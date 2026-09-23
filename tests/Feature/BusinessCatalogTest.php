<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Product;
use App\Models\Role;
use App\Models\Subscription;
use App\Models\User;
use App\Services\BusinessCatalogService;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BusinessCatalogTest extends TestCase
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

    public function test_seeding_the_epicerie_catalog_creates_products_with_no_price_and_no_stock(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'business', 'status' => 'active']);

        $result = app(BusinessCatalogService::class)->seed($company, 'epicerie_ppn');

        $this->assertGreaterThan(20, $result['created']);
        $this->assertEquals(0, $result['skipped_limit']);

        $product = Product::where('company_id', $company->id)->first();
        $this->assertEquals(0, $product->purchase_price);
        $this->assertEquals(0, $product->selling_price);
        $this->assertEquals(0, $product->stock_quantity);

        $this->assertDatabaseHas('products', ['company_id' => $company->id, 'name' => 'News Maitso']);
        $this->assertDatabaseHas('products', ['company_id' => $company->id, 'name' => 'News Mena']);
    }

    public function test_seeding_twice_does_not_create_duplicates(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'business', 'status' => 'active']);

        $service = app(BusinessCatalogService::class);
        $first = $service->seed($company, 'epicerie_ppn');
        $second = $service->seed($company, 'epicerie_ppn');

        $this->assertEquals(0, $second['created']);
        $this->assertEquals($first['created'], $second['skipped_duplicate']);
    }

    public function test_seeding_respects_the_plan_product_limit(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'free', 'status' => 'active']); // limite 20

        $result = app(BusinessCatalogService::class)->seed($company, 'epicerie_ppn');

        $this->assertEquals(20, $result['created']);
        $this->assertGreaterThan(0, $result['skipped_limit']);
        $this->assertDatabaseCount('products', 20);
    }

    public function test_owner_can_seed_catalog_from_onboarding(): void
    {
        $company = Company::factory()->create(['business_type' => 'epicerie_ppn', 'onboarding_completed' => false]);
        Subscription::create(['company_id' => $company->id, 'plan' => 'business', 'status' => 'active']);
        $owner = $this->ownerFor($company);

        $this->actingAs($owner)
            ->post(route('onboarding.seed-catalog'))
            ->assertRedirect(route('onboarding.show'));

        $this->assertGreaterThan(0, Product::where('company_id', $company->id)->count());
    }

    public function test_a_free_text_business_type_displays_as_is_not_as_a_raw_slug(): void
    {
        $company = Company::factory()->create(['business_type' => 'Atelier de couture']);

        $this->assertEquals('Atelier de couture', $company->businessTypeLabel());
    }

    public function test_a_known_catalog_slug_displays_its_readable_label(): void
    {
        $company = Company::factory()->create(['business_type' => 'epicerie_ppn']);

        $this->assertEquals(BusinessCatalogService::options()['epicerie_ppn'], $company->businessTypeLabel());
    }
}
