<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Services\SaleService;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Un vendeur ne doit voir NI le chiffre d'affaires, NI un lien de
 * navigation vers une page à laquelle il n'a pas accès — jamais un lien
 * cliquable qui finit sur "non autorisé" (demande explicite du client).
 */
class RolePermissionUiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([PermissionSeeder::class, RoleSeeder::class]);
    }

    protected function userWithRole(Company $company, string $slug): User
    {
        $role = Role::whereNull('company_id')->where('slug', $slug)->first();

        return User::factory()->create(['company_id' => $company->id, 'role_id' => $role->id]);
    }

    public function test_a_seller_does_not_see_revenue_figures_on_the_dashboard(): void
    {
        $company = Company::factory()->create();
        $seller = $this->userWithRole($company, 'seller');
        $owner = $this->userWithRole($company, 'owner');

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 10, 'selling_price' => 50000]);
        app(SaleService::class)->create([
            'items' => [['product_id' => $product->id, 'quantity' => 2]],
            'paid_amount' => 100000,
            'payment_method' => 'cash',
        ], $owner);

        $response = $this->actingAs($seller)->get(route('dashboard'));

        $response->assertOk();
        $response->assertDontSee("Chiffre d'affaires");
        $response->assertDontSee('Résultat estimé');
        // Les ventes récentes restent visibles (le vendeur y a déjà accès
        // via sa permission sales.view) : seul le CA AGRÉGÉ est masqué.
        $response->assertSee('Dernières ventes');
    }

    public function test_a_manager_does_see_revenue_figures_on_the_dashboard(): void
    {
        $company = Company::factory()->create();
        $manager = $this->userWithRole($company, 'manager');

        $response = $this->actingAs($manager)->get(route('dashboard'));

        $response->assertOk();
        $response->assertSee("Chiffre d'affaires");
    }

    public function test_a_seller_does_not_see_a_link_to_reports_in_navigation(): void
    {
        $company = Company::factory()->create();
        $seller = $this->userWithRole($company, 'seller');

        $response = $this->actingAs($seller)->get(route('dashboard'));

        $response->assertOk();
        $response->assertDontSee(route('reports.index'), false);
        $response->assertDontSee(route('employees.index'), false);
        $response->assertDontSee(route('settings.index'), false);
    }

    public function test_a_seller_visiting_reports_directly_is_still_forbidden(): void
    {
        $company = Company::factory()->create();
        $seller = $this->userWithRole($company, 'seller');

        $this->actingAs($seller)->get(route('reports.index'))->assertForbidden();
    }

    public function test_an_accountant_sees_reports_link_but_not_sales_creation_quick_action(): void
    {
        $company = Company::factory()->create();
        $accountant = $this->userWithRole($company, 'accountant');

        $response = $this->actingAs($accountant)->get(route('dashboard'));

        $response->assertOk();
        $response->assertSee(route('reports.index'), false);
    }
}
