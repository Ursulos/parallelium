<x-layouts.app title="Nouvelle vente">
    <div x-data="saleForm({
            products: {{ \Illuminate\Support\Js::from($products) }},
            currencySymbol: {{ \Illuminate\Support\Js::from(auth()->user()->company->currencySymbol()) }},
        })" x-init="init()">

        <div class="mb-5 flex items-center justify-between">
            <div>
                <h2 class="text-xl font-bold text-slate-900">Nouvelle vente</h2>
                <p class="text-sm text-slate-500">Sélectionnez les produits, le reste est calculé automatiquement.</p>
            </div>
            <x-button :href="route('sales.index')" variant="ghost" size="sm">Annuler</x-button>
        </div>

        @if ($errors->any())
            <x-alert type="error" class="mb-4">{{ $errors->first() }}</x-alert>
        @endif

        <form method="POST" action="{{ route('sales.store') }}">
            @csrf

            <div class="grid gap-4 lg:grid-cols-5">
                {{-- Catalogue --}}
                <div class="lg:col-span-3">
                    <div class="relative mb-3">
                        <x-icon name="search" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                        <input type="text" x-model="search" placeholder="Rechercher un produit ou un SKU..."
                               class="w-full rounded-xl border border-slate-200 py-3 pl-10 pr-4 text-base focus:outline-none focus:ring-2 focus:ring-brand-400">
                    </div>

                    <div class="grid grid-cols-2 gap-2 sm:grid-cols-3">
                        <template x-for="product in filteredProducts()" :key="product.id">
                            <button type="button" x-on:click="addToCart(product)"
                                    class="rounded-2xl border border-slate-100 bg-white p-3 text-left transition hover:border-brand-200 hover:shadow-sm active:scale-95">
                                <p class="truncate text-sm font-semibold text-slate-800" x-text="product.name"></p>
                                <p class="mt-0.5 text-xs text-slate-400" x-text="product.stock_quantity + ' ' + product.unit + ' dispo.'"></p>
                                <p class="mt-1 text-sm font-bold text-brand-700" x-text="formatMoney(product.selling_price)"></p>
                            </button>
                        </template>
                    </div>

                    <p x-show="filteredProducts().length === 0" x-cloak class="mt-4 text-center text-sm text-slate-400">
                        Aucun produit ne correspond à la recherche.
                    </p>
                </div>

                {{-- Panier --}}
                <div class="lg:col-span-2">
                    <x-card>
                        <h3 class="mb-3 text-sm font-semibold text-slate-700">Panier</h3>

                        <p x-show="cart.length === 0" x-cloak class="rounded-xl border border-dashed border-slate-200 py-8 text-center text-sm text-slate-400">
                            Ajoutez des produits depuis le catalogue.
                        </p>

                        <div class="space-y-2" x-show="cart.length > 0">
                            <template x-for="(item, index) in cart" :key="item.product_id">
                                <div class="flex items-center gap-2 rounded-xl border border-slate-100 p-2">
                                    <div class="min-w-0 flex-1">
                                        <p class="truncate text-sm font-medium text-slate-800" x-text="item.name"></p>
                                        <p class="text-xs text-slate-400" x-text="formatMoney(item.unit_price) + ' / ' + item.unit"></p>
                                    </div>

                                    <div class="flex items-center gap-1">
                                        <button type="button" x-on:click="changeQuantity(index, -1)" class="flex h-7 w-7 items-center justify-center rounded-full bg-slate-100 text-slate-600">-</button>
                                        <input type="number" min="1" :max="item.max" x-model.number="item.quantity" x-on:change="clampQuantity(index)" class="w-12 rounded-lg border border-slate-200 py-1 text-center text-sm">
                                        <button type="button" x-on:click="changeQuantity(index, 1)" class="flex h-7 w-7 items-center justify-center rounded-full bg-slate-100 text-slate-600">+</button>
                                    </div>

                                    <p class="w-20 shrink-0 text-right text-sm font-semibold text-slate-800" x-text="formatMoney(item.quantity * item.unit_price)"></p>

                                    <button type="button" x-on:click="removeFromCart(index)" class="shrink-0 text-slate-300 hover:text-red-500">
                                        <x-icon name="error" />
                                    </button>

                                    <input type="hidden" :name="'items[' + index + '][product_id]'" :value="item.product_id">
                                    <input type="hidden" :name="'items[' + index + '][quantity]'" :value="item.quantity">
                                </div>
                            </template>
                        </div>

                        <div class="mt-4 space-y-2 border-t border-slate-100 pt-3 text-sm">
                            <div class="flex justify-between text-slate-500">
                                <span>Sous-total</span>
                                <span x-text="formatMoney(subtotal())"></span>
                            </div>
                            <div class="flex items-center justify-between text-slate-500">
                                <span>Remise</span>
                                <input type="number" name="discount" min="0" step="0.01" x-model.number="discount" class="w-24 rounded-lg border border-slate-200 py-1 text-right text-sm">
                            </div>
                            <div class="flex justify-between text-base font-bold text-slate-900">
                                <span>Total</span>
                                <span x-text="formatMoney(total())"></span>
                            </div>
                        </div>

                        <div class="mt-4 space-y-3 border-t border-slate-100 pt-3">
                            <div>
                                <x-label for="customer_id">Client (optionnel)</x-label>
                                <select id="customer_id" name="customer_id" class="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400">
                                    <option value="">Client de passage</option>
                                    @foreach ($customers as $customer)
                                        <option value="{{ $customer->id }}">{{ $customer->name }}</option>
                                    @endforeach
                                </select>
                            </div>

                            <div>
                                <x-label for="payment_method">Paiement</x-label>
                                <select id="payment_method" name="payment_method" class="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400">
                                    @foreach (\App\Enums\PaymentMethod::options() as $value => $label)
                                        <option value="{{ $value }}">{{ $label }}</option>
                                    @endforeach
                                </select>
                            </div>

                            <div>
                                <x-label for="paid_amount">Montant payé</x-label>
                                <input id="paid_amount" type="number" name="paid_amount" min="0" step="0.01" x-model.number="paidAmount"
                                       class="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400">
                                <button type="button" x-on:click="paidAmount = total()" class="mt-1 text-xs font-medium text-brand-600 hover:underline">Payé en totalité</button>
                            </div>

                            <div class="flex justify-between rounded-xl bg-slate-50 px-3 py-2 text-sm">
                                <span class="text-slate-500">Reste à payer</span>
                                <span class="font-semibold" :class="remaining() > 0 ? 'text-amber-600' : 'text-emerald-600'" x-text="formatMoney(remaining())"></span>
                            </div>

                            <div>
                                <x-label for="notes">Note (optionnel)</x-label>
                                <input id="notes" name="notes" class="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400">
                            </div>
                        </div>

                        <x-button type="submit" class="mt-4 w-full justify-center" size="lg" x-bind:disabled="cart.length === 0">
                            Enregistrer la vente
                        </x-button>
                    </x-card>
                </div>
            </div>
        </form>
    </div>

    <script>
        function saleForm(config) {
            return {
                allProducts: config.products,
                currencySymbol: config.currencySymbol,
                search: '',
                cart: [],
                discount: 0,
                paidAmount: 0,

                init() {},

                filteredProducts() {
                    const term = this.search.trim().toLowerCase();
                    let list = this.allProducts;
                    if (term) {
                        list = list.filter(p =>
                            p.name.toLowerCase().includes(term) ||
                            (p.sku && p.sku.toLowerCase().includes(term))
                        );
                    }
                    return list.slice(0, 24);
                },

                addToCart(product) {
                    const existing = this.cart.find(i => i.product_id === product.id);
                    if (existing) {
                        this.changeQuantity(this.cart.indexOf(existing), 1);
                        return;
                    }
                    if (product.stock_quantity < 1) return;

                    this.cart.push({
                        product_id: product.id,
                        name: product.name,
                        unit: product.unit,
                        unit_price: parseFloat(product.selling_price),
                        quantity: 1,
                        max: product.stock_quantity,
                    });
                },

                removeFromCart(index) {
                    this.cart.splice(index, 1);
                },

                changeQuantity(index, delta) {
                    const item = this.cart[index];
                    const next = item.quantity + delta;
                    if (next < 1) { this.removeFromCart(index); return; }
                    item.quantity = Math.min(next, item.max);
                },

                clampQuantity(index) {
                    const item = this.cart[index];
                    if (item.quantity < 1) item.quantity = 1;
                    if (item.quantity > item.max) item.quantity = item.max;
                },

                subtotal() {
                    return this.cart.reduce((sum, i) => sum + (i.quantity * i.unit_price), 0);
                },

                total() {
                    return Math.max(0, this.subtotal() - (this.discount || 0));
                },

                remaining() {
                    return Math.max(0, this.total() - (this.paidAmount || 0));
                },

                formatMoney(value) {
                    return new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 2 }).format(Number(value) || 0) + ' ' + this.currencySymbol;
                },
            };
        }
    </script>
</x-layouts.app>
