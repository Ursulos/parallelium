<div
    x-data="{ open: false }"
    x-on:open-quick-actions.window="open = true"
    x-show="open"
    x-cloak
    class="fixed inset-0 z-40 lg:hidden"
    style="display: none;">
    <div class="absolute inset-0 bg-slate-900/40" x-on:click="open = false"></div>

    <div
        x-show="open"
        x-transition:enter="transition ease-out duration-200"
        x-transition:enter-start="translate-y-full"
        x-transition:enter-end="translate-y-0"
        class="absolute inset-x-0 bottom-0 rounded-t-3xl bg-white p-5 pb-[calc(env(safe-area-inset-bottom)+1.5rem)] shadow-2xl">
        <div class="mx-auto mb-4 h-1.5 w-10 rounded-full bg-slate-200"></div>
        <p class="mb-4 text-sm font-semibold text-slate-500">Action rapide</p>

        <div class="grid grid-cols-2 gap-3">
            <x-quick-action-item route-name="sales.create" icon="sales" label="Nouvelle vente" permission="sales.create" />
            <x-quick-action-item route-name="expenses.create" icon="expenses" label="Nouvelle dépense" permission="expenses.create" />
            <x-quick-action-item route-name="customers.create" icon="customers" label="Nouveau client" permission="customers.create" />
            <x-quick-action-item route-name="products.create" icon="products" label="Ajouter produit" permission="products.create" />
        </div>
    </div>
</div>
