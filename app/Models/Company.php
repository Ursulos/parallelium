<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;

class Company extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'name',
        'legal_name',
        'logo',
        'email',
        'phone',
        'address',
        'city',
        'country',
        'currency',
        'timezone',
        'business_type',
        'tax_identifier',
        'invoice_prefix',
        'onboarding_completed',
        'status',
    ];

    protected function casts(): array
    {
        return [
            'onboarding_completed' => 'boolean',
        ];
    }

    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }

    public function subscription(): HasOne
    {
        return $this->hasOne(Subscription::class);
    }

    public function activityLogs(): HasMany
    {
        return $this->hasMany(ActivityLog::class);
    }

    // Relations utilisées par le panneau admin plateforme (statistiques
    // par entreprise) — voir App\Http\Controllers\Admin\CompanyController.
    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }

    public function customers(): HasMany
    {
        return $this->hasMany(Customer::class);
    }

    public function sales(): HasMany
    {
        return $this->hasMany(Sale::class);
    }

    /**
     * Devise formatée selon config('parallelium.currencies').
     * Ne jamais coder le symbole "Ar" en dur dans les vues : utiliser
     * $company->currencySymbol() ou le helper App\Support\Money.
     */
    public function currencySymbol(): string
    {
        return config("parallelium.currencies.{$this->currency}.symbol", $this->currency);
    }

    /**
     * Le champ business_type peut contenir soit un mot-clé de catalogue
     * standard (ex. "epicerie_ppn"), soit un texte libre saisi via
     * "Autre" à l'onboarding. Ce helper affiche toujours un libellé
     * lisible, jamais le mot-clé brut.
     */
    public function businessTypeLabel(): ?string
    {
        if (! $this->business_type) {
            return null;
        }

        return \App\Services\BusinessCatalogService::options()[$this->business_type] ?? $this->business_type;
    }

    /**
     * Numéro de document suivant (facture, vente, dépense), unique par
     * entreprise. Incrémente atomiquement le compteur correspondant.
     */
    public function nextDocumentNumber(string $type): string
    {
        $column = "next_{$type}_number";
        $prefixKey = $type === 'invoice' ? $this->invoice_prefix : config("parallelium.document_prefixes.{$type}");

        $number = $this->{$column};

        $this->increment($column);

        return sprintf('%s-%s-%06d', $prefixKey, now()->format('Y'), $number);
    }
}
