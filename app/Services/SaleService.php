<?php

namespace App\Services;

use App\Enums\PaymentStatus;
use App\Enums\SaleStatus;
use App\Enums\StockMovementType;
use App\Models\Product;
use App\Models\Sale;
use App\Models\User;
use App\Support\Tenant;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * Flux d'une vente (cahier des charges §15) :
 * vérifier le stock -> calculer le montant -> créer la vente -> créer les
 * lignes -> enregistrer le paiement -> diminuer le stock -> créer le
 * mouvement de stock -> mettre à jour les indicateurs.
 *
 * RÈGLE CAPITALE (§49) : le serveur recalcule TOUJOURS le sous-total, la
 * remise, le total, le paiement et le reste. Le prix unitaire vient de
 * Product::selling_price en base, jamais d'une valeur envoyée par le
 * navigateur. Toute l'opération est atomique (DB::transaction) : si une
 * étape échoue, tout est annulé.
 */
class SaleService
{
    public function __construct(protected StockService $stockService)
    {
    }

    public function create(array $data, User $user): Sale
    {
        return DB::transaction(function () use ($data, $user) {
            $company = Tenant::current();

            // 1. Charger les produits réels (jamais les prix du frontend),
            //    avec verrou pour éviter une vente en double sur un stock
            //    limité (course entre deux ventes simultanées).
            $productIds = collect($data['items'])->pluck('product_id');
            $products = Product::whereIn('id', $productIds)->lockForUpdate()->get()->keyBy('id');

            $subtotal = 0;
            $lines = [];

            foreach ($data['items'] as $item) {
                $product = $products->get($item['product_id']);

                if (! $product) {
                    throw new RuntimeException('Produit introuvable.');
                }

                // 2. Vérifier le stock.
                if ($product->stock_quantity < $item['quantity']) {
                    throw new RuntimeException("Stock insuffisant pour « {$product->name} » (disponible : {$product->stock_quantity}).");
                }

                $lineDiscount = (float) ($item['discount'] ?? 0);
                $lineSubtotal = ($product->selling_price * $item['quantity']) - $lineDiscount;

                $lines[] = [
                    'product' => $product,
                    'quantity' => (int) $item['quantity'],
                    'unit_price' => $product->selling_price,
                    'discount' => $lineDiscount,
                    'subtotal' => $lineSubtotal,
                ];

                $subtotal += $lineSubtotal;
            }

            // 3. Calculer le montant total (remise globale déduite).
            $globalDiscount = (float) ($data['discount'] ?? 0);
            $totalAmount = max(0, $subtotal - $globalDiscount);

            $paidAmount = (float) ($data['paid_amount'] ?? 0);
            if ($paidAmount > $totalAmount) {
                throw new RuntimeException('Le montant payé ne peut pas dépasser le total de la vente.');
            }

            $remainingAmount = $totalAmount - $paidAmount;

            // 4. Créer la vente.
            $sale = Sale::create([
                'company_id' => $company->id,
                'customer_id' => $data['customer_id'] ?? null,
                'user_id' => $user->id,
                'sale_number' => $company->nextDocumentNumber('sale'),
                'subtotal' => $subtotal,
                'discount' => $globalDiscount,
                'total_amount' => $totalAmount,
                'paid_amount' => $paidAmount,
                'remaining_amount' => $remainingAmount,
                'payment_status' => PaymentStatus::fromAmounts($totalAmount, $paidAmount),
                'sale_status' => SaleStatus::Completed,
                'payment_method' => $data['payment_method'],
                'notes' => $data['notes'] ?? null,
                'sold_at' => now(),
            ]);

            // 5. Créer les lignes + 6/7. Diminuer le stock et tracer le mouvement.
            foreach ($lines as $line) {
                $sale->items()->create([
                    'product_id' => $line['product']->id,
                    'quantity' => $line['quantity'],
                    'unit_price' => $line['unit_price'],
                    'discount' => $line['discount'],
                    'subtotal' => $line['subtotal'],
                ]);

                $this->stockService->record(
                    $line['product'],
                    StockMovementType::Sale,
                    -$line['quantity'],
                    "Vente {$sale->sale_number}",
                    $sale,
                    $user,
                );
            }

            return $sale->fresh(['items.product', 'customer']);
        });
    }

    /**
     * Annule une vente : restaure le stock (mouvement "return" tracé,
     * jamais un simple update silencieux — §54) et marque la vente comme
     * annulée. Les ventes déjà annulées ne peuvent pas l'être à nouveau.
     */
    public function cancel(Sale $sale, User $user): Sale
    {
        return DB::transaction(function () use ($sale, $user) {
            if ($sale->isCancelled()) {
                throw new RuntimeException('Cette vente est déjà annulée.');
            }

            foreach ($sale->items()->with('product')->get() as $item) {
                if (! $item->product) {
                    continue;
                }

                $this->stockService->record(
                    $item->product,
                    StockMovementType::Return,
                    $item->quantity,
                    "Annulation vente {$sale->sale_number}",
                    $sale,
                    $user,
                );
            }

            $sale->update(['sale_status' => SaleStatus::Cancelled]);

            return $sale->fresh();
        });
    }
}
