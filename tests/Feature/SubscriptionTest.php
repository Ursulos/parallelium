<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Role;
use App\Models\Subscription;
use App\Models\User;
use App\Services\ProductService;
use App\Services\SubscriptionService;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use RuntimeException;
use Tests\TestCase;

class SubscriptionTest extends TestCase
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

    public function test_free_plan_blocks_product_creation_past_its_limit(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'free', 'status' => 'active']);
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        Product::factory()->count(50)->create(['company_id' => $company->id]);

        $this->expectException(RuntimeException::class);

        app(ProductService::class)->create([
            'company_id' => $company->id,
            'name' => 'Produit en trop',
            'unit' => 'unite',
            'purchase_price' => 100,
            'selling_price' => 200,
        ]);
    }

    public function test_starter_plan_allows_more_products_than_free(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'starter', 'status' => 'active']);
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        Product::factory()->count(50)->create(['company_id' => $company->id]);

        $product = app(ProductService::class)->create([
            'company_id' => $company->id,
            'name' => 'Produit 51',
            'unit' => 'unite',
            'purchase_price' => 100,
            'selling_price' => 200,
        ]);

        $this->assertNotNull($product->id);
    }

    public function test_business_plan_has_unlimited_products(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'business', 'status' => 'active']);

        $this->assertNull(app(SubscriptionService::class)->usage($company)['products']['limit']);
    }

    public function test_free_plan_blocks_customer_creation_past_its_limit(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'free', 'status' => 'active']);
        $owner = $this->ownerFor($company);

        Customer::factory()->count(100)->create(['company_id' => $company->id]);

        $response = $this->actingAs($owner)->post(route('customers.store'), ['name' => 'Client en trop']);

        $response->assertSessionHasErrors('name');
        $this->assertDatabaseCount('customers', 100);
    }

    public function test_owner_can_change_plan(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'free', 'status' => 'active']);
        $owner = $this->ownerFor($company);

        $this->actingAs($owner)
            ->post(route('settings.subscription'), ['plan' => 'starter'])
            ->assertRedirect(route('settings.index'));

        $this->assertEquals('starter', $company->subscription->fresh()->plan);
    }

    public function test_a_seller_cannot_change_the_plan(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'free', 'status' => 'active']);
        $sellerRole = Role::whereNull('company_id')->where('slug', 'seller')->first();
        $seller = User::factory()->create(['company_id' => $company->id, 'role_id' => $sellerRole->id]);

        $this->actingAs($seller)
            ->post(route('settings.subscription'), ['plan' => 'starter'])
            ->assertForbidden();
    }
}
