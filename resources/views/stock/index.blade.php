<x-layouts.app title="Stock">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Stock</h2>
            <p class="text-sm text-slate-500">Historique des mouvements et alertes de stock faible.</p>
        </div>

        <div x-data="{ open: false, productId: '{{ request('product_id') }}' }">
            <x-button @click="open = true" size="sm"><x-icon name="plus" /> Ajuster un stock</x-button>

            <div x-show="open" x-cloak class="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 p-4">
                <div x-show="open" x-on:click.outside="open = false" x-transition class="w-full max-w-sm rounded-2xl bg-white p-5 shadow-xl">
                    <h3 class="mb-4 text-base font-semibold text-slate-800">Ajuster un stock</h3>

                    <form method="POST" x-bind:action="productId ? '/stock/' + productId + '/adjust' : '#'" class="space-y-3">
                        @csrf
                        <div>
                            <x-label for="adjust_product">Produit</x-label>
                            <select id="adjust_product" x-model="productId" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400" required>
                                <option value="">Sélectionner...</option>
                                @foreach ($products as $product)
                                    <option value="{{ $product->id }}">{{ $product->name }} ({{ $product->stock_quantity }} {{ $product->unit->label() }})</option>
                                @endforeach
                            </select>
                        </div>

                        <div>
                            <x-label for="type">Type de mouvement</x-label>
                            <select id="type" name="type" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400" required>
                                <option value="purchase">Entrée de stock (achat)</option>
                                <option value="loss">Perte</option>
                                <option value="correction">Correction d'inventaire</option>
                            </select>
                        </div>

                        <div>
                            <x-label for="quantity">Quantité</x-label>
                            <x-input id="quantity" type="number" min="1" name="quantity" required />
                        </div>

                        <div>
                            <x-label for="reason">Motif (optionnel)</x-label>
                            <x-input id="reason" name="reason" placeholder="Ex. Réception fournisseur" />
                        </div>

                        <div class="flex justify-end gap-2 pt-2">
                            <x-button type="button" variant="ghost" @click="open = false">Annuler</x-button>
                            <x-button type="submit">Enregistrer</x-button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
    @endif
    @if ($errors->any())
        <x-alert type="error" class="mb-4">{{ $errors->first() }}</x-alert>
    @endif

    @if ($lowStockProducts->isNotEmpty())
        <x-card class="mb-5">
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Produits en stock faible</h3>
            <div class="flex flex-wrap gap-2">
                @foreach ($lowStockProducts as $product)
                    <a href="{{ route('stock.index', ['product_id' => $product->id]) }}"
                       class="flex items-center gap-2 rounded-full border border-amber-200 bg-amber-50 px-3 py-1.5 text-xs font-medium text-amber-800">
                        {{ $product->name }}
                        <span class="rounded-full bg-amber-200 px-1.5">{{ $product->stock_quantity }}</span>
                    </a>
                @endforeach
            </div>
        </x-card>
    @endif

    @if (request('product_id'))
        <div class="mb-3">
            <a href="{{ route('stock.index') }}" class="text-sm font-medium text-brand-600 hover:underline">&larr; Voir tous les mouvements</a>
        </div>
    @endif

    @if ($movements->isEmpty())
        <x-empty-state icon="stock" title="Aucun mouvement de stock." description="Les entrées, ventes et ajustements de stock apparaîtront ici, chacun tracé individuellement." />
    @else
        <x-card :padded="false">
            <div class="divide-y divide-slate-100">
                @foreach ($movements as $movement)
                    <div class="flex items-center justify-between gap-3 px-5 py-3">
                        <div class="min-w-0">
                            <p class="truncate text-sm font-medium text-slate-800">{{ $movement->product->name }}</p>
                            <p class="text-xs text-slate-400">
                                {{ $movement->type->label() }}
                                @if ($movement->reason) · {{ $movement->reason }} @endif
                                · {{ $movement->created_at->format('d/m/Y H:i') }}
                                @if ($movement->user) · {{ $movement->user->name }} @endif
                            </p>
                        </div>
                        <span class="shrink-0 text-sm font-bold {{ $movement->quantity >= 0 ? 'text-emerald-600' : 'text-red-500' }}">
                            {{ $movement->quantity >= 0 ? '+' : '' }}{{ $movement->quantity }}
                        </span>
                    </div>
                @endforeach
            </div>
        </x-card>

        <div class="mt-5">{{ $movements->links() }}</div>
    @endif
</x-layouts.app>
