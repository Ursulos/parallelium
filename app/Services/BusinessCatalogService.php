<?php

namespace App\Services;

use App\Models\Category;
use App\Models\Company;
use App\Models\Product;

/**
 * Ajoute au catalogue d'une entreprise la liste de produits standards de
 * son secteur (§40, onboarding — toujours à la demande explicite du
 * propriétaire, jamais automatique). Les prix restent à 0 : à
 * l'entrepreneur de les compléter selon son propre fournisseur.
 */
class BusinessCatalogService
{
    public function __construct(protected SubscriptionService $subscriptionService)
    {
    }

    public static function options(): array
    {
        return collect(config('business_catalogs'))
            ->mapWithKeys(fn ($catalog, $slug) => [$slug => $catalog['label']])
            ->all();
    }

    /**
     * @return array{created: int, skipped_duplicate: int, skipped_limit: int}
     */
    public function seed(Company $company, string $catalogSlug): array
    {
        $catalog = config("business_catalogs.{$catalogSlug}");

        if (! $catalog) {
            return ['created' => 0, 'skipped_duplicate' => 0, 'skipped_limit' => 0];
        }

        $existingNames = Product::where('company_id', $company->id)->pluck('name')->map(fn ($n) => mb_strtolower($n));

        $remaining = $company->subscription?->limit('products');
        $created = 0;
        $skippedDuplicate = 0;
        $skippedLimit = 0;

        foreach ($catalog['categories'] as $categoryName => $products) {
            $category = null;

            foreach ($products as $item) {
                if ($existingNames->contains(mb_strtolower($item['name']))) {
                    $skippedDuplicate++;

                    continue;
                }

                if ($remaining !== null && $remaining <= 0) {
                    $skippedLimit++;

                    continue;
                }

                // La catégorie n'est créée qu'à la première utilisation
                // réelle (§64 — pas de catégorie vide inutile).
                $category ??= Category::firstOrCreate(
                    ['company_id' => $company->id, 'name' => $categoryName],
                    ['is_active' => true]
                );

                Product::create([
                    'company_id' => $company->id,
                    'category_id' => $category->id,
                    'name' => $item['name'],
                    'unit' => $item['unit'],
                    'purchase_price' => 0,
                    'selling_price' => 0,
                    'stock_quantity' => 0,
                    'minimum_stock' => 5,
                    'is_active' => true,
                ]);

                $created++;
                if ($remaining !== null) {
                    $remaining--;
                }
            }
        }

        return ['created' => $created, 'skipped_duplicate' => $skippedDuplicate, 'skipped_limit' => $skippedLimit];
    }
}
