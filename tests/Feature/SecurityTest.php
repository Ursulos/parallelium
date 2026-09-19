<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Derniers filets de sécurité (Phase 12, §33 et §48) : en-têtes HTTP,
 * accès cross-tenant via le model binding de route, mass assignment.
 */
class SecurityTest extends TestCase
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

    public function test_security_headers_are_present_on_every_response(): void
    {
        $response = $this->get(route('login'));

        $response->assertHeader('X-Frame-Options', 'SAMEORIGIN');
        $response->assertHeader('X-Content-Type-Options', 'nosniff');
        $response->assertHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    }

    public function test_a_company_cannot_edit_another_companys_product_via_url(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();
        $ownerA = $this->ownerFor($companyA);
        $productB = Product::factory()->create(['company_id' => $companyB->id]);

        // Le scope tenant automatique (BelongsToCompany) doit rendre ce
        // produit introuvable pour une entreprise différente, y compris
        // via le model binding implicite de route.
        $this->actingAs($ownerA)->get(route('products.edit', $productB))->assertNotFound();
    }

    public function test_registration_is_rate_limited(): void
    {
        for ($i = 0; $i < 7; $i++) {
            $response = $this->post(route('register'), [
                'company_name' => "Boutique {$i}",
                'name' => 'Test',
                'email' => "test{$i}@example.com",
                'password' => 'password123',
                'password_confirmation' => 'password123',
            ]);
        }

        $response->assertStatus(429);
    }

    public function test_mass_assignment_cannot_override_company_id_on_product_creation(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();
        $ownerA = $this->ownerFor($companyA);

        $this->actingAs($ownerA)->post(route('products.store'), [
            // Tentative d'injection d'un company_id arbitraire : le champ
            // n'est simplement pas dans les règles de validation, donc
            // jamais transmis au service, quoi qu'envoie le client.
            'company_id' => $companyB->id,
            'name' => 'Produit test',
            'unit' => 'unite',
            'purchase_price' => 100,
            'selling_price' => 200,
        ]);

        $product = Product::first();
        $this->assertEquals($companyA->id, $product->company_id);
    }
}
