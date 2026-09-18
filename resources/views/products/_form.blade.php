@csrf
@if ($product ?? null)
    @method('PUT')
@endif

<div class="grid gap-4 sm:grid-cols-2">
    <div class="sm:col-span-2">
        <x-label for="name">Nom du produit</x-label>
        <x-input id="name" name="name" value="{{ old('name', $product->name ?? '') }}" required autofocus />
    </div>

    <div>
        <x-label for="category_id">Catégorie</x-label>
        <select id="category_id" name="category_id" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400">
            <option value="">Sans catégorie</option>
            @foreach ($categories as $category)
                <option value="{{ $category->id }}" @selected(old('category_id', $product->category_id ?? null) == $category->id)>{{ $category->name }}</option>
            @endforeach
        </select>
    </div>

    <div>
        <x-label for="unit">Unité</x-label>
        <select id="unit" name="unit" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400">
            @foreach (\App\Enums\ProductUnit::options() as $value => $label)
                <option value="{{ $value }}" @selected(old('unit', $product->unit->value ?? 'unite') === $value)>{{ $label }}</option>
            @endforeach
        </select>
    </div>

    <div>
        <x-label for="sku">SKU (référence interne)</x-label>
        <x-input id="sku" name="sku" value="{{ old('sku', $product->sku ?? '') }}" placeholder="Optionnel" />
    </div>

    <div>
        <x-label for="barcode">Code-barres</x-label>
        <x-input id="barcode" name="barcode" value="{{ old('barcode', $product->barcode ?? '') }}" placeholder="Optionnel" />
    </div>

    <div>
        <x-label for="purchase_price">Prix d'achat</x-label>
        <x-input id="purchase_price" type="number" step="0.01" min="0" name="purchase_price" value="{{ old('purchase_price', $product->purchase_price ?? 0) }}" required />
    </div>

    <div>
        <x-label for="selling_price">Prix de vente</x-label>
        <x-input id="selling_price" type="number" step="0.01" min="0" name="selling_price" value="{{ old('selling_price', $product->selling_price ?? 0) }}" required />
    </div>

    @unless ($product ?? null)
        <div>
            <x-label for="stock_quantity">Stock initial</x-label>
            <x-input id="stock_quantity" type="number" min="0" name="stock_quantity" value="{{ old('stock_quantity', 0) }}" />
        </div>
    @endunless

    <div>
        <x-label for="minimum_stock">Stock minimum (alerte)</x-label>
        <x-input id="minimum_stock" type="number" min="0" name="minimum_stock" value="{{ old('minimum_stock', $product->minimum_stock ?? 5) }}" />
    </div>

    <div class="sm:col-span-2">
        <x-label for="description">Description</x-label>
        <textarea id="description" name="description" rows="3" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400">{{ old('description', $product->description ?? '') }}</textarea>
    </div>
</div>

<div class="mt-6 flex items-center gap-3">
    <x-button type="submit">{{ ($product ?? null) ? 'Enregistrer les modifications' : 'Ajouter le produit' }}</x-button>
    <x-button :href="route('products.index')" variant="ghost" type="button">Annuler</x-button>
</div>
