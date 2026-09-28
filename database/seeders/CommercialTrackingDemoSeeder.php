<?php

namespace Database\Seeders;

use App\Enums\ObjectiveScope;
use App\Models\Commercial;
use App\Models\CommercialObjective;
use App\Models\CommercialSale;
use App\Models\Company;
use App\Models\SalesCity;
use App\Models\SalesSector;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;

/**
 * Jeu de données réaliste pour le module "Suivi commercial" (§25 du
 * cahier des charges du module) : 3 commerciaux, 3 villes, 2 secteurs,
 * plusieurs mois de ventes et d'objectifs, pour que les calculs
 * (écart, taux d'atteinte, comparaison annuelle) soient visibles
 * immédiatement après installation.
 */
class CommercialTrackingDemoSeeder extends Seeder
{
    public function run(): void
    {
        $company = Company::where('name', 'Parallelium Demo')->first();

        if (! $company || SalesSector::withoutTenantScope()->where('company_id', $company->id)->exists()) {
            return;
        }

        $sectors = collect(['Centre', 'Nord'])->mapWithKeys(
            fn ($name) => [$name => SalesSector::create(['company_id' => $company->id, 'name' => $name, 'is_active' => true])->id]
        );

        $cities = collect(['Antananarivo', 'Toamasina', 'Antsirabe'])->mapWithKeys(
            fn ($name) => [$name => SalesCity::create(['company_id' => $company->id, 'name' => $name, 'is_active' => true])->id]
        );

        $sellerUser = User::where('company_id', $company->id)->where('email', 'seller@parallelium.demo')->first();
        $ownerUser = User::where('company_id', $company->id)->where('email', 'owner@parallelium.demo')->first();

        $commercials = [
            'CHAMINA' => Commercial::create([
                'company_id' => $company->id,
                'user_id' => $sellerUser?->id,
                'manager_id' => $ownerUser?->id,
                'first_name' => 'CHAMINA',
                'sector_id' => $sectors['Centre'],
                'city_id' => $cities['Antananarivo'],
                'is_active' => true,
            ]),
            'SAIDY' => Commercial::create([
                'company_id' => $company->id,
                'manager_id' => $ownerUser?->id,
                'first_name' => 'SAIDY',
                'sector_id' => $sectors['Centre'],
                'city_id' => $cities['Toamasina'],
                'is_active' => true,
            ]),
            'PONEY' => Commercial::create([
                'company_id' => $company->id,
                'manager_id' => $ownerUser?->id,
                'first_name' => 'PONEY',
                'sector_id' => $sectors['Nord'],
                'city_id' => $cities['Antsirabe'],
                'is_active' => true,
            ]),
        ];

        // Objectifs et réalisations sur les 3 derniers mois (dont le
        // mois courant), avec des volumes cohérents avec l'exemple du
        // cahier des charges (CHAMINA : objectif 725, réalisation 577).
        $monthlyTargets = [
            'CHAMINA' => 725,
            'SAIDY' => 450,
            'PONEY' => 600,
        ];
        $monthlyRealisationRatio = [
            'CHAMINA' => 0.796, // 79,6 % -> ~577
            'SAIDY' => 1.004,   // 100,4 % -> ~452
            'PONEY' => 1.075,   // 107,5 % -> ~645
        ];

        for ($monthsAgo = 2; $monthsAgo >= 0; $monthsAgo--) {
            $period = now()->subMonthsNoOverflow($monthsAgo);
            $year = (int) $period->format('Y');
            $month = (int) $period->format('n');

            $globalTarget = array_sum($monthlyTargets);
            CommercialObjective::create([
                'company_id' => $company->id,
                'year' => $year,
                'month' => $month,
                'scope' => ObjectiveScope::Global->value,
                'target_volume' => $globalTarget,
            ]);

            foreach ($commercials as $name => $commercial) {
                CommercialObjective::create([
                    'company_id' => $company->id,
                    'year' => $year,
                    'month' => $month,
                    'scope' => ObjectiveScope::Commercial->value,
                    'commercial_id' => $commercial->id,
                    'target_volume' => $monthlyTargets[$name],
                ]);

                $target = (int) round($monthlyTargets[$name] * $monthlyRealisationRatio[$name]);
                $this->spreadSalesAcrossMonth($company->id, $commercial, $year, $month, $target);
            }
        }
    }

    /**
     * Répartit un volume mensuel sur des jours ouvrés réalistes (jamais
     * une seule grosse ligne artificielle) pour que le suivi hebdomadaire
     * ait aussi des données à montrer.
     */
    protected function spreadSalesAcrossMonth(int $companyId, Commercial $commercial, int $year, int $month, int $totalVolume): void
    {
        $start = Carbon::create($year, $month, 1)->startOfMonth();
        $end = $start->copy()->endOfMonth();
        $workDays = collect();

        for ($d = $start->copy(); $d->lte($end); $d->addDay()) {
            if (! $d->isSunday()) {
                $workDays->push($d->copy());
            }
        }

        if ($workDays->isEmpty() || $totalVolume <= 0) {
            return;
        }

        $remaining = $totalVolume;
        $perDayBase = intdiv($totalVolume, $workDays->count());

        foreach ($workDays as $index => $day) {
            $isLast = $index === $workDays->count() - 1;
            $qty = $isLast ? $remaining : max(1, $perDayBase + rand(-2, 3));
            $qty = min($qty, $remaining);

            if ($qty <= 0) {
                continue;
            }

            CommercialSale::create([
                'company_id' => $companyId,
                'commercial_id' => $commercial->id,
                'sector_id' => $commercial->sector_id,
                'city_id' => $commercial->city_id,
                'sale_date' => $day->format('Y-m-d'),
                'quantity' => $qty,
                'entered_by' => $commercial->manager_id,
            ]);

            $remaining -= $qty;

            if ($remaining <= 0) {
                break;
            }
        }
    }
}
