<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreCategoryRequest;
use App\Http\Requests\UpdateCategoryRequest;
use App\Models\Category;

class CategoryController extends Controller
{
    public function index()
    {
        $this->authorize('products.view');

        $categories = Category::withCount('products')
            ->orderBy('name')
            ->paginate(20);

        return view('categories.index', compact('categories'));
    }

    public function store(StoreCategoryRequest $request)
    {
        Category::create($request->validated());

        return back()->with('status', 'Catégorie ajoutée.');
    }

    public function update(UpdateCategoryRequest $request, Category $category)
    {
        $category->update($request->validated());

        return back()->with('status', 'Catégorie mise à jour.');
    }

    public function destroy(Category $category)
    {
        $this->authorize('products.delete');

        if ($category->products()->exists()) {
            return back()->withErrors([
                'category' => "Impossible de supprimer « {$category->name} » : des produits y sont rattachés.",
            ]);
        }

        $category->delete();

        return back()->with('status', 'Catégorie supprimée.');
    }
}
