<?php

namespace App\Services;

use App\Enums\StockMovementType;
use App\Models\Company;
use App\Models\Product;
use App\Support\Tenant;
use Illuminate\Support\Facades\DB;

class ProductService
{
    public function __construct(
        protected StockService $stockService,
        protected SubscriptionService $subscriptionService,
    ) {
    }

    public function create(array $data): Product
    {
        // Tenant::current() est vide hors contexte HTTP authentifié (ex.
        // seeders, commandes artisan) : dans ce cas on se base sur le
        // company_id fourni explicitement plutôt que de planter, et on
        // saute la vérification de plan (contexte administratif, jamais
        // exposé à un utilisateur final).
        $company = Tenant::current() ?? (isset($data['company_id']) ? Company::find($data['company_id']) : null);

        if ($company && Tenant::check()) {
            $this->subscriptionService->assertCanCreate($company, 'products');
        }

        return DB::transaction(function () use ($data) {
            $initialStock = (int) ($data['stock_quantity'] ?? 0);
            unset($data['stock_quantity']);

            /** @var Product $product */
            $product = Product::create([...$data, 'stock_quantity' => 0]);

            if ($initialStock > 0) {
                $this->stockService->record(
                    $product,
                    StockMovementType::Adjustment,
                    $initialStock,
                    'Stock initial'
                );
            }

            return $product->fresh();
        });
    }

    /**
     * Le stock ne se modifie JAMAIS via update() : uniquement via
     * StockService::adjust(), pour rester traçable.
     */
    public function update(Product $product, array $data): Product
    {
        unset($data['stock_quantity']);

        $product->update($data);

        return $product->fresh();
    }

    public function delete(Product $product): void
    {
        $product->update(['is_active' => false]);
        $product->delete();
    }
}
