<x-layouts.app title="Tableau de bord">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Bonjour {{ explode(' ', auth()->user()->name)[0] }}</h2>
        <p class="text-sm text-slate-500">Voici un aperçu de {{ $company->name }}.</p>
    </div>

    <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <x-stat-card label="Chiffre d'affaires (jour)" :value="\App\Support\Money::format($kpis['revenue_today'])" icon="money" />
        <x-stat-card label="Chiffre d'affaires (mois)" :value="\App\Support\Money::format($kpis['revenue_month'])" icon="revenue" />
        <x-stat-card label="Dépenses (mois)" :value="\App\Support\Money::format($kpis['expenses_month'])" icon="expenses" />
        <x-stat-card label="Résultat estimé" :value="\App\Support\Money::format($kpis['estimated_result'])" tone="brand" icon="result" />
    </div>

    <p class="mt-3 text-xs text-slate-400">
        Le résultat affiché est un indicateur de gestion interne, pas un résultat comptable officiel.
    </p>

    <div class="mt-6 grid gap-4 lg:grid-cols-3">
        <x-card class="lg:col-span-2">
            <div class="flex items-center justify-between">
                <h3 class="text-sm font-semibold text-slate-700">Dernières ventes</h3>
            </div>

            <x-empty-state
                class="mt-4"
                icon="sales"
                title="Aucune vente pour le moment."
                description="Le module Ventes arrive en Phase 4. Vos ventes récentes apparaîtront ici automatiquement.">
            </x-empty-state>
        </x-card>

        <x-card>
            <h3 class="text-sm font-semibold text-slate-700">Stock faible</h3>
            <x-empty-state
                class="mt-4"
                icon="package"
                title="Aucune alerte de stock."
                description="Le module Produits & Stock arrive en Phase 2.">
            </x-empty-state>
        </x-card>
    </div>

    <div class="mt-4 grid gap-4 lg:grid-cols-2">
        <x-card>
            <h3 class="text-sm font-semibold text-slate-700">Créances clients</h3>
            <x-empty-state class="mt-4" icon="customers" title="Aucun client pour le moment." description="Le module Clients arrive en Phase 3." />
        </x-card>

        <x-card>
            <h3 class="text-sm font-semibold text-slate-700">Dernières dépenses</h3>
            <x-empty-state class="mt-4" icon="expenses" title="Aucune dépense pour le moment." description="Le module Dépenses arrive en Phase 5." />
        </x-card>
    </div>
</x-layouts.app>