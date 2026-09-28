<?php

namespace Tests\Feature\Commercial;

use App\Enums\ObjectiveScope;
use App\Models\Commercial;
use App\Models\CommercialObjective;
use App\Models\CommercialSale;
use App\Models\Company;
use App\Models\Role;
use App\Models\SalesCity;
use App\Models\SalesSector;
use App\Models\User;
use App\Services\CommercialPerformanceService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

/**
 * Vérifie en priorité l'EXACTITUDE des calculs (§25 du cahier des
 * charges du module Suivi commercial) : écart, taux d'atteinte,
 * agrégations hebdo/mensuelle/annuelle, division par zéro, filtres,
 * historique conservé pour un commercial inactif.
 */
class CommercialPerformanceTest extends TestCase
{
    use RefreshDatabase;

    protected function ownerFor(Company $company): User
    {
        $role = Role::firstOrCreate(
            ['company_id' => null, 'slug' => 'owner'],
            ['name' => 'Propriétaire', 'is_system' => true]
        );

        return User::factory()->create(['company_id' => $company->id, 'role_id' => $role->id]);
    }

    protected function makeCommercial(Company $company, string $name, ?SalesSector $sector = null, ?SalesCity $city = null): Commercial
    {
        return Commercial::create([
            'company_id' => $company->id,
            'first_name' => $name,
            'sector_id' => $sector?->id,
            'city_id' => $city?->id,
            'is_active' => true,
        ]);
    }

    protected function addSale(Company $company, Commercial $commercial, string $date, int $qty): void
    {
        CommercialSale::create([
            'company_id' => $company->id,
            'commercial_id' => $commercial->id,
            'sector_id' => $commercial->sector_id,
            'city_id' => $commercial->city_id,
            'sale_date' => $date,
            'quantity' => $qty,
        ]);
    }

    public function test_performance_computes_ecart_and_taux_correctly(): void
    {
        $service = new CommercialPerformanceService();

        // Exemple exact du cahier des charges : 577 / 725 = 79,59 % -> 79,6 %.
        $result = $service->performance(577, 725);

        $this->assertEquals(-148, $result['ecart']);
        $this->assertEquals(79.6, $result['taux']);
    }

    public function test_performance_never_divides_by_zero_when_no_objective_is_set(): void
    {
        $service = new CommercialPerformanceService();

        $result = $service->performance(300, null);

        $this->assertNull($result['ecart']);
        $this->assertNull($result['taux']);
        $this->assertEquals(300, $result['realisation']);
    }

    public function test_performance_never_divides_by_zero_when_objective_is_zero(): void
    {
        $service = new CommercialPerformanceService();

        $result = $service->performance(50, 0);

        $this->assertNull($result['taux']);
    }

    public function test_weekly_breakdown_sums_per_day_and_computes_total(): void
    {
        $company = Company::factory()->create();
        $this->actingAs($this->ownerFor($company));
        $commercial = $this->makeCommercial($company, 'CHAMINA');

        $monday = Carbon::parse('2026-03-02'); // un lundi
        $this->addSale($company, $commercial, $monday->format('Y-m-d'), 20);
        $this->addSale($company, $commercial, $monday->copy()->addDay()->format('Y-m-d'), 15);
        // Dimanche ignoré par défaut.
        $this->addSale($company, $commercial, $monday->copy()->addDays(6)->format('Y-m-d'), 999);

        $service = new CommercialPerformanceService();
        $breakdown = $service->weeklyBreakdown($monday, $monday->copy()->addDays(6));

        $row = $breakdown->firstWhere('commercial.id', $commercial->id);

        $this->assertEquals(35, $row['total']); // 20 + 15, sans le dimanche
    }

    public function test_monthly_report_computes_team_total_and_per_commercial_rates(): void
    {
        $company = Company::factory()->create();
        $this->actingAs($this->ownerFor($company));
        $chamina = $this->makeCommercial($company, 'CHAMINA');
        $saidy = $this->makeCommercial($company, 'SAIDY');

        $year = 2026;
        $month = 1;

        CommercialObjective::create(['company_id' => $company->id, 'year' => $year, 'month' => $month, 'scope' => ObjectiveScope::Commercial->value, 'commercial_id' => $chamina->id, 'target_volume' => 725]);
        CommercialObjective::create(['company_id' => $company->id, 'year' => $year, 'month' => $month, 'scope' => ObjectiveScope::Commercial->value, 'commercial_id' => $saidy->id, 'target_volume' => 450]);

        $this->addSale($company, $chamina, "{$year}-01-05", 577);
        $this->addSale($company, $saidy, "{$year}-01-05", 452);

        $service = new CommercialPerformanceService();
        $report = $service->monthlyByCommercial($year, $month);

        $chaminaRow = $report['rows']->firstWhere('commercial.id', $chamina->id);
        $this->assertEquals(-148, $chaminaRow['ecart']);
        $this->assertEquals(79.6, $chaminaRow['taux']);

        $this->assertEquals(1175, $report['team']['objectif']); // 725 + 450
        $this->assertEquals(1029, $report['team']['realisation']); // 577 + 452
        $this->assertEquals(-146, $report['team']['ecart']);
    }

    public function test_annual_report_lines_up_all_twelve_months(): void
    {
        $company = Company::factory()->create();
        $this->actingAs($this->ownerFor($company));
        $commercial = $this->makeCommercial($company, 'CHAMINA');

        $this->addSale($company, $commercial, '2026-01-10', 100);
        $this->addSale($company, $commercial, '2026-04-10', 250);

        $service = new CommercialPerformanceService();
        $report = $service->annualByCommercial(2026);

        $row = $report['rows']->firstWhere('commercial.id', $commercial->id);

        $this->assertCount(12, $row['months']);
        $this->assertEquals(100, $row['months'][0]); // Janvier (index 0)
        $this->assertEquals(0, $row['months'][1]);   // Février : aucune vente
        $this->assertEquals(250, $row['months'][3]); // Avril (index 3)
        $this->assertEquals(350, $row['total']);
    }

    public function test_filters_by_sector_and_city_restrict_the_results(): void
    {
        $company = Company::factory()->create();
        $this->actingAs($this->ownerFor($company));
        $sectorCentre = SalesSector::factory()->create(['company_id' => $company->id, 'name' => 'Centre']);
        $sectorNord = SalesSector::factory()->create(['company_id' => $company->id, 'name' => 'Nord']);
        $cityTana = SalesCity::factory()->create(['company_id' => $company->id, 'name' => 'Antananarivo']);

        $chamina = $this->makeCommercial($company, 'CHAMINA', $sectorCentre, $cityTana);
        $poney = $this->makeCommercial($company, 'PONEY', $sectorNord);

        $this->addSale($company, $chamina, '2026-02-10', 100);
        $this->addSale($company, $poney, '2026-02-10', 300);

        $service = new CommercialPerformanceService();

        $centreOnly = $service->realization(Carbon::parse('2026-02-01'), Carbon::parse('2026-02-28'), ['sector_id' => $sectorCentre->id]);
        $this->assertEquals(100, $centreOnly);

        $tanaOnly = $service->realization(Carbon::parse('2026-02-01'), Carbon::parse('2026-02-28'), ['city_id' => $cityTana->id]);
        $this->assertEquals(100, $tanaOnly);
    }

    public function test_an_inactive_commercials_sales_history_remains_intact(): void
    {
        $company = Company::factory()->create();
        $this->actingAs($this->ownerFor($company));
        $commercial = $this->makeCommercial($company, 'CHAMINA');
        $this->addSale($company, $commercial, '2026-01-15', 400);

        $commercial->update(['is_active' => false]);
        $commercial->delete(); // soft delete, comme un employé qui quitte l'entreprise

        $service = new CommercialPerformanceService();
        $realisation = $service->realization(Carbon::parse('2026-01-01'), Carbon::parse('2026-01-31'), ['commercial_id' => $commercial->id]);

        $this->assertEquals(400, $realisation);
        $this->assertSoftDeleted($commercial);
    }

    public function test_objective_consistency_reports_the_gap_without_blocking_anything(): void
    {
        $company = Company::factory()->create();
        $this->actingAs($this->ownerFor($company));
        $a = $this->makeCommercial($company, 'A');
        $b = $this->makeCommercial($company, 'B');
        $c = $this->makeCommercial($company, 'C');

        CommercialObjective::create(['company_id' => $company->id, 'year' => 2026, 'month' => 1, 'scope' => ObjectiveScope::Global->value, 'target_volume' => 10000]);
        CommercialObjective::create(['company_id' => $company->id, 'year' => 2026, 'month' => 1, 'scope' => ObjectiveScope::Commercial->value, 'commercial_id' => $a->id, 'target_volume' => 3000]);
        CommercialObjective::create(['company_id' => $company->id, 'year' => 2026, 'month' => 1, 'scope' => ObjectiveScope::Commercial->value, 'commercial_id' => $b->id, 'target_volume' => 2500]);
        CommercialObjective::create(['company_id' => $company->id, 'year' => 2026, 'month' => 1, 'scope' => ObjectiveScope::Commercial->value, 'commercial_id' => $c->id, 'target_volume' => 2000]);

        $service = new CommercialPerformanceService();
        $consistency = $service->objectiveConsistency(2026, 1);

        $this->assertEquals(10000, $consistency['global']);
        $this->assertEquals(7500, $consistency['individual_sum']);
        $this->assertEquals(2500, $consistency['difference']);
    }

    public function test_no_objective_defined_returns_null_consistency(): void
    {
        $company = Company::factory()->create();
        $this->actingAs($this->ownerFor($company));

        $service = new CommercialPerformanceService();
        $this->assertNull($service->objectiveConsistency(2026, 6));
    }

    public function test_a_companys_commercial_data_never_leaks_to_another_company(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();

        $this->actingAs($this->ownerFor($companyB));
        $commercialB = $this->makeCommercial($companyB, 'COMMERCIAL B');
        $this->addSale($companyB, $commercialB, '2026-03-10', 999);

        $this->actingAs($this->ownerFor($companyA));
        $commercialA = $this->makeCommercial($companyA, 'COMMERCIAL A');
        $this->addSale($companyA, $commercialA, '2026-03-10', 50);

        $service = new CommercialPerformanceService();
        $realisation = $service->realization(Carbon::parse('2026-03-01'), Carbon::parse('2026-03-31'));

        // Authentifié sur l'entreprise A : seule sa propre donnée doit
        // apparaître, jamais les 999 unités de l'entreprise B.
        $this->assertEquals(50, $realisation);
    }
}
