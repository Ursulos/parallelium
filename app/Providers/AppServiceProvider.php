<?php

namespace App\Providers;

use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Vite;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        // Toutes les permissions passent par le rôle de l'utilisateur.
        // Ceci permet d'écrire @can('sales.create') dans les vues et
        // $this->authorize('sales.create') dans les contrôleurs pour
        // n'importe quelle permission définie en base, sans avoir à
        // déclarer un Gate::define() par permission.
        Gate::before(function ($user, string $ability) {
            if (! str_contains($ability, '.')) {
                return null; // laisse les Policies "classiques" gérer les autres abilities
            }

            if ($user->isOwner()) {
                return true;
            }

            return $user->hasPermission($ability) ?: null;
        });

        Vite::prefetch(concurrency: 3);
    }
}
