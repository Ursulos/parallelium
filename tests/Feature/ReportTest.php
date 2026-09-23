<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Expense;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Services\ReportService;
use App\Services\SaleService;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ReportTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([PermissionSeeder::class, RoleSeeder::class]);
    }

    protected function ownerFor(Company $company): User
    {
        $role = Role::whereNull('company_id')->where('slug', 'owner')->first();

        return User::factory()->create(['company_id' => $company->id, 'role_id' => $role->id]);
    }

    public function test_sales_report_totals_match_completed_sales_in_period(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 10, 'selling_price' => 5000]);
        app(SaleService::class)->create([
            'items' => [['product_id' => $product->id, 'quantity' => 2]],
            'paid_amount' => 6000,
            'payment_method' => 'cash',
        ], $owner);

        $report = app(ReportService::class)->salesReport(now()->startOfMonth(), now()->endOfMonth());

        $this->assertEquals(1, $report['count']);
        $this->assertEquals(10000, $report['revenue']);
        $this->assertEquals(6000, $report['paid']);
        $this->assertEquals(4000, $report['remaining']);
    }

    public function test_products_report_does_not_leak_across_companies(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();
        $ownerA = $this->ownerFor($companyA);
        $ownerB = $this->ownerFor($companyB);

        $productA = Product::factory()->create(['company_id' => $companyA->id, 'stock_quantity' => 10, 'selling_price' => 1000, 'name' => 'Produit A']);
        $productB = Product::factory()->create(['company_id' => $companyB->id, 'stock_quantity' => 10, 'selling_price' => 1000, 'name' => 'Produit B']);

        $this->actingAs($ownerB);
        app(SaleService::class)->create(['items' => [['product_id' => $productB->id, 'quantity' => 1]], 'paid_amount' => 1000, 'payment_method' => 'cash'], $ownerB);

        $this->actingAs($ownerA);
        app(SaleService::class)->create(['items' => [['product_id' => $productA->id, 'quantity' => 1]], 'paid_amount' => 1000, 'payment_method' => 'cash'], $ownerA);

        $report = app(ReportService::class)->productsReport(now()->startOfMonth(), now()->endOfMonth());

        $this->assertCount(1, $report['rows']);
        $this->assertEquals('Produit A', $report['rows']->first()->name);
    }

    public function test_expenses_report_groups_by_category(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        Expense::factory()->create(['company_id' => $company->id, 'category' => 'transport', 'amount' => 10000, 'expense_date' => now()]);
        Expense::factory()->create(['company_id' => $company->id, 'category' => 'transport', 'amount' => 5000, 'expense_date' => now()]);
        Expense::factory()->create(['company_id' => $company->id, 'category' => 'rent', 'amount' => 300000, 'expense_date' => now()]);

        $report = app(ReportService::class)->expensesReport(now()->startOfMonth(), now()->endOfMonth());

        $this->assertEquals(315000, $report['total']);
        $transport = $report['byCategory']->firstWhere('label', 'Transport');
        $this->assertEquals(15000, $transport['total']);
        $this->assertEquals(2, $transport['count']);
    }

    public function test_csv_export_is_downloadable_by_an_authorized_user(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);

        $response = $this->actingAs($owner)->get(route('reports.sales', ['export' => 'csv']));

        $response->assertOk();
        $response->assertHeader('content-type', 'text/csv; charset=UTF-8');
    }

    public function test_a_seller_cannot_access_reports(): void
    {
        $company = Company::factory()->create();
        $sellerRole = Role::whereNull('company_id')->where('slug', 'seller')->first();
        $seller = User::factory()->create(['company_id' => $company->id, 'role_id' => $sellerRole->id]);

        $this->actingAs($seller)->get(route('reports.index'))->assertForbidden();
    }

    public function test_comparing_two_periods_computes_both_reports_and_the_delta(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 100, 'selling_price' => 10000]);
        $saleService = app(SaleService::class);

        // Période A : 2 ventes (sold_at forcé après coup, la vente se crée "maintenant").
        $saleService->create(['items' => [['product_id' => $product->id, 'quantity' => 1]], 'paid_amount' => 10000, 'payment_method' => 'cash'], $owner);
        $saleA2 = $saleService->create(['items' => [['product_id' => $product->id, 'quantity' => 1]], 'paid_amount' => 10000, 'payment_method' => 'cash'], $owner);

        // Période B (mois dernier) : 1 vente, forcée dans le passé directement en base.
        $saleB = $saleService->create(['items' => [['product_id' => $product->id, 'quantity' => 1]], 'paid_amount' => 10000, 'payment_method' => 'cash'], $owner);
        $saleB->update(['sold_at' => now()->subMonthNoOverflow()->startOfMonth()->addDay()]);

        $report = app(ReportService::class);
        [$fromA, $toA] = [now()->startOfMonth(), now()->endOfMonth()];
        [$fromB, $toB] = [now()->subMonthNoOverflow()->startOfMonth(), now()->subMonthNoOverflow()->endOfMonth()];

        $comparison = $report->compareSales($fromA, $toA, $fromB, $toB);

        $this->assertEquals(2, $comparison['a']['count']);
        $this->assertEquals(1, $comparison['b']['count']);
        $this->assertEquals(20000, $comparison['a']['revenue']);
        $this->assertEquals(10000, $comparison['b']['revenue']);
        // +100% de CA (20 000 contre 10 000) et +100% de ventes (2 contre 1).
        $this->assertEquals(100.0, $comparison['revenue_change']);
        $this->assertEquals(100.0, $comparison['count_change']);
    }

    public function test_sales_report_compare_mode_is_reachable_via_the_route(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);

        $this->actingAs($owner)
            ->get(route('reports.sales', [
                'compare' => 1,
                'from' => now()->startOfMonth()->format('Y-m-d'),
                'to' => now()->endOfMonth()->format('Y-m-d'),
                'from_b' => now()->subMonthNoOverflow()->startOfMonth()->format('Y-m-d'),
                'to_b' => now()->subMonthNoOverflow()->endOfMonth()->format('Y-m-d'),
            ]))
            ->assertOk()
            ->assertSee('Comparer deux périodes');
    }
}
