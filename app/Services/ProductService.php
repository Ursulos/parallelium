<?php

namespace App\Services;

use App\Enums\StockMovementType;
use App\Models\Product;
use Illuminate\Support\Facades\DB;

class ProductService
{
    public function __construct(protected StockService $stockService)
    {
    }

    public function create(array $data): Product
    {
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
