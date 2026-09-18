<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Services\SaleService;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use RuntimeException;
use Tests\TestCase;

class SaleTest extends TestCase
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

    public function test_creating_a_sale_decreases_stock_and_records_a_movement(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 10, 'selling_price' => 5000]);

        $sale = app(SaleService::class)->create([
            'items' => [['product_id' => $product->id, 'quantity' => 3]],
            'paid_amount' => 15000,
            'payment_method' => 'cash',
        ], $owner);

        $this->assertEquals(7, $product->fresh()->stock_quantity);
        $this->assertEquals(15000, $sale->total_amount);
        $this->assertEquals('paid', $sale->payment_status->value);
        $this->assertDatabaseHas('stock_movements', [
            'product_id' => $product->id,
            'quantity' => -3,
            'reference_type' => $sale->getMorphClass(),
            'reference_id' => $sale->id,
        ]);
    }

    public function test_sale_fails_when_stock_is_insufficient(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 2]);

        try {
            app(SaleService::class)->create([
                'items' => [['product_id' => $product->id, 'quantity' => 5]],
                'paid_amount' => 0,
                'payment_method' => 'cash',
            ], $owner);
            $this->fail('Une exception RuntimeException était attendue.');
        } catch (RuntimeException $e) {
            $this->assertStringContainsString('Stock insuffisant', $e->getMessage());
        }

        $this->assertEquals(2, $product->fresh()->stock_quantity);
        $this->assertDatabaseCount('sales', 0);
    }

    public function test_partial_payment_computes_remaining_amount_and_status(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 10, 'selling_price' => 10000]);
        $customer = Customer::factory()->create(['company_id' => $company->id]);

        $sale = app(SaleService::class)->create([
            'customer_id' => $customer->id,
            'items' => [['product_id' => $product->id, 'quantity' => 2]],
            'paid_amount' => 15000,
            'payment_method' => 'mvola',
        ], $owner);

        $this->assertEquals(20000, $sale->total_amount);
        $this->assertEquals(5000, $sale->remaining_amount);
        $this->assertEquals('partially_paid', $sale->payment_status->value);
        $this->assertEquals(20000, $customer->fresh()->totalPurchases());
        $this->assertEquals(5000, $customer->fresh()->totalRemaining());
    }

    public function test_cancelling_a_sale_restores_stock(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 10, 'selling_price' => 1000]);

        $saleService = app(SaleService::class);
        $sale = $saleService->create([
            'items' => [['product_id' => $product->id, 'quantity' => 4]],
            'paid_amount' => 4000,
            'payment_method' => 'cash',
        ], $owner);

        $this->assertEquals(6, $product->fresh()->stock_quantity);

        $saleService->cancel($sale, $owner);

        $this->assertEquals(10, $product->fresh()->stock_quantity);
        $this->assertEquals('cancelled', $sale->fresh()->sale_status->value);
    }

    public function test_a_company_cannot_see_another_companys_sales(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();

        $ownerA = $this->ownerFor($companyA);
        $ownerB = $this->ownerFor($companyB);

        $this->actingAs($ownerB);
        $productB = Product::factory()->create(['company_id' => $companyB->id, 'stock_quantity' => 5]);
        app(SaleService::class)->create([
            'items' => [['product_id' => $productB->id, 'quantity' => 1]],
            'paid_amount' => 0,
            'payment_method' => 'cash',
        ], $ownerB);

        $this->actingAs($ownerA);

        $this->assertCount(0, \App\Models\Sale::all());
    }
}
