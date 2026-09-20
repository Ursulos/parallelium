<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Role;
use App\Models\Subscription;
use App\Models\User;
use App\Services\EmployeeService;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Illuminate\Auth\Notifications\ResetPassword;
use RuntimeException;
use Tests\TestCase;

class EmployeeTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([PermissionSeeder::class, RoleSeeder::class]);
        Notification::fake();
    }

    protected function ownerFor(Company $company): User
    {
        $role = Role::whereNull('company_id')->where('slug', 'owner')->first();

        return User::factory()->create(['company_id' => $company->id, 'role_id' => $role->id]);
    }

    public function test_owner_can_invite_an_employee_with_a_role(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $employee = app(EmployeeService::class)->invite([
            'name' => 'Nouvel Employé',
            'email' => 'employe@example.com',
            'role' => 'seller',
        ]);

        $this->assertEquals($company->id, $employee->company_id);
        $this->assertEquals('seller', $employee->role->slug);
        Notification::assertSentTo($employee, ResetPassword::class);
    }

    public function test_invitation_is_blocked_once_the_plan_user_limit_is_reached(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'free', 'status' => 'active']);
        $owner = $this->ownerFor($company); // 1er utilisateur, plan free = 1 max
        $this->actingAs($owner);

        $this->expectException(RuntimeException::class);

        app(EmployeeService::class)->invite([
            'name' => 'Trop Nombreux',
            'email' => 'trop@example.com',
            'role' => 'seller',
        ]);
    }

    public function test_a_manager_cannot_manage_employees(): void
    {
        $company = Company::factory()->create();
        $managerRole = Role::whereNull('company_id')->where('slug', 'manager')->first();
        $manager = User::factory()->create(['company_id' => $company->id, 'role_id' => $managerRole->id]);

        $this->actingAs($manager)->get(route('employees.index'))->assertForbidden();
    }

    public function test_a_user_cannot_deactivate_their_own_account(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);

        $this->expectException(RuntimeException::class);
        app(EmployeeService::class)->deactivate($owner, $owner);
    }

    public function test_the_owner_cannot_be_deactivated(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $managerRole = Role::whereNull('company_id')->where('slug', 'manager')->first();
        $manager = User::factory()->create(['company_id' => $company->id, 'role_id' => $managerRole->id]);

        $this->expectException(RuntimeException::class);
        app(EmployeeService::class)->deactivate($owner, $manager);
    }

    public function test_a_company_cannot_see_another_companys_employees(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();

        $ownerA = $this->ownerFor($companyA);
        User::factory()->create(['company_id' => $companyB->id, 'name' => 'Employé B']);

        $response = $this->actingAs($ownerA)->get(route('employees.index'));

        $response->assertOk();
        $response->assertDontSee('Employé B');
    }

    public function test_owner_can_resend_an_invitation(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $sellerRole = Role::whereNull('company_id')->where('slug', 'seller')->first();
        $employee = User::factory()->create(['company_id' => $company->id, 'role_id' => $sellerRole->id]);

        $this->actingAs($owner)
            ->post(route('employees.resend-invite', $employee))
            ->assertRedirect();

        Notification::assertSentTo($employee, ResetPassword::class);
    }

    public function test_a_company_cannot_edit_or_deactivate_another_companys_employee(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();

        $ownerA = $this->ownerFor($companyA);
        $sellerRole = Role::whereNull('company_id')->where('slug', 'seller')->first();
        $employeeB = User::factory()->create(['company_id' => $companyB->id, 'role_id' => $sellerRole->id]);

        $this->actingAs($ownerA);

        $this->get(route('employees.edit', $employeeB))->assertNotFound();
        $this->delete(route('employees.destroy', $employeeB))->assertNotFound();
        $this->assertNotSoftDeleted($employeeB);
    }
}
