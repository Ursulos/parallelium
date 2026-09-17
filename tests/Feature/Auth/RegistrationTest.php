<?php

namespace Tests\Feature\Auth;

use App\Models\Company;
use App\Models\Subscription;
use App\Models\User;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RegistrationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([PermissionSeeder::class, RoleSeeder::class]);
    }

    public function test_registering_creates_a_company_and_an_owner_user(): void
    {
        $response = $this->post('/register', [
            'company_name' => 'Épicerie Test',
            'name' => 'Jean Test',
            'email' => 'jean@example.com',
            'phone' => '0341234567',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertRedirect(route('onboarding.show'));

        $this->assertDatabaseHas('companies', ['name' => 'Épicerie Test']);

        $user = User::where('email', 'jean@example.com')->first();
        $this->assertNotNull($user);
        $this->assertTrue($user->isOwner());
        $this->assertNotNull($user->company_id);

        $this->assertDatabaseHas('subscriptions', [
            'company_id' => $user->company_id,
            'plan' => 'free',
            'status' => 'trialing',
        ]);

        $this->assertAuthenticatedAs($user);
    }

    public function test_registration_requires_unique_email(): void
    {
        $company = Company::factory()->create();
        User::factory()->create(['company_id' => $company->id, 'email' => 'taken@example.com']);

        $response = $this->post('/register', [
            'company_name' => 'Autre Entreprise',
            'name' => 'Autre Personne',
            'email' => 'taken@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertSessionHasErrors('email');
    }
}
