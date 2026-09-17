<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Subscription;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * L'isolation multi-tenant est la garantie la plus critique de
 * Parallelium (cahier des charges §8 et §48) : une entreprise ne doit
 * JAMAIS voir les données d'une autre, même en connaissant son ID.
 */
class TenantIsolationTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_company_cannot_see_another_companys_data_via_global_scope(): void
    {
        $companyA = Company::factory()->create(['name' => 'Entreprise A']);
        $companyB = Company::factory()->create(['name' => 'Entreprise B']);

        Subscription::create(['company_id' => $companyA->id, 'plan' => 'free', 'status' => 'trialing']);
        Subscription::create(['company_id' => $companyB->id, 'plan' => 'free', 'status' => 'trialing']);

        $userA = User::factory()->create(['company_id' => $companyA->id]);

        $this->actingAs($userA);

        // Le scope global "company" doit filtrer automatiquement : même
        // sans condition explicite, seule la souscription de l'entreprise A
        // doit être visible.
        $visible = Subscription::all();

        $this->assertCount(1, $visible);
        $this->assertEquals($companyA->id, $visible->first()->company_id);
    }

    public function test_dashboard_is_inaccessible_without_authentication(): void
    {
        $this->get(route('dashboard'))->assertRedirect(route('login'));
    }

    public function test_authenticated_user_can_reach_their_own_dashboard(): void
    {
        $company = Company::factory()->create(['onboarding_completed' => true]);
        $user = User::factory()->create(['company_id' => $company->id]);

        $this->actingAs($user)
            ->get(route('dashboard'))
            ->assertOk()
            ->assertSee($company->name);
    }
}
