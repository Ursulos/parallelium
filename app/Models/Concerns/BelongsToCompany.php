<?php

namespace App\Models\Concerns;

use App\Models\Company;
use App\Support\Tenant;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Isole automatiquement les données par entreprise (tenant).
 *
 * - Un global scope filtre TOUJOURS les requêtes sur company_id de
 *   l'entreprise courante (jamais sur une valeur envoyée par le navigateur).
 * - À la création, company_id est renseigné automatiquement.
 *
 * Ne JAMAIS faire confiance à un company_id transmis par le client :
 * il est ici résolu uniquement depuis App\Support\Tenant (contexte serveur,
 * basé sur l'utilisateur authentifié).
 */
trait BelongsToCompany
{
    public static function bootBelongsToCompany(): void
    {
        static::addGlobalScope('company', function (Builder $builder) {
            if (Tenant::check()) {
                $builder->where($builder->getModel()->getTable().'.company_id', Tenant::id());
            }
        });

        static::creating(function ($model) {
            if (! $model->company_id && Tenant::check()) {
                $model->company_id = Tenant::id();
            }
        });
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    /**
     * Permet d'accéder volontairement aux données de toutes les entreprises
     * (ex: job planifié, commande artisan). À utiliser avec une extrême
     * prudence, jamais dans un contrôleur exposé à l'utilisateur.
     */
    public function scopeWithoutTenantScope(Builder $builder): Builder
    {
        return $builder->withoutGlobalScope('company');
    }
}
