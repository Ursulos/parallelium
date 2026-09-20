<?php

namespace Tests\Feature\Admin;

use App\Models\Admin;
use App\Models\ActivityLog;
use App\Models\Company;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminControlTest extends TestCase
{
    use RefreshDatabase;

    protected function ownerFor(Company $company): User
    {
        $role = Role::firstOrCreate(
            ['company_id' => null, 'slug' => 'owner'],
            ['name' => 'Propriétaire', 'is_system' => true]
        );

        return User::factory()->create(['company_id' => $company->id, 'role_id' => $role->id, 'is_active' => true]);
    }

    public function test_admin_dashboard_shows_platform_wide_stats(): void
    {
        $admin = Admin::factory()->create();
        Company::factory()->count(3)->create(['status' => 'active']);

        $this->actingAs($admin, 'admin')
            ->get(route('admin.dashboard'))
            ->assertOk()
            ->assertSee('Vue d\'ensemble');
    }

    public function test_admin_can_create_and_delete_another_admin(): void
    {
        $admin = Admin::factory()->create();

        $this->actingAs($admin, 'admin')->post(route('admin.admins.store'), [
            'name' => 'Second Admin',
            'email' => 'second@parallelium.app',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ])->assertRedirect(route('admin.admins.index'));

        $second = Admin::where('email', 'second@parallelium.app')->first();
        $this->assertNotNull($second);

        $this->actingAs($admin, 'admin')
            ->delete(route('admin.admins.destroy', $second))
            ->assertRedirect();

        $this->assertNull(Admin::find($second->id));
    }

    public function test_admin_cannot_delete_their_own_account(): void
    {
        $admin = Admin::factory()->create();
        Admin::factory()->create(); // pour ne pas être le dernier compte

        $this->actingAs($admin, 'admin')
            ->delete(route('admin.admins.destroy', $admin))
            ->assertSessionHasErrors('admin');

        $this->assertNotNull(Admin::find($admin->id));
    }

    public function test_admin_cannot_delete_the_last_remaining_admin(): void
    {
        $admin = Admin::factory()->create();
        $other = Admin::factory()->create();

        // Supprime tous les autres pour ne laisser que $other, tenté seul.
        Admin::where('id', '!=', $other->id)->delete();

        $this->actingAs($other, 'admin')
            ->delete(route('admin.admins.destroy', $other))
            ->assertSessionHasErrors('admin');
    }

    public function test_admin_can_edit_a_company(): void
    {
        $admin = Admin::factory()->create();
        $company = Company::factory()->create(['name' => 'Ancien nom']);

        $this->actingAs($admin, 'admin')->put(route('admin.companies.update', $company), [
            'name' => 'Nouveau nom',
            'currency' => 'MGA',
        ])->assertRedirect(route('admin.companies.show', $company));

        $this->assertEquals('Nouveau nom', $company->fresh()->name);
    }

    public function test_admin_can_close_a_company_permanently(): void
    {
        $admin = Admin::factory()->create();
        $company = Company::factory()->create(['status' => 'active']);

        $this->actingAs($admin, 'admin')
            ->post(route('admin.companies.close', $company))
            ->assertRedirect();

        $this->assertEquals('closed', $company->fresh()->status);
    }

    public function test_admin_can_impersonate_a_company_user_and_stop(): void
    {
        $admin = Admin::factory()->create();
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);

        $this->actingAs($admin, 'admin')
            ->post(route('admin.companies.impersonate', [$company, $owner]))
            ->assertRedirect(route('dashboard'));

        $this->assertAuthenticatedAs($owner, 'web');
        // La session admin reste valide en parallèle.
        $this->assertAuthenticatedAs($admin, 'admin');

        $this->assertDatabaseHas('activity_logs', [
            'company_id' => $company->id,
            'action' => 'admin.impersonation_started',
        ]);

        $this->post(route('impersonation.stop'))
            ->assertRedirect(route('admin.companies.show', $company));

        $this->assertGuest('web');
        // Toujours connecté côté admin après l'arrêt de l'impersonation.
        $this->assertAuthenticatedAs($admin, 'admin');
    }

    public function test_admin_cannot_impersonate_a_user_from_a_different_company(): void
    {
        $admin = Admin::factory()->create();
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();
        $ownerB = $this->ownerFor($companyB);

        $this->actingAs($admin, 'admin')
            ->post(route('admin.companies.impersonate', [$companyA, $ownerB]))
            ->assertNotFound();
    }
}
