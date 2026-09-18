<?php

namespace App\Services;

use App\Enums\StockMovementType;
use App\Models\Product;
use App\Models\StockMovement;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * Point de passage UNIQUE pour toute variation de stock.
 *
 * Règle du cahier des charges (§12) : ne jamais modifier stock_quantity
 * silencieusement. Chaque appel crée un StockMovement traçable et met
 * à jour le produit dans la même transaction.
 */
class StockService
{
    /**
     * Enregistre un mouvement de stock et applique la variation au produit.
     *
     * @param  int  $signedQuantity  Négatif pour une sortie, positif pour une entrée.
     * @param  bool  $allowNegative  Si false, lève une exception si le stock deviendrait négatif.
     */
    public function record(
        Product $product,
        StockMovementType $type,
        int $signedQuantity,
        ?string $reason = null,
        ?Model $reference = null,
        ?User $user = null,
        bool $allowNegative = false,
    ): StockMovement {
        return DB::transaction(function () use ($product, $type, $signedQuantity, $reason, $reference, $user, $allowNegative) {
            // Verrouille la ligne produit le temps de la transaction pour
            // éviter une situation de course (deux ventes simultanées).
            $product = Product::whereKey($product->id)->lockForUpdate()->firstOrFail();

            $newQuantity = $product->stock_quantity + $signedQuantity;

            if (! $allowNegative && $newQuantity < 0) {
                throw new RuntimeException("Stock insuffisant pour « {$product->name} ».");
            }

            $movement = StockMovement::create([
                'company_id' => $product->company_id,
                'product_id' => $product->id,
                'type' => $type,
                'quantity' => $signedQuantity,
                'reason' => $reason,
                'reference_type' => $reference?->getMorphClass(),
                'reference_id' => $reference?->getKey(),
                'user_id' => $user?->id ?? Auth::id(),
            ]);

            $product->update(['stock_quantity' => $newQuantity]);

            return $movement;
        });
    }

    /**
     * Ajustement manuel saisi par un utilisateur (correction d'inventaire,
     * perte constatée, entrée de stock hors achat...).
     */
    public function adjust(Product $product, int $signedQuantity, StockMovementType $type, ?string $reason = null): StockMovement
    {
        return $this->record($product, $type, $signedQuantity, $reason, allowNegative: $type === StockMovementType::Correction);
    }
}
