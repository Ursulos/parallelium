<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Services\InvoiceService;
use App\Services\SaleService;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use RuntimeException;
use Tests\TestCase;

class InvoiceTest extends TestCase
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

    public function test_generating_an_invoice_from_a_sale_uses_the_company_prefix_and_year(): void
    {
        $company = Company::factory()->create(['invoice_prefix' => 'PAR']);
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 10, 'selling_price' => 1000]);
        $sale = app(SaleService::class)->create([
            'items' => [['product_id' => $product->id, 'quantity' => 2]],
            'paid_amount' => 2000,
            'payment_method' => 'cash',
        ], $owner);

        $invoice = app(InvoiceService::class)->generateFor($sale);

        $this->assertStringStartsWith('PAR-'.now()->year.'-', $invoice->invoice_number);
        $this->assertEquals('paid', $invoice->status->value);
        $this->assertEquals($invoice->id, $sale->fresh()->invoice_id);
    }

    public function test_generating_an_invoice_twice_returns_the_same_invoice(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 10, 'selling_price' => 1000]);
        $sale = app(SaleService::class)->create([
            'items' => [['product_id' => $product->id, 'quantity' => 1]],
            'paid_amount' => 0,
            'payment_method' => 'cash',
        ], $owner);

        $invoiceService = app(InvoiceService::class);
        $first = $invoiceService->generateFor($sale);
        $second = $invoiceService->generateFor($sale->fresh());

        $this->assertEquals($first->id, $second->id);
        $this->assertDatabaseCount('invoices', 1);
    }

    public function test_a_cancelled_sale_cannot_be_invoiced(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 10, 'selling_price' => 1000]);
        $saleService = app(SaleService::class);
        $sale = $saleService->create([
            'items' => [['product_id' => $product->id, 'quantity' => 1]],
            'paid_amount' => 1000,
            'payment_method' => 'cash',
        ], $owner);
        $saleService->cancel($sale, $owner);

        $this->expectException(RuntimeException::class);
        app(InvoiceService::class)->generateFor($sale->fresh());
    }

    public function test_invoice_numbers_are_unique_per_company_and_independent_between_companies(): void
    {
        $companyA = Company::factory()->create(['invoice_prefix' => 'PAR']);
        $companyB = Company::factory()->create(['invoice_prefix' => 'PAR']);
        $ownerA = $this->ownerFor($companyA);
        $ownerB = $this->ownerFor($companyB);

        $productA = Product::factory()->create(['company_id' => $companyA->id, 'stock_quantity' => 10, 'selling_price' => 1000]);
        $productB = Product::factory()->create(['company_id' => $companyB->id, 'stock_quantity' => 10, 'selling_price' => 1000]);

        $this->actingAs($ownerA);
        $saleA = app(SaleService::class)->create(['items' => [['product_id' => $productA->id, 'quantity' => 1]], 'paid_amount' => 1000, 'payment_method' => 'cash'], $ownerA);
        $invoiceA = app(InvoiceService::class)->generateFor($saleA);

        $this->actingAs($ownerB);
        $saleB = app(SaleService::class)->create(['items' => [['product_id' => $productB->id, 'quantity' => 1]], 'paid_amount' => 1000, 'payment_method' => 'cash'], $ownerB);
        $invoiceB = app(InvoiceService::class)->generateFor($saleB);

        // Chaque entreprise numérote depuis 1, indépendamment de l'autre.
        $this->assertStringEndsWith('000001', $invoiceA->invoice_number);
        $this->assertStringEndsWith('000001', $invoiceB->invoice_number);
    }
}
