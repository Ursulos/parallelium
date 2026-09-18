<?php

namespace App\Http\Controllers;

use App\Enums\StockMovementType;
use App\Http\Requests\AdjustStockRequest;
use App\Models\Product;
use App\Models\StockMovement;
use App\Services\StockService;
use Illuminate\Http\Request;
use RuntimeException;

class StockController extends Controller
{
    public function index(Request $request)
    {
        $this->authorize('stock.view');

        $movements = StockMovement::with(['product', 'user'])
            ->when($request->filled('product_id'), fn ($q) => $q->where('product_id', $request->integer('product_id')))
            ->latest('created_at')
            ->paginate(20)
            ->withQueryString();

        $lowStockProducts = Product::active()->lowStock()->orderBy('stock_quantity')->get();
        $products = Product::active()->orderBy('name')->get();

        return view('stock.index', compact('movements', 'lowStockProducts', 'products'));
    }

    public function adjust(AdjustStockRequest $request, Product $product, StockService $stockService)
    {
        $this->authorize('stock.manage');

        $type = StockMovementType::from($request->validated('type'));
        $quantity = $request->validated('quantity');

        // Le sens du mouvement dépend du TYPE choisi côté serveur, jamais
        // d'un signe envoyé par le formulaire : un achat est toujours une
        // entrée, une perte est toujours une sortie.
        $signedQuantity = $type === StockMovementType::Loss ? -$quantity : $quantity;

        try {
            $stockService->adjust($product, $signedQuantity, $type, $request->validated('reason'));
        } catch (RuntimeException $e) {
            return back()->withErrors(['quantity' => $e->getMessage()]);
        }

        return back()->with('status', "Stock de « {$product->name} » mis à jour.");
    }
}
