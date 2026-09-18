<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Customer;
use App\Models\Role;
use App\Models\User;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CustomerTest extends TestCase
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

    public function test_owner_can_create_a_customer(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);

        $response = $this->actingAs($owner)->post(route('customers.store'), [
            'name' => 'Client Test',
            'phone' => '034 00 000 00',
        ]);

        $customer = Customer::first();
        $response->assertRedirect(route('customers.show', $customer));
        $this->assertDatabaseHas('customers', ['name' => 'Client Test', 'company_id' => $company->id]);
    }

    public function test_a_company_cannot_see_another_companys_customers(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();

        Customer::factory()->create(['company_id' => $companyA->id, 'name' => 'Client A']);
        Customer::factory()->create(['company_id' => $companyB->id, 'name' => 'Client B']);

        $userA = $this->ownerFor($companyA);

        $customers = $this->actingAs($userA)->get(route('customers.index'));

        $customers->assertSee('Client A');
        $customers->assertDontSee('Client B');
    }

    public function test_a_seller_without_permission_cannot_delete_a_customer(): void
    {
        $company = Company::factory()->create();
        $sellerRole = Role::whereNull('company_id')->where('slug', 'seller')->first();
        $seller = User::factory()->create(['company_id' => $company->id, 'role_id' => $sellerRole->id]);
        $customer = Customer::factory()->create(['company_id' => $company->id]);

        $this->actingAs($seller)
            ->delete(route('customers.destroy', $customer))
            ->assertForbidden();

        $this->assertNotSoftDeleted($customer);
    }
}
