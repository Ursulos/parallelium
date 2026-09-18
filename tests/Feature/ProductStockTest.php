<?php

namespace Tests\Feature;

use App\Enums\StockMovementType;
use App\Models\Company;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Services\ProductService;
use App\Services\StockService;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use RuntimeException;
use Tests\TestCase;

class ProductStockTest extends TestCase
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

    public function test_creating_a_product_with_initial_stock_records_a_stock_movement(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = app(ProductService::class)->create([
            'company_id' => $company->id,
            'name' => 'Riz local 1kg',
            'unit' => 'kg',
            'purchase_price' => 2800,
            'selling_price' => 3500,
            'stock_quantity' => 50,
            'minimum_stock' => 10,
        ]);

        $this->assertEquals(50, $product->stock_quantity);
        $this->assertDatabaseHas('stock_movements', [
            'product_id' => $product->id,
            'quantity' => 50,
            'type' => 'adjustment',
        ]);
    }

    public function test_stock_cannot_go_negative_without_allow_negative(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 3]);

        $this->expectException(RuntimeException::class);

        app(StockService::class)->record($product, StockMovementType::Sale, -5);
    }

    public function test_stock_movement_updates_product_quantity_and_is_traceable(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 10]);

        app(StockService::class)->record($product, StockMovementType::Loss, -2, 'Casse');

        $this->assertEquals(8, $product->fresh()->stock_quantity);
        $this->assertDatabaseHas('stock_movements', [
            'product_id' => $product->id,
            'quantity' => -2,
            'reason' => 'Casse',
        ]);
    }

    public function test_a_company_cannot_see_another_companys_products(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();

        Product::factory()->create(['company_id' => $companyA->id, 'name' => 'Produit A']);
        Product::factory()->create(['company_id' => $companyB->id, 'name' => 'Produit B']);

        $userA = $this->ownerFor($companyA);
        $this->actingAs($userA);

        $products = Product::all();

        $this->assertCount(1, $products);
        $this->assertEquals('Produit A', $products->first()->name);
    }

    public function test_low_stock_scope_returns_only_products_under_minimum(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 50, 'minimum_stock' => 10]);
        $low = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 2, 'minimum_stock' => 10]);

        $result = Product::lowStock()->get();

        $this->assertCount(1, $result);
        $this->assertEquals($low->id, $result->first()->id);
    }
}
