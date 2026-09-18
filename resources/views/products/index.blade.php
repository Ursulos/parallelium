<x-layouts.app title="Produits">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Produits</h2>
            <p class="text-sm text-slate-500">{{ $products->total() }} produit{{ $products->total() > 1 ? 's' : '' }} au catalogue.</p>
        </div>

        <div class="flex items-center gap-2">
            <x-button :href="route('categories.index')" variant="secondary" size="sm">Catégories</x-button>
            <x-button :href="route('products.create')" size="sm"><x-icon name="plus" /> Ajouter un produit</x-button>
        </div>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
    @endif

    @if ($lowStockCount > 0)
        <x-alert type="warning" class="mb-4">
            {{ $lowStockCount }} produit{{ $lowStockCount > 1 ? 's ont' : ' a' }} un stock faible ou épuisé.
            <a href="{{ route('products.index', ['low_stock' => 1]) }}" class="font-semibold underline">Voir</a>
        </x-alert>
    @endif

    <form method="GET" class="mb-4 flex flex-wrap items-center gap-2">
        <div class="relative flex-1 min-w-[200px]">
            <x-icon name="search" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <x-input name="q" value="{{ request('q') }}" placeholder="Rechercher un produit, SKU, code-barres..." class="pl-10" />
        </div>

        <select name="category_id" class="rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400" onchange="this.form.submit()">
            <option value="">Toutes les catégories</option>
            @foreach ($categories as $category)
                <option value="{{ $category->id }}" @selected(request('category_id') == $category->id)>{{ $category->name }}</option>
            @endforeach
        </select>

        <label class="flex items-center gap-2 rounded-xl border border-slate-200 px-3 py-2.5 text-sm text-slate-600">
            <input type="checkbox" name="low_stock" value="1" @checked(request('low_stock')) onchange="this.form.submit()" class="rounded border-slate-300 text-brand-600 focus:ring-brand-400">
            Stock faible uniquement
        </label>

        <x-button type="submit" variant="ghost" size="sm">Filtrer</x-button>
    </form>

    @if ($products->isEmpty())
        <x-empty-state icon="products" title="Aucun produit pour le moment." description="Ajoutez votre premier produit pour commencer à gérer votre stock.">
            <x-slot:action>
                <x-button :href="route('products.create')">Ajouter un produit</x-button>
            </x-slot:action>
        </x-empty-state>
    @else
        <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            @foreach ($products as $product)
                <x-card>
                    <div class="flex items-start justify-between gap-2">
                        <div class="min-w-0">
                            <p class="truncate font-semibold text-slate-800">{{ $product->name }}</p>
                            <p class="text-xs text-slate-400">{{ $product->category?->name ?? 'Sans catégorie' }} · {{ $product->sku ?? 'Pas de SKU' }}</p>
                        </div>
                        @if ($product->isOutOfStock())
                            <x-badge tone="danger">Épuisé</x-badge>
                        @elseif ($product->isLowStock())
                            <x-badge tone="warning">Stock faible</x-badge>
                        @endif
                    </div>

                    <div class="mt-3 flex items-end justify-between">
                        <div>
                            <p class="text-lg font-bold text-slate-900"><x-money :amount="$product->selling_price" /></p>
                            <p class="text-xs text-slate-400">Achat : <x-money :amount="$product->purchase_price" /></p>
                        </div>
                        <p class="text-sm font-medium text-slate-600">
                            {{ $product->stock_quantity }} {{ $product->unit->label() }}
                        </p>
                    </div>

                    <div class="mt-4 flex items-center gap-3 border-t border-slate-100 pt-3 text-sm">
                        <a href="{{ route('products.edit', $product) }}" class="font-medium text-brand-600 hover:underline">Modifier</a>
                        <a href="{{ route('stock.index', ['product_id' => $product->id]) }}" class="font-medium text-slate-500 hover:underline">Mouvements</a>
                        <form method="POST" action="{{ route('products.destroy', $product) }}" onsubmit="return confirm('Supprimer ce produit ?');" class="ml-auto">
                            @csrf
                            @method('DELETE')
                            <button type="submit" class="font-medium text-red-500 hover:underline">Supprimer</button>
                        </form>
                    </div>
                </x-card>
            @endforeach
        </div>

        <div class="mt-5">{{ $products->links() }}</div>
    @endif
</x-layouts.app>
