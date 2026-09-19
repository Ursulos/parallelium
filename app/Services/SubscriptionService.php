<?php

namespace App\Services;

use App\Models\Company;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Sale;
use App\Models\Subscription;
use App\Models\User;
use RuntimeException;

/**
 * Point de passage UNIQUE pour vérifier les limites d'un plan
 * d'abonnement (§32 du cahier des charges). Aucune limite ne doit être
 * codée en dur ailleurs dans les contrôleurs ou services — tout passe
 * par assertCanCreate() ou usage().
 */
class SubscriptionService
{
    protected const COUNTERS = [
        'products' => Product::class,
        'users' => User::class,
        'customers' => Customer::class,
    ];

    public function assertCanCreate(Company $company, string $resource): void
    {
        $limit = $company->subscription?->limit($resource);

        if ($limit === null) {
            return; // pas d'abonnement (ne devrait pas arriver) ou illimité
        }

        $current = $this->currentCount($company, $resource);

        if ($current >= $limit) {
            $label = $this->resourceLabel($resource);
            throw new RuntimeException(
                "Le plan {$company->subscription->planConfig()['label']} autorise au maximum {$limit} {$label}. Passez à un plan supérieur pour continuer."
            );
        }
    }

    public function currentCount(Company $company, string $resource): int
    {
        if ($resource === 'sales_per_month') {
            return Sale::completed()
                ->whereBetween('sold_at', [now()->startOfMonth(), now()->endOfMonth()])
                ->count();
        }

        $modelClass = self::COUNTERS[$resource] ?? null;

        if (! $modelClass) {
            return 0;
        }

        return $modelClass::where('company_id', $company->id)->count();
    }

    /**
     * Utilisation actuelle vs limites du plan, pour affichage dans les
     * paramètres (§41) : ['products' => ['used' => 12, 'limit' => 50], ...].
     */
    public function usage(Company $company): array
    {
        $subscription = $company->subscription;

        $resources = ['products', 'users', 'customers', 'sales_per_month'];

        return collect($resources)->mapWithKeys(function ($resource) use ($company, $subscription) {
            return [$resource => [
                'used' => $this->currentCount($company, $resource),
                'limit' => $subscription?->limit($resource),
            ]];
        })->all();
    }

    public function changePlan(Company $company, string $planSlug): Subscription
    {
        if (! array_key_exists($planSlug, config('parallelium.plans'))) {
            throw new RuntimeException('Plan inconnu.');
        }

        $subscription = $company->subscription ?? new Subscription(['company_id' => $company->id]);
        $subscription->fill([
            'plan' => $planSlug,
            'status' => 'active',
            'current_period_ends_at' => now()->addMonth(),
        ])->save();

        return $subscription->fresh();
    }

    protected function resourceLabel(string $resource): string
    {
        return match ($resource) {
            'products' => 'produits',
            'users' => 'utilisateurs',
            'customers' => 'clients',
            'sales_per_month' => 'ventes par mois',
            default => $resource,
        };
    }
}
