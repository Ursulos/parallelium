<?php

namespace Tests\Feature\Admin;

use App\Models\Admin;
use App\Models\Company;
use App\Models\Role;
use App\Models\Subscription;
use App\Models\User;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Le panneau admin plateforme est un système d'authentification à part
 * entière (guard "admin"), totalement étanche au guard "web" (comptes
 * d'entreprise). Ces tests vérifient explicitement cette étanchéité dans
 * les deux sens.
 */
class AdminPanelTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([PermissionSeeder::class, RoleSeeder::class]);
    }

    public function test_an_admin_can_log_in_and_list_companies(): void
    {
        $admin = Admin::factory()->create(['password' => 'password123']);
        Company::factory()->count(3)->create();

        $this->post(route('admin.login'), [
            'email' => $admin->email,
            'password' => 'password123',
        ])->assertRedirect(route('admin.companies.index'));

        $this->assertAuthenticatedAs($admin, 'admin');

        $this->actingAs($admin, 'admin')
            ->get(route('admin.companies.index'))
            ->assertOk();
    }

    public function test_a_company_owner_cannot_access_the_admin_panel(): void
    {
        $company = Company::factory()->create();
        $role = Role::whereNull('company_id')->where('slug', 'owner')->first();
        $owner = User::factory()->create(['company_id' => $company->id, 'role_id' => $role->id]);

        // Authentifié sur le guard "web" (entreprise), jamais sur "admin".
        $this->actingAs($owner)
            ->get(route('admin.companies.index'))
            ->assertRedirect(route('admin.login'));
    }

    public function test_an_admin_cannot_access_tenant_routes(): void
    {
        $admin = Admin::factory()->create();

        // Authentifié sur le guard "admin", jamais sur "web" : le
        // dashboard d'entreprise doit rester inaccessible.
        $this->actingAs($admin, 'admin')
            ->get(route('dashboard'))
            ->assertRedirect(route('login'));
    }

    public function test_admin_can_suspend_a_company_and_its_owner_gets_logged_out(): void
    {
        $admin = Admin::factory()->create();
        $company = Company::factory()->create(['status' => 'active']);
        $role = Role::whereNull('company_id')->where('slug', 'owner')->first();
        $owner = User::factory()->create(['company_id' => $company->id, 'role_id' => $role->id]);

        $this->actingAs($admin, 'admin')
            ->post(route('admin.companies.suspend', $company))
            ->assertRedirect();

        $this->assertEquals('suspended', $company->fresh()->status);

        // Le propriétaire, déjà connecté, est bloqué dès sa prochaine requête.
        $this->actingAs($owner)
            ->get(route('dashboard'))
            ->assertRedirect(route('login'));
    }

    public function test_admin_can_change_a_companys_plan(): void
    {
        $admin = Admin::factory()->create();
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'free', 'status' => 'active']);

        $this->actingAs($admin, 'admin')
            ->post(route('admin.companies.plan', $company), ['plan' => 'business'])
            ->assertRedirect();

        $this->assertEquals('business', $company->subscription->fresh()->plan);
    }
}
