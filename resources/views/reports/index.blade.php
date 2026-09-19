<x-layouts.app title="Rapports">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Rapports</h2>
        <p class="text-sm text-slate-500">Analysez vos ventes, dépenses, produits et clients par période.</p>
    </div>

    <div class="grid gap-3 sm:grid-cols-2">
        <a href="{{ route('reports.sales') }}">
            <x-card class="h-full transition hover:border-brand-200 hover:shadow-md">
                <div class="flex items-center gap-3">
                    <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-brand-50 text-brand-600"><x-icon name="sales" /></span>
                    <div>
                        <p class="font-semibold text-slate-800">Rapport des ventes</p>
                        <p class="text-xs text-slate-400">Nombre de ventes, CA, payé, reste à payer</p>
                    </div>
                </div>
            </x-card>
        </a>

        <a href="{{ route('reports.expenses') }}">
            <x-card class="h-full transition hover:border-brand-200 hover:shadow-md">
                <div class="flex items-center gap-3">
                    <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-brand-50 text-brand-600"><x-icon name="expenses" /></span>
                    <div>
                        <p class="font-semibold text-slate-800">Rapport des dépenses</p>
                        <p class="text-xs text-slate-400">Total, répartition par catégorie</p>
                    </div>
                </div>
            </x-card>
        </a>

        <a href="{{ route('reports.products') }}">
            <x-card class="h-full transition hover:border-brand-200 hover:shadow-md">
                <div class="flex items-center gap-3">
                    <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-brand-50 text-brand-600"><x-icon name="products" /></span>
                    <div>
                        <p class="font-semibold text-slate-800">Rapport produits</p>
                        <p class="text-xs text-slate-400">Produits vendus, quantités, chiffre d'affaires</p>
                    </div>
                </div>
            </x-card>
        </a>

        <a href="{{ route('reports.customers') }}">
            <x-card class="h-full transition hover:border-brand-200 hover:shadow-md">
                <div class="flex items-center gap-3">
                    <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-brand-50 text-brand-600"><x-icon name="customers" /></span>
                    <div>
                        <p class="font-semibold text-slate-800">Rapport clients</p>
                        <p class="text-xs text-slate-400">Clients les plus actifs, créances</p>
                    </div>
                </div>
            </x-card>
        </a>
    </div>
</x-layouts.app>
