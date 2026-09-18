<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreProductRequest;
use App\Http\Requests\UpdateProductRequest;
use App\Models\Category;
use App\Models\Product;
use App\Services\ProductService;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $this->authorize('products.view');

        $products = Product::with('category')
            ->search($request->string('q')->toString())
            ->when($request->boolean('low_stock'), fn ($q) => $q->lowStock())
            ->when($request->filled('category_id'), fn ($q) => $q->where('category_id', $request->integer('category_id')))
            ->orderBy('name')
            ->paginate(15)
            ->withQueryString();

        $categories = Category::orderBy('name')->get();
        $lowStockCount = Product::active()->lowStock()->count();

        return view('products.index', compact('products', 'categories', 'lowStockCount'));
    }

    public function create()
    {
        $this->authorize('products.create');

        $categories = Category::active()->orderBy('name')->get();

        return view('products.create', compact('categories'));
    }

    public function store(StoreProductRequest $request, ProductService $productService)
    {
        $productService->create($request->validated());

        return redirect()->route('products.index')->with('status', 'Produit ajouté.');
    }

    public function edit(Product $product)
    {
        $this->authorize('products.update');

        $categories = Category::active()->orderBy('name')->get();

        return view('products.edit', compact('product', 'categories'));
    }

    public function update(UpdateProductRequest $request, Product $product, ProductService $productService)
    {
        $productService->update($product, $request->validated());

        return redirect()->route('products.index')->with('status', 'Produit mis à jour.');
    }

    public function destroy(Product $product, ProductService $productService)
    {
        $this->authorize('products.delete');

        $productService->delete($product);

        return back()->with('status', 'Produit supprimé.');
    }
}
