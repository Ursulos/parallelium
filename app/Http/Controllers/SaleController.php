<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreSaleRequest;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Sale;
use App\Services\SaleService;
use Illuminate\Http\Request;
use RuntimeException;

class SaleController extends Controller
{
    public function index(Request $request)
    {
        $this->authorize('sales.view');

        $sales = Sale::with(['customer', 'user'])
            ->when($request->filled('status'), fn ($q) => $q->where('payment_status', $request->string('status')))
            ->latest('sold_at')
            ->paginate(15)
            ->withQueryString();

        return view('sales.index', compact('sales'));
    }

    public function create()
    {
        $this->authorize('sales.create');

        $products = Product::active()
            ->where('stock_quantity', '>', 0)
            ->orderBy('name')
            ->get(['id', 'name', 'sku', 'selling_price', 'stock_quantity', 'minimum_stock', 'unit']);

        $customers = Customer::active()->orderBy('name')->get(['id', 'name', 'phone']);

        return view('sales.create', compact('products', 'customers'));
    }

    public function store(StoreSaleRequest $request, SaleService $saleService)
    {
        try {
            $sale = $saleService->create($request->validated(), $request->user());
        } catch (RuntimeException $e) {
            return back()->withErrors(['items' => $e->getMessage()])->withInput();
        }

        return redirect()->route('sales.show', $sale)->with('status', 'Vente enregistrée.');
    }

    public function show(Sale $sale)
    {
        $this->authorize('sales.view');

        $sale->load(['items.product', 'customer', 'user']);

        return view('sales.show', compact('sale'));
    }

    public function cancel(Sale $sale, SaleService $saleService)
    {
        $this->authorize('sales.cancel');

        try {
            $saleService->cancel($sale, request()->user());
        } catch (RuntimeException $e) {
            return back()->withErrors(['sale' => $e->getMessage()]);
        }

        return back()->with('status', 'Vente annulée, le stock a été restauré.');
    }
}
