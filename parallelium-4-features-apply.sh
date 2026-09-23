#!/usr/bin/env bash
#
# Parallelium - 4 demandes : CA masque aux vendeurs, navigation filtree
# par permission, comparaison de 2 periodes (rapport ventes), catalogues
# de produits standards par type de commerce a l'onboarding.
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
set -e
echo "Application des fichiers..."

mkdir -p "database/seeders"
cat > "database/seeders/PermissionSeeder.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Database\Seeders;

use App\Models\Permission;
use Illuminate\Database\Seeder;

class PermissionSeeder extends Seeder
{
    public function run(): void
    {
        $groups = [
            'dashboard' => ['view', 'revenue'],
            'products' => ['view', 'create', 'update', 'delete'],
            'stock' => ['view', 'manage'],
            'customers' => ['view', 'create', 'update', 'delete'],
            'sales' => ['view', 'create', 'cancel'],
            'expenses' => ['view', 'create', 'update', 'delete'],
            'invoices' => ['view', 'create'],
            'reports' => ['view'],
            'employees' => ['view', 'manage'],
            'settings' => ['manage'],
        ];

        foreach ($groups as $group => $actions) {
            foreach ($actions as $action) {
                Permission::updateOrCreate(
                    ['slug' => "{$group}.{$action}"],
                    ['name' => ucfirst($group)." — ".ucfirst($action), 'group' => $group]
                );
            }
        }
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "resources/views"
cat > "resources/views/dashboard.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Tableau de bord">
    @php
        $canSeeRevenue = auth()->user()->can('dashboard.revenue');
        $canSeeExpenses = auth()->user()->can('expenses.view');
    @endphp

    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Bonjour {{ explode(' ', auth()->user()->name)[0] }}</h2>
        <p class="text-sm text-slate-500">Voici un aperçu de {{ $company->name }}.</p>
    </div>

    @if ($canSeeRevenue || $canSeeExpenses)
        <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
            @can('dashboard.revenue')
                <x-stat-card label="Chiffre d'affaires (jour)" :value="\App\Support\Money::format($kpis['revenue_today'])" icon="money">
                    @if (! is_null($kpis['revenue_today_change']))
                        <x-slot:trend>
                            <span class="{{ $kpis['revenue_today_change'] >= 0 ? 'text-emerald-600' : 'text-red-500' }}">
                                {{ $kpis['revenue_today_change'] >= 0 ? '+' : '' }}{{ $kpis['revenue_today_change'] }}% vs hier
                            </span>
                        </x-slot:trend>
                    @endif
                </x-stat-card>
                <x-stat-card label="Chiffre d'affaires (mois)" :value="\App\Support\Money::format($kpis['revenue_month'])" icon="revenue">
                    @if (! is_null($kpis['revenue_month_change']))
                        <x-slot:trend>
                            <span class="{{ $kpis['revenue_month_change'] >= 0 ? 'text-emerald-600' : 'text-red-500' }}">
                                {{ $kpis['revenue_month_change'] >= 0 ? '+' : '' }}{{ $kpis['revenue_month_change'] }}% vs mois dernier
                            </span>
                        </x-slot:trend>
                    @endif
                </x-stat-card>
            @endcan
            @can('expenses.view')
                <x-stat-card label="Dépenses (mois)" :value="\App\Support\Money::format($kpis['expenses_month'])" icon="expenses" />
            @endcan
            @can('dashboard.revenue')
                <x-stat-card label="Résultat estimé" :value="\App\Support\Money::format($kpis['estimated_result'])" tone="brand" icon="result" />
            @endcan
        </div>

        @can('dashboard.revenue')
            <p class="mt-3 text-xs text-slate-400">
                Le résultat affiché est un indicateur de gestion interne, pas un résultat comptable officiel.
            </p>
        @endcan
    @endif

    <div class="mt-6 grid gap-4 lg:grid-cols-3">
        <x-card class="lg:col-span-2" :padded="false">
            <div class="flex items-center justify-between px-5 pt-5">
                <h3 class="text-sm font-semibold text-slate-700">Dernières ventes</h3>
                @can('sales.view')
                    <a href="{{ route('sales.index') }}" class="text-xs font-medium text-brand-600 hover:underline">Voir tout</a>
                @endcan
            </div>

            @if ($recentSales->isEmpty())
                <x-empty-state
                    class="m-5"
                    icon="sales"
                    title="Aucune vente pour le moment."
                    description="Vos ventes récentes apparaîtront ici automatiquement.">
                    @can('sales.create')
                        <x-slot:action>
                            <x-button :href="route('sales.create')">Nouvelle vente</x-button>
                        </x-slot:action>
                    @endcan
                </x-empty-state>
            @else
                <div class="mt-2 divide-y divide-slate-100">
                    @foreach ($recentSales as $sale)
                        <a href="{{ route('sales.show', $sale) }}" class="flex items-center justify-between px-5 py-2.5 text-sm hover:bg-slate-50">
                            <div class="min-w-0">
                                <p class="truncate font-medium text-slate-800">{{ $sale->customer?->name ?? 'Client de passage' }}</p>
                                <p class="text-xs text-slate-400">{{ $sale->sale_number }} · {{ $sale->sold_at->format('d/m H:i') }}</p>
                            </div>
                            <p class="shrink-0 font-semibold text-slate-800"><x-money :amount="$sale->total_amount" /></p>
                        </a>
                    @endforeach
                </div>
                <div class="h-2"></div>
            @endif
        </x-card>

        <x-card>
            <h3 class="text-sm font-semibold text-slate-700">Stock faible</h3>
            @if ($lowStockProducts->isEmpty())
                <x-empty-state
                    class="mt-4"
                    icon="package"
                    title="Aucune alerte de stock."
                    description="Vous serez averti ici dès qu'un produit passera sous son seuil minimum." />
            @else
                <div class="mt-3 space-y-2">
                    @foreach ($lowStockProducts as $product)
                        <a href="{{ route('stock.index', ['product_id' => $product->id]) }}" class="flex items-center justify-between rounded-xl border border-amber-100 bg-amber-50 px-3 py-2 text-sm">
                            <span class="font-medium text-amber-900">{{ $product->name }}</span>
                            <span class="text-amber-700">{{ $product->stock_quantity }} / {{ $product->minimum_stock }}</span>
                        </a>
                    @endforeach
                </div>
                <a href="{{ route('products.index', ['low_stock' => 1]) }}" class="mt-3 block text-center text-xs font-medium text-brand-600 hover:underline">
                    Voir tous les produits en stock faible
                </a>
            @endif
        </x-card>
    </div>

    @if ($canSeeRevenue || $canSeeExpenses)
        <div class="mt-4 grid gap-4 lg:grid-cols-2">
            @can('dashboard.revenue')
                <x-card>
                    <h3 class="text-sm font-semibold text-slate-700">Créances clients</h3>
                    @if ($kpis['receivables'] > 0)
                        <p class="mt-3 text-2xl font-bold text-amber-600"><x-money :amount="$kpis['receivables']" /></p>
                        <p class="mt-1 text-xs text-slate-400">Montant restant à encaisser sur les ventes à crédit.</p>
                    @elseif ($kpis['customers_count'] > 0)
                        <div class="mt-3 flex items-center justify-between rounded-xl border border-slate-100 bg-slate-50 px-3 py-2 text-sm">
                            <span class="text-slate-600">{{ $kpis['customers_count'] }} client{{ $kpis['customers_count'] > 1 ? 's' : '' }} enregistré{{ $kpis['customers_count'] > 1 ? 's' : '' }}, aucune créance en cours.</span>
                        </div>
                    @else
                        <x-empty-state class="mt-4" icon="customers" title="Aucun client pour le moment." description="Ajoutez votre premier client pour commencer." />
                    @endif
                </x-card>
            @endcan

            @can('expenses.view')
                <x-card>
                    <h3 class="text-sm font-semibold text-slate-700">Dernières dépenses</h3>
                    @if ($recentExpenses->isEmpty())
                        <x-empty-state class="mt-4" icon="expenses" title="Aucune dépense pour le moment." description="Enregistrez votre première dépense pour la voir apparaître ici." />
                    @else
                        <div class="mt-3 space-y-2">
                            @foreach ($recentExpenses as $expense)
                                <a href="{{ route('expenses.index') }}" class="flex items-center justify-between rounded-xl border border-slate-100 px-3 py-2 text-sm hover:bg-slate-50">
                                    <span class="text-slate-600">{{ $expense->category->label() }}</span>
                                    <span class="font-semibold text-slate-800"><x-money :amount="$expense->amount" /></span>
                                </a>
                            @endforeach
                        </div>
                        <a href="{{ route('expenses.index') }}" class="mt-3 block text-center text-xs font-medium text-brand-600 hover:underline">
                            Voir toutes les dépenses
                        </a>
                    @endif
                </x-card>
            @endcan
        </div>
    @endif

    @if ($canSeeRevenue || $canSeeExpenses || count($charts['topProducts']) > 0)
        <div class="mt-6 grid gap-4 lg:grid-cols-2">
            @can('dashboard.revenue')
                <x-card>
                    <h3 class="mb-3 text-sm font-semibold text-slate-700">Chiffre d'affaires — 7 derniers jours</h3>
                    @if (collect($charts['salesLast7Days'])->sum('total') > 0)
                        <canvas id="chart-sales-7d" height="180"></canvas>
                    @else
                        <p class="py-8 text-center text-sm text-slate-400">Pas encore de ventes cette semaine.</p>
                    @endif
                </x-card>
            @endcan

            <x-card>
                <h3 class="mb-3 text-sm font-semibold text-slate-700">Top produits vendus (ce mois-ci)</h3>
                @if (count($charts['topProducts']) > 0)
                    <canvas id="chart-top-products" height="180"></canvas>
                @else
                    <p class="py-8 text-center text-sm text-slate-400">Aucune vente ce mois-ci.</p>
                @endif
            </x-card>

            @can('dashboard.revenue')
                <x-card>
                    <h3 class="mb-3 text-sm font-semibold text-slate-700">Ventes par catégorie (ce mois-ci)</h3>
                    @if (count($charts['salesByCategory']) > 0)
                        <canvas id="chart-sales-category" height="200"></canvas>
                    @else
                        <p class="py-8 text-center text-sm text-slate-400">Aucune vente ce mois-ci.</p>
                    @endif
                </x-card>
            @endcan

            @can('expenses.view')
                <x-card>
                    <h3 class="mb-3 text-sm font-semibold text-slate-700">Dépenses par catégorie (ce mois-ci)</h3>
                    @if (count($charts['expensesByCategory']) > 0)
                        <canvas id="chart-expenses-category" height="200"></canvas>
                    @else
                        <p class="py-8 text-center text-sm text-slate-400">Aucune dépense ce mois-ci.</p>
                    @endif
                </x-card>
            @endcan
        </div>
    @endif

    @if (($canSeeRevenue && collect($charts['salesLast7Days'])->sum('total') > 0) || count($charts['topProducts']) > 0 || ($canSeeRevenue && count($charts['salesByCategory']) > 0) || ($canSeeExpenses && count($charts['expensesByCategory']) > 0))
        <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.4/chart.umd.min.js" integrity="sha512-e3nkTaqZ4qhAtI22fMPCH7ELiC4qhBQCiCTgKXWBTx6jHU0y3TKO5+ez+IEK9nnMx7DdMg0jZQBcwSj2Hn45Sw==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
        <script>
            document.addEventListener('DOMContentLoaded', () => {
                const brand = '#6a35c2';
                const palette = ['#6a35c2', '#c22fb0', '#8760d1', '#dd5ed0', '#481f89', '#f5bff0'];

                // Les données financières (CA, dépenses) ne sont sérialisées
                // dans la page QUE si l'utilisateur a la permission
                // correspondante — jamais envoyées "cachées" dans le HTML
                // pour un rôle qui ne devrait pas les voir.
                const sales7d = {!! $canSeeRevenue ? \Illuminate\Support\Js::from($charts['salesLast7Days']) : '[]' !!};
                const topProducts = @json($charts['topProducts']);
                const salesByCategory = {!! $canSeeRevenue ? \Illuminate\Support\Js::from($charts['salesByCategory']) : '[]' !!};
                const expensesByCategory = {!! $canSeeExpenses ? \Illuminate\Support\Js::from($charts['expensesByCategory']) : '[]' !!};

                const el7d = document.getElementById('chart-sales-7d');
                if (el7d) {
                    new Chart(el7d, {
                        type: 'bar',
                        data: {
                            labels: sales7d.map(d => d.label),
                            datasets: [{ data: sales7d.map(d => d.total), backgroundColor: brand, borderRadius: 6 }],
                        },
                        options: {
                            plugins: { legend: { display: false } },
                            scales: { y: { beginAtZero: true } },
                        },
                    });
                }

                const elTop = document.getElementById('chart-top-products');
                if (elTop) {
                    new Chart(elTop, {
                        type: 'bar',
                        data: {
                            labels: topProducts.map(p => p.label),
                            datasets: [{ data: topProducts.map(p => p.quantity), backgroundColor: palette, borderRadius: 6 }],
                        },
                        options: {
                            indexAxis: 'y',
                            plugins: { legend: { display: false } },
                            scales: { x: { beginAtZero: true, ticks: { precision: 0 } } },
                        },
                    });
                }

                const elCat = document.getElementById('chart-sales-category');
                if (elCat) {
                    new Chart(elCat, {
                        type: 'doughnut',
                        data: {
                            labels: salesByCategory.map(c => c.label),
                            datasets: [{ data: salesByCategory.map(c => c.total), backgroundColor: palette }],
                        },
                        options: { plugins: { legend: { position: 'bottom', labels: { boxWidth: 10, font: { size: 11 } } } } },
                    });
                }

                const elExp = document.getElementById('chart-expenses-category');
                if (elExp) {
                    new Chart(elExp, {
                        type: 'doughnut',
                        data: {
                            labels: expensesByCategory.map(c => c.label),
                            datasets: [{ data: expensesByCategory.map(c => c.total), backgroundColor: palette }],
                        },
                        options: { plugins: { legend: { position: 'bottom', labels: { boxWidth: 10, font: { size: 11 } } } } },
                    });
                }
            });
        </script>
    @endif
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/components"
cat > "resources/views/components/nav-link.blade.php" << 'PARALLELIUM_FILE_EOF'
@props(['routeName' => null, 'icon' => 'circle', 'label', 'permission' => null])

@php
    // Si l'utilisateur n'a pas la permission requise, l'élément de
    // navigation est totalement absent du rendu — jamais affiché grisé
    // ni cliquable pour finir sur un "non autorisé".
    if ($permission && ! auth()->user()?->can($permission)) {
        return;
    }

    $active = $routeName && request()->routeIs($routeName.'*');
    $enabled = $routeName && \Illuminate\Support\Facades\Route::has($routeName);
    $href = $enabled ? route($routeName) : '#';
@endphp

@if ($enabled)
    <a href="{{ $href }}"
       {{ $attributes->merge([
            'class' => 'group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition '
                . ($active ? 'bg-brand-50 text-brand-700' : 'text-slate-600 hover:bg-slate-100'),
       ]) }}>
        <x-icon :name="$icon" class="w-4 text-center text-base" />
        <span>{{ $label }}</span>
    </a>
@endif
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/components"
cat > "resources/views/components/bottom-nav-item.blade.php" << 'PARALLELIUM_FILE_EOF'
@props(['routeName', 'icon', 'label', 'permission' => null])

@php
    if ($permission && ! auth()->user()?->can($permission)) {
        return;
    }

    $active = request()->routeIs($routeName.'*');
    $enabled = \Illuminate\Support\Facades\Route::has($routeName);
    $href = $enabled ? route($routeName) : '#';
@endphp

@if ($enabled)
    <a href="{{ $href }}" class="flex flex-col items-center gap-0.5 rounded-lg py-1.5 text-[11px] font-medium {{ $active ? 'text-brand-700' : 'text-slate-500' }}">
        <x-icon :name="$icon" class="text-lg" />
        {{ $label }}
    </a>
@endif
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/components"
cat > "resources/views/components/app-bottom-nav.blade.php" << 'PARALLELIUM_FILE_EOF'
@php
    // Liste de candidats classés par priorité, filtrée par permission ET
    // par existence de la route. On ne prend que les 4 premiers
    // autorisés : jamais d'emplacement vide grisé, la barre s'adapte
    // simplement au rôle de l'utilisateur (flex + justify-around, pas de
    // grille figée à 5 colonnes).
    $bottomNavCandidates = collect([
        ['route' => 'dashboard', 'icon' => 'home', 'label' => 'Accueil', 'permission' => 'dashboard.view'],
        ['route' => 'sales.index', 'icon' => 'sales', 'label' => 'Ventes', 'permission' => 'sales.view'],
        ['route' => 'stock.index', 'icon' => 'stock', 'label' => 'Stock', 'permission' => 'stock.view'],
        ['route' => 'customers.index', 'icon' => 'customers', 'label' => 'Clients', 'permission' => 'customers.view'],
        ['route' => 'expenses.index', 'icon' => 'expenses', 'label' => 'Dépenses', 'permission' => 'expenses.view'],
        ['route' => 'reports.index', 'icon' => 'reports', 'label' => 'Rapports', 'permission' => 'reports.view'],
    ])->filter(fn ($c) => auth()->user()?->can($c['permission']) && \Illuminate\Support\Facades\Route::has($c['route']))
      ->take(4)
      ->values();

    $bottomNavMid = (int) ceil($bottomNavCandidates->count() / 2);
    $bottomNavLeft = $bottomNavCandidates->slice(0, $bottomNavMid);
    $bottomNavRight = $bottomNavCandidates->slice($bottomNavMid);
@endphp

<nav class="fixed inset-x-0 bottom-0 z-30 border-t border-slate-100 bg-white/95 backdrop-blur pb-[env(safe-area-inset-bottom)] lg:hidden">
    <div class="relative mx-auto flex max-w-lg items-center justify-around px-2 py-2">
        @foreach ($bottomNavLeft as $item)
            <x-bottom-nav-item :route-name="$item['route']" :icon="$item['icon']" :label="$item['label']" />
        @endforeach

        @canany(['sales.create', 'expenses.create', 'customers.create', 'products.create'])
            <div class="flex items-center justify-center">
                <button
                    type="button"
                    x-data
                    @click="$dispatch('open-quick-actions')"
                    class="-mt-8 flex h-14 w-14 items-center justify-center rounded-full bg-brand-gradient text-xl text-white shadow-lg shadow-brand-500/40 active:scale-95 transition">
                    <x-icon name="plus" />
                </button>
            </div>
        @endcanany

        @foreach ($bottomNavRight as $item)
            <x-bottom-nav-item :route-name="$item['route']" :icon="$item['icon']" :label="$item['label']" />
        @endforeach
    </div>
</nav>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/components"
cat > "resources/views/components/quick-action-item.blade.php" << 'PARALLELIUM_FILE_EOF'
@props(['routeName', 'icon', 'label', 'permission' => null])

@php
    if ($permission && ! auth()->user()?->can($permission)) {
        return;
    }

    $enabled = \Illuminate\Support\Facades\Route::has($routeName);
@endphp

@if ($enabled)
    <a href="{{ route($routeName) }}"
       class="flex flex-col items-center gap-2 rounded-2xl border border-slate-100 p-4 text-center active:scale-95 hover:bg-slate-50 transition">
        <x-icon :name="$icon" class="text-2xl" />
        <span class="text-xs font-medium text-slate-600">{{ $label }}</span>
    </a>
@endif
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/components"
cat > "resources/views/components/quick-actions-sheet.blade.php" << 'PARALLELIUM_FILE_EOF'
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
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/components"
cat > "resources/views/components/app-sidebar.blade.php" << 'PARALLELIUM_FILE_EOF'
<aside class="hidden w-64 shrink-0 flex-col border-r border-slate-100 bg-white px-4 py-6 lg:flex">
    <div class="mb-8 flex items-center gap-2 px-2 text-lg font-extrabold text-brand-800">
        <span class="flex h-8 w-8 items-center justify-center rounded-full bg-brand-gradient text-sm text-white"><x-icon name="logo" /></span>
        Parallelium
    </div>

    <nav class="flex flex-1 flex-col gap-1">
        <x-nav-link route-name="dashboard" icon="home" label="Accueil" permission="dashboard.view" />
        <x-nav-link route-name="sales.index" icon="sales" label="Ventes" permission="sales.view" />
        <x-nav-link route-name="products.index" icon="products" label="Produits" permission="products.view" />
        <x-nav-link route-name="stock.index" icon="stock" label="Stock" permission="stock.view" />
        <x-nav-link route-name="customers.index" icon="customers" label="Clients" permission="customers.view" />
        <x-nav-link route-name="expenses.index" icon="expenses" label="Dépenses" permission="expenses.view" />
        <x-nav-link route-name="invoices.index" icon="invoices" label="Factures" permission="invoices.view" />
        <x-nav-link route-name="reports.index" icon="reports" label="Rapports" permission="reports.view" />
        <x-nav-link route-name="employees.index" icon="employees" label="Employés" permission="employees.view" />
        <x-nav-link route-name="settings.index" icon="settings" label="Paramètres" permission="settings.manage" />
    </nav>

    <div class="mt-4 rounded-xl bg-brand-50 p-3 text-xs text-brand-700">
        <p class="font-semibold">{{ auth()->user()->company->name }}</p>
        <p class="mt-0.5 text-brand-500">Plan {{ ucfirst(auth()->user()->company->subscription->plan ?? 'free') }}</p>
    </div>
</aside>
PARALLELIUM_FILE_EOF

mkdir -p "app/Services"
cat > "app/Services/ReportService.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Services;

use App\Enums\ExpenseCategory;
use App\Models\Customer;
use App\Models\Expense;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Support\Tenant;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

/**
 * Rapports simples (§22) : ventes, dépenses, produits, clients.
 * Toutes les périodes sont résolues côté serveur — jamais de dates
 * envoyées telles quelles sans validation.
 */
class ReportService
{
    /**
     * @return array{0: Carbon, 1: Carbon, 2: string}
     */
    public function resolvePeriod(Request $request): array
    {
        $period = $request->string('period', 'month')->toString();

        return match ($period) {
            'today' => [today()->startOfDay(), today()->endOfDay(), "aujourd'hui"],
            'week' => [now()->startOfWeek(), now()->endOfWeek(), 'cette semaine'],
            'custom' => [
                $request->filled('from') ? Carbon::parse($request->date('from'))->startOfDay() : now()->startOfMonth(),
                $request->filled('to') ? Carbon::parse($request->date('to'))->endOfDay() : now()->endOfDay(),
                'période personnalisée',
            ],
            default => [now()->startOfMonth(), now()->endOfMonth(), 'ce mois'],
        };
    }

    /**
     * Deuxième période, pour la comparaison de ventes. Toujours des dates
     * personnalisées explicites (le principe même de la comparaison), pas
     * de raccourcis "aujourd'hui/semaine/mois" — on laisse l'utilisateur
     * choisir exactement les deux plages à confronter.
     *
     * @return array{0: Carbon, 1: Carbon}
     */
    public function resolvePeriodB(Request $request): array
    {
        $from = $request->filled('from_b')
            ? Carbon::parse($request->date('from_b'))->startOfDay()
            : now()->subMonthNoOverflow()->startOfMonth();

        $to = $request->filled('to_b')
            ? Carbon::parse($request->date('to_b'))->endOfDay()
            : now()->subMonthNoOverflow()->endOfMonth();

        return [$from, $to];
    }

    public function compareSales(Carbon $fromA, Carbon $toA, Carbon $fromB, Carbon $toB): array
    {
        $a = $this->salesReport($fromA, $toA);
        $b = $this->salesReport($fromB, $toB);

        return [
            'a' => $a,
            'b' => $b,
            'revenue_change' => $this->percentChange($b['revenue'], $a['revenue']),
            'count_change' => $this->percentChange($b['count'], $a['count']),
        ];
    }

    /**
     * Variation en pourcentage entre deux périodes, ou null si la
     * période de référence est à zéro (comparaison non pertinente).
     */
    protected function percentChange(float $previous, float $current): ?float
    {
        if ($previous <= 0) {
            return null;
        }

        return round((($current - $previous) / $previous) * 100, 1);
    }

    public function salesReport(Carbon $from, Carbon $to): array
    {
        $sales = Sale::completed()->whereBetween('sold_at', [$from, $to]);

        return [
            'count' => (clone $sales)->count(),
            'revenue' => (clone $sales)->sum('total_amount'),
            'paid' => (clone $sales)->sum('paid_amount'),
            'remaining' => (clone $sales)->sum('remaining_amount'),
            'rows' => (clone $sales)->with('customer')->latest('sold_at')->get(),
        ];
    }

    public function expensesReport(Carbon $from, Carbon $to): array
    {
        $expenses = Expense::whereBetween('expense_date', [$from, $to]);

        $byCategory = (clone $expenses)
            ->selectRaw('category, SUM(amount) as total, COUNT(*) as count')
            ->groupBy('category')
            ->orderByDesc('total')
            ->get()
            ->map(fn ($row) => [
                'label' => $row->category->label(),
                'total' => (float) $row->total,
                'count' => (int) $row->count,
            ]);

        return [
            'total' => (clone $expenses)->sum('amount'),
            'count' => (clone $expenses)->count(),
            'byCategory' => $byCategory,
            'rows' => (clone $expenses)->latest('expense_date')->get(),
        ];
    }

    public function productsReport(Carbon $from, Carbon $to): array
    {
        $rows = SaleItem::query()
            ->join('sales', 'sales.id', '=', 'sale_items.sale_id')
            ->join('products', 'products.id', '=', 'sale_items.product_id')
            ->where('sales.company_id', Tenant::id())
            ->where('sales.sale_status', 'completed')
            ->whereBetween('sales.sold_at', [$from, $to])
            ->selectRaw('products.id, products.name, SUM(sale_items.quantity) as quantity, SUM(sale_items.subtotal) as revenue')
            ->groupBy('products.id', 'products.name')
            ->orderByDesc('revenue')
            ->get();

        return [
            'rows' => $rows,
            'totalQuantity' => (int) $rows->sum('quantity'),
            'totalRevenue' => (float) $rows->sum('revenue'),
        ];
    }

    public function customersReport(Carbon $from, Carbon $to): array
    {
        $rows = Customer::query()
            ->withSum(['sales as period_revenue' => function ($q) use ($from, $to) {
                $q->completed()->whereBetween('sold_at', [$from, $to]);
            }], 'total_amount')
            ->withSum(['sales as period_remaining' => function ($q) use ($from, $to) {
                $q->completed()->whereBetween('sold_at', [$from, $to]);
            }], 'remaining_amount')
            ->withCount(['sales as period_sales_count' => function ($q) use ($from, $to) {
                $q->completed()->whereBetween('sold_at', [$from, $to]);
            }])
            ->having('period_sales_count', '>', 0)
            ->orderByDesc('period_revenue')
            ->get();

        return [
            'rows' => $rows,
            'totalRevenue' => (float) $rows->sum('period_revenue'),
            'totalRemaining' => (float) $rows->sum('period_remaining'),
        ];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/ReportController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use App\Services\ReportService;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ReportController extends Controller
{
    public function index()
    {
        $this->authorize('reports.view');

        return view('reports.index');
    }

    public function sales(Request $request, ReportService $reportService)
    {
        $this->authorize('reports.view');

        if ($request->boolean('compare')) {
            [$fromA, $toA, $periodLabel] = $reportService->resolvePeriod($request);
            [$fromB, $toB] = $reportService->resolvePeriodB($request);
            $comparison = $reportService->compareSales($fromA, $toA, $fromB, $toB);

            return view('reports.sales-compare', compact('comparison', 'fromA', 'toA', 'fromB', 'toB'));
        }

        [$from, $to, $periodLabel] = $reportService->resolvePeriod($request);
        $report = $reportService->salesReport($from, $to);

        if ($request->query('export') === 'csv') {
            return $this->csv('rapport-ventes', ['Date', 'Numéro', 'Client', 'Total', 'Payé', 'Reste', 'Statut'],
                $report['rows']->map(fn ($sale) => [
                    $sale->sold_at->format('d/m/Y H:i'),
                    $sale->sale_number,
                    $sale->customer?->name ?? 'Client de passage',
                    $sale->total_amount,
                    $sale->paid_amount,
                    $sale->remaining_amount,
                    $sale->payment_status->label(),
                ])
            );
        }

        if ($request->query('export') === 'pdf') {
            $pdf = Pdf::loadView('pdf.report-sales', compact('report', 'periodLabel', 'from', 'to'))->setPaper('a4');

            return $pdf->download('rapport-ventes.pdf');
        }

        return view('reports.sales', compact('report', 'periodLabel', 'from', 'to'));
    }

    public function expenses(Request $request, ReportService $reportService)
    {
        $this->authorize('reports.view');

        [$from, $to, $periodLabel] = $reportService->resolvePeriod($request);
        $report = $reportService->expensesReport($from, $to);

        if ($request->query('export') === 'csv') {
            return $this->csv('rapport-depenses', ['Date', 'Catégorie', 'Fournisseur', 'Montant', 'Paiement'],
                $report['rows']->map(fn ($expense) => [
                    $expense->expense_date->format('d/m/Y'),
                    $expense->category->label(),
                    $expense->supplier_name ?? '—',
                    $expense->amount,
                    $expense->payment_method->label(),
                ])
            );
        }

        return view('reports.expenses', compact('report', 'periodLabel', 'from', 'to'));
    }

    public function products(Request $request, ReportService $reportService)
    {
        $this->authorize('reports.view');

        [$from, $to, $periodLabel] = $reportService->resolvePeriod($request);
        $report = $reportService->productsReport($from, $to);

        if ($request->query('export') === 'csv') {
            return $this->csv('rapport-produits', ['Produit', 'Quantité vendue', 'Chiffre d\'affaires'],
                $report['rows']->map(fn ($row) => [$row->name, $row->quantity, $row->revenue])
            );
        }

        return view('reports.products', compact('report', 'periodLabel', 'from', 'to'));
    }

    public function customers(Request $request, ReportService $reportService)
    {
        $this->authorize('reports.view');

        [$from, $to, $periodLabel] = $reportService->resolvePeriod($request);
        $report = $reportService->customersReport($from, $to);

        if ($request->query('export') === 'csv') {
            return $this->csv('rapport-clients', ['Client', 'Ventes', 'Chiffre d\'affaires', 'Reste dû'],
                $report['rows']->map(fn ($c) => [$c->name, $c->period_sales_count, $c->period_revenue, $c->period_remaining ?? 0])
            );
        }

        return view('reports.customers', compact('report', 'periodLabel', 'from', 'to'));
    }

    /**
     * Génère un CSV en flux (pas de fichier temporaire sur le serveur).
     * Les montants restent des nombres bruts (pas de symbole monétaire)
     * pour rester exploitables dans un tableur.
     */
    protected function csv(string $filename, array $headers, iterable $rows): StreamedResponse
    {
        return response()->streamDownload(function () use ($headers, $rows) {
            $handle = fopen('php://output', 'w');
            fwrite($handle, "\xEF\xBB\xBF"); // BOM UTF-8 (Excel)
            fputcsv($handle, $headers, ';');
            foreach ($rows as $row) {
                fputcsv($handle, $row, ';');
            }
            fclose($handle);
        }, "{$filename}-".now()->format('Y-m-d').'.csv', ['Content-Type' => 'text/csv; charset=UTF-8']);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/reports"
cat > "resources/views/reports/sales-compare.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Comparer deux périodes">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Comparer deux périodes</h2>
            <p class="text-sm text-slate-500">Ventes de la période A face à la période B.</p>
        </div>
        <x-button :href="route('reports.sales')" variant="ghost" size="sm">Retour au rapport simple</x-button>
    </div>

    <x-card class="mb-5">
        <form method="GET" class="grid gap-4 sm:grid-cols-2">
            <input type="hidden" name="compare" value="1">

            <div>
                <p class="mb-2 text-xs font-semibold uppercase tracking-wide text-brand-600">Période A</p>
                <div class="flex items-center gap-2">
                    <x-input type="date" name="from" value="{{ request('from', $fromA->format('Y-m-d')) }}" />
                    <x-icon name="chevron-right" class="shrink-0 text-xs text-slate-400" />
                    <x-input type="date" name="to" value="{{ request('to', $toA->format('Y-m-d')) }}" />
                </div>
            </div>

            <div>
                <p class="mb-2 text-xs font-semibold uppercase tracking-wide text-slate-500">Période B (référence)</p>
                <div class="flex items-center gap-2">
                    <x-input type="date" name="from_b" value="{{ request('from_b', $fromB->format('Y-m-d')) }}" />
                    <x-icon name="chevron-right" class="shrink-0 text-xs text-slate-400" />
                    <x-input type="date" name="to_b" value="{{ request('to_b', $toB->format('Y-m-d')) }}" />
                </div>
            </div>

            <div class="sm:col-span-2">
                <x-button type="submit">Comparer</x-button>
            </div>
        </form>
    </x-card>

    <div class="mb-3 flex flex-wrap items-center gap-3">
        @if (! is_null($comparison['revenue_change']))
            <x-badge :tone="$comparison['revenue_change'] >= 0 ? 'success' : 'danger'">
                CA : {{ $comparison['revenue_change'] >= 0 ? '+' : '' }}{{ $comparison['revenue_change'] }}% vs période B
            </x-badge>
        @endif
        @if (! is_null($comparison['count_change']))
            <x-badge :tone="$comparison['count_change'] >= 0 ? 'success' : 'danger'">
                Ventes : {{ $comparison['count_change'] >= 0 ? '+' : '' }}{{ $comparison['count_change'] }}% vs période B
            </x-badge>
        @endif
    </div>

    <div class="grid gap-4 sm:grid-cols-2">
        <x-card>
            <p class="mb-3 text-xs font-semibold uppercase tracking-wide text-brand-600">
                Période A — {{ $fromA->format('d/m/Y') }} au {{ $toA->format('d/m/Y') }}
            </p>
            <div class="grid grid-cols-2 gap-3">
                <x-stat-card label="Ventes" :value="$comparison['a']['count']" icon="sales" />
                <x-stat-card label="Chiffre d'affaires" :value="\App\Support\Money::format($comparison['a']['revenue'])" icon="money" tone="brand" />
                <x-stat-card label="Payé" :value="\App\Support\Money::format($comparison['a']['paid'])" icon="revenue" />
                <x-stat-card label="Reste à payer" :value="\App\Support\Money::format($comparison['a']['remaining'])" icon="credit" />
            </div>
        </x-card>

        <x-card>
            <p class="mb-3 text-xs font-semibold uppercase tracking-wide text-slate-500">
                Période B — {{ $fromB->format('d/m/Y') }} au {{ $toB->format('d/m/Y') }}
            </p>
            <div class="grid grid-cols-2 gap-3">
                <x-stat-card label="Ventes" :value="$comparison['b']['count']" icon="sales" />
                <x-stat-card label="Chiffre d'affaires" :value="\App\Support\Money::format($comparison['b']['revenue'])" icon="money" />
                <x-stat-card label="Payé" :value="\App\Support\Money::format($comparison['b']['paid'])" icon="revenue" />
                <x-stat-card label="Reste à payer" :value="\App\Support\Money::format($comparison['b']['remaining'])" icon="credit" />
            </div>
        </x-card>
    </div>
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/reports"
cat > "resources/views/reports/sales.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Rapport des ventes">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Rapport des ventes</h2>
            <p class="text-sm text-slate-500">{{ ucfirst($periodLabel) }} — du {{ $from->format('d/m/Y') }} au {{ $to->format('d/m/Y') }}</p>
        </div>
        <div class="flex items-center gap-2">
            <x-button :href="route('reports.sales', ['compare' => 1])" variant="secondary" size="sm">Comparer deux périodes</x-button>
            <x-button :href="route('reports.sales', array_merge(request()->query(), ['export' => 'csv']))" variant="secondary" size="sm">Export CSV</x-button>
            <x-button :href="route('reports.sales', array_merge(request()->query(), ['export' => 'pdf']))" variant="ghost" size="sm">Export PDF</x-button>
        </div>
    </div>

    <x-report-period-filter route="reports.sales" />

    <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <x-stat-card label="Nombre de ventes" :value="$report['count']" icon="sales" />
        <x-stat-card label="Chiffre d'affaires" :value="\App\Support\Money::format($report['revenue'])" icon="money" />
        <x-stat-card label="Montant payé" :value="\App\Support\Money::format($report['paid'])" icon="revenue" />
        <x-stat-card label="Reste à payer" :value="\App\Support\Money::format($report['remaining'])" icon="credit" />
    </div>

    <div class="mt-6">
        @if ($report['rows']->isEmpty())
            <x-empty-state icon="sales" title="Aucune vente sur cette période." />
        @else
            <x-card :padded="false">
                <div class="divide-y divide-slate-100">
                    @foreach ($report['rows'] as $sale)
                        <a href="{{ route('sales.show', $sale) }}" class="flex items-center justify-between gap-3 px-5 py-3 hover:bg-slate-50">
                            <div class="min-w-0">
                                <p class="truncate text-sm font-semibold text-slate-800">{{ $sale->sale_number }}</p>
                                <p class="text-xs text-slate-400">{{ $sale->customer?->name ?? 'Client de passage' }} · {{ $sale->sold_at->format('d/m/Y H:i') }}</p>
                            </div>
                            <div class="shrink-0 text-right">
                                <p class="text-sm font-bold text-slate-900"><x-money :amount="$sale->total_amount" /></p>
                                <x-badge :tone="$sale->payment_status->tone()">{{ $sale->payment_status->label() }}</x-badge>
                            </div>
                        </a>
                    @endforeach
                </div>
            </x-card>
        @endif
    </div>
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "config"
cat > "config/business_catalogs.php" << 'PARALLELIUM_FILE_EOF'
<?php

/**
 * Catalogues de produits standards proposés à l'inscription (§40, sur
 * demande explicite). L'utilisateur choisit un type de commerce ; on lui
 * propose ensuite d'ajouter cette liste à son catalogue — jamais
 * automatique, toujours un choix explicite (voir OnboardingController).
 *
 * Volontairement SANS prix ni SKU : à l'entrepreneur de les compléter
 * selon son propre fournisseur et sa propre marge. Le stock initial est
 * toujours à 0 (aucune donnée fictive — §51).
 *
 * Les variétés de marque (ex. cigarettes) reflètent des produits
 * réellement vendus à Madagascar, mais les prix/marques évoluent : c'est
 * un point de départ à ajuster, pas une vérité figée.
 */

return [
    'epicerie_ppn' => [
        'label' => 'Épicerie / PPN (Produits de Première Nécessité)',
        'categories' => [
            'Alimentation de base' => [
                ['name' => 'Riz local 1kg', 'unit' => 'kg'],
                ['name' => 'Riz importé 1kg', 'unit' => 'kg'],
                ['name' => 'Huile alimentaire 1L', 'unit' => 'litre'],
                ['name' => 'Sucre blanc 1kg', 'unit' => 'kg'],
                ['name' => 'Sel de cuisine', 'unit' => 'paquet'],
                ['name' => 'Farine de blé 1kg', 'unit' => 'kg'],
                ['name' => 'Pâtes alimentaires', 'unit' => 'paquet'],
                ['name' => 'Lait en poudre', 'unit' => 'boite'],
                ['name' => 'Café moulu', 'unit' => 'paquet'],
                ['name' => 'Thé (sachets)', 'unit' => 'boite'],
                ['name' => 'Sardines en boîte', 'unit' => 'boite'],
                ['name' => 'Corned-beef en boîte', 'unit' => 'boite'],
                ['name' => 'Concentré de tomate', 'unit' => 'boite'],
                ['name' => 'Bonbons assortis', 'unit' => 'paquet'],
                ['name' => 'Biscuits', 'unit' => 'paquet'],
                ['name' => 'Pain', 'unit' => 'unite'],
                ['name' => 'Œufs', 'unit' => 'unite'],
            ],
            'Boissons' => [
                ['name' => 'Eau minérale 1.5L', 'unit' => 'unite'],
                ['name' => 'Eau minérale 0.5L', 'unit' => 'unite'],
                ['name' => 'THB 65cl', 'unit' => 'unite'],
                ['name' => 'Boisson gazeuse 1L', 'unit' => 'unite'],
                ['name' => 'Jus de fruit en sachet', 'unit' => 'unite'],
                ['name' => 'Rhum arrangé (local)', 'unit' => 'litre'],
            ],
            'Hygiène et entretien' => [
                ['name' => 'Savon de Marseille', 'unit' => 'unite'],
                ['name' => 'Savon en poudre (lessive)', 'unit' => 'paquet'],
                ['name' => 'Pâte dentifrice', 'unit' => 'unite'],
                ['name' => 'Papier hygiénique', 'unit' => 'unite'],
                ['name' => 'Allumettes', 'unit' => 'boite'],
                ['name' => 'Bougies', 'unit' => 'paquet'],
                ['name' => 'Pétrole lampant', 'unit' => 'litre'],
                ['name' => 'Charbon de bois', 'unit' => 'kg'],
                ['name' => 'Piles électriques (AA)', 'unit' => 'paquet'],
            ],
            'Cigarettes' => [
                ['name' => 'Good Look', 'unit' => 'paquet'],
                ['name' => 'Good Look (à la tige)', 'unit' => 'unite'],
                ['name' => 'Melia Rouge', 'unit' => 'paquet'],
                ['name' => 'Melia Rouge (à la tige)', 'unit' => 'unite'],
                ['name' => 'First', 'unit' => 'paquet'],
                ['name' => 'First (à la tige)', 'unit' => 'unite'],
                ['name' => 'News Maitso', 'unit' => 'paquet'],
                ['name' => 'News Maitso (à la tige)', 'unit' => 'unite'],
                ['name' => 'News Mena', 'unit' => 'paquet'],
                ['name' => 'News Mena (à la tige)', 'unit' => 'unite'],
                ['name' => 'PS Rouge', 'unit' => 'paquet'],
                ['name' => 'PS Rouge (à la tige)', 'unit' => 'unite'],
            ],
        ],
    ],

    'quincaillerie' => [
        'label' => 'Quincaillerie',
        'categories' => [
            'Outillage' => [
                ['name' => 'Marteau', 'unit' => 'unite'],
                ['name' => 'Tournevis (jeu)', 'unit' => 'unite'],
                ['name' => 'Pince', 'unit' => 'unite'],
                ['name' => 'Scie à métaux', 'unit' => 'unite'],
                ['name' => 'Mètre ruban', 'unit' => 'unite'],
                ['name' => 'Niveau à bulle', 'unit' => 'unite'],
            ],
            'Quincaillerie générale' => [
                ['name' => 'Clous assortis', 'unit' => 'kg'],
                ['name' => 'Vis assorties', 'unit' => 'boite'],
                ['name' => 'Boulons et écrous', 'unit' => 'boite'],
                ['name' => 'Fil de fer', 'unit' => 'kg'],
                ['name' => 'Cadenas', 'unit' => 'unite'],
                ['name' => 'Charnières', 'unit' => 'unite'],
                ['name' => 'Ruban adhésif large', 'unit' => 'unite'],
                ['name' => 'Colle forte', 'unit' => 'unite'],
            ],
            'Peinture et plomberie' => [
                ['name' => 'Peinture (pot 1L)', 'unit' => 'unite'],
                ['name' => 'Pinceau', 'unit' => 'unite'],
                ['name' => 'Tuyau PVC (mètre)', 'unit' => 'metre'],
                ['name' => 'Raccord PVC', 'unit' => 'unite'],
                ['name' => 'Robinet', 'unit' => 'unite'],
                ['name' => 'Ampoule électrique', 'unit' => 'unite'],
                ['name' => 'Câble électrique (mètre)', 'unit' => 'metre'],
            ],
        ],
    ],

    'telephonie_mobile_money' => [
        'label' => 'Téléphonie & Mobile Money',
        'categories' => [
            'Accessoires téléphone' => [
                ['name' => 'Câble de charge USB', 'unit' => 'unite'],
                ['name' => 'Chargeur secteur', 'unit' => 'unite'],
                ['name' => 'Écouteurs filaires', 'unit' => 'unite'],
                ['name' => 'Coque de protection', 'unit' => 'unite'],
                ['name' => 'Protection d\'écran (verre trempé)', 'unit' => 'unite'],
                ['name' => 'Batterie externe (powerbank)', 'unit' => 'unite'],
                ['name' => 'Carte mémoire', 'unit' => 'unite'],
            ],
            'Recharges et cartes SIM' => [
                ['name' => 'Recharge Telma', 'unit' => 'unite'],
                ['name' => 'Recharge Orange', 'unit' => 'unite'],
                ['name' => 'Recharge Airtel', 'unit' => 'unite'],
                ['name' => 'Carte SIM Telma', 'unit' => 'unite'],
                ['name' => 'Carte SIM Orange', 'unit' => 'unite'],
                ['name' => 'Carte SIM Airtel', 'unit' => 'unite'],
            ],
        ],
    ],

    'vetements' => [
        'label' => 'Vêtements et accessoires',
        'categories' => [
            'Vêtements' => [
                ['name' => 'T-shirt homme', 'unit' => 'unite'],
                ['name' => 'T-shirt femme', 'unit' => 'unite'],
                ['name' => 'Chemise', 'unit' => 'unite'],
                ['name' => 'Pantalon', 'unit' => 'unite'],
                ['name' => 'Robe', 'unit' => 'unite'],
                ['name' => 'Jupe', 'unit' => 'unite'],
                ['name' => 'Lamba (traditionnel)', 'unit' => 'unite'],
                ['name' => 'Sous-vêtements', 'unit' => 'unite'],
            ],
            'Chaussures et accessoires' => [
                ['name' => 'Sandales', 'unit' => 'unite'],
                ['name' => 'Chaussures fermées', 'unit' => 'unite'],
                ['name' => 'Ceinture', 'unit' => 'unite'],
                ['name' => 'Casquette', 'unit' => 'unite'],
                ['name' => 'Sac à main', 'unit' => 'unite'],
            ],
        ],
    ],
];
PARALLELIUM_FILE_EOF

mkdir -p "app/Services"
cat > "app/Services/BusinessCatalogService.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Services;

use App\Models\Category;
use App\Models\Company;
use App\Models\Product;

/**
 * Ajoute au catalogue d'une entreprise la liste de produits standards de
 * son secteur (§40, onboarding — toujours à la demande explicite du
 * propriétaire, jamais automatique). Les prix restent à 0 : à
 * l'entrepreneur de les compléter selon son propre fournisseur.
 */
class BusinessCatalogService
{
    public function __construct(protected SubscriptionService $subscriptionService)
    {
    }

    public static function options(): array
    {
        return collect(config('business_catalogs'))
            ->mapWithKeys(fn ($catalog, $slug) => [$slug => $catalog['label']])
            ->all();
    }

    /**
     * @return array{created: int, skipped_duplicate: int, skipped_limit: int}
     */
    public function seed(Company $company, string $catalogSlug): array
    {
        $catalog = config("business_catalogs.{$catalogSlug}");

        if (! $catalog) {
            return ['created' => 0, 'skipped_duplicate' => 0, 'skipped_limit' => 0];
        }

        $existingNames = Product::where('company_id', $company->id)->pluck('name')->map(fn ($n) => mb_strtolower($n));

        $remaining = $company->subscription?->limit('products');
        $created = 0;
        $skippedDuplicate = 0;
        $skippedLimit = 0;

        foreach ($catalog['categories'] as $categoryName => $products) {
            $category = null;

            foreach ($products as $item) {
                if ($existingNames->contains(mb_strtolower($item['name']))) {
                    $skippedDuplicate++;

                    continue;
                }

                if ($remaining !== null && $remaining <= 0) {
                    $skippedLimit++;

                    continue;
                }

                // La catégorie n'est créée qu'à la première utilisation
                // réelle (§64 — pas de catégorie vide inutile).
                $category ??= Category::firstOrCreate(
                    ['company_id' => $company->id, 'name' => $categoryName],
                    ['is_active' => true]
                );

                Product::create([
                    'company_id' => $company->id,
                    'category_id' => $category->id,
                    'name' => $item['name'],
                    'unit' => $item['unit'],
                    'purchase_price' => 0,
                    'selling_price' => 0,
                    'stock_quantity' => 0,
                    'minimum_stock' => 5,
                    'is_active' => true,
                ]);

                $created++;
                if ($remaining !== null) {
                    $remaining--;
                }
            }
        }

        return ['created' => $created, 'skipped_duplicate' => $skippedDuplicate, 'skipped_limit' => $skippedLimit];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/OnboardingController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use App\Services\BusinessCatalogService;
use App\Support\Tenant;
use Illuminate\Http\Request;

class OnboardingController extends Controller
{
    public function show()
    {
        $company = Tenant::current();

        if ($company->onboarding_completed) {
            return redirect()->route('dashboard');
        }

        $businessTypes = BusinessCatalogService::options();

        return view('onboarding.show', compact('company', 'businessTypes'));
    }

    public function update(Request $request)
    {
        $data = $request->validate([
            'business_type' => ['nullable', 'string', 'max:255'],
            'business_type_other' => ['nullable', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:30'],
            'currency' => ['nullable', 'string', 'in:'.implode(',', array_keys(config('parallelium.currencies')))],
        ]);

        // "Autre" : on stocke le texte libre plutôt que le mot-clé, pour
        // un affichage lisible ailleurs (Paramètres, panneau admin).
        if (($data['business_type'] ?? null) === 'autre') {
            $data['business_type'] = $data['business_type_other'] ?? null;
        } elseif (($data['business_type'] ?? null) === '') {
            $data['business_type'] = null;
        }
        unset($data['business_type_other']);

        Tenant::current()->update($data);

        return redirect()->route('onboarding.show');
    }

    /**
     * Ajoute au catalogue les produits standards du secteur choisi —
     * uniquement sur demande explicite du propriétaire (§40), jamais
     * silencieusement.
     */
    public function seedCatalog(Request $request, BusinessCatalogService $catalogService)
    {
        $company = Tenant::current();

        if (! array_key_exists($company->business_type, BusinessCatalogService::options())) {
            return redirect()->route('onboarding.show');
        }

        $result = $catalogService->seed($company, $company->business_type);

        $message = "{$result['created']} produit(s) standard ajouté(s) à votre catalogue.";
        if ($result['skipped_limit'] > 0) {
            $message .= " {$result['skipped_limit']} n'ont pas pu être ajoutés car votre plan actuel a atteint sa limite de produits.";
        }

        return redirect()->route('onboarding.show')->with('status', $message);
    }

    public function finish()
    {
        Tenant::current()->update(['onboarding_completed' => true]);

        return redirect()->route('dashboard')->with('status', 'Votre entreprise est prête');
    }

    public function skip()
    {
        Tenant::current()->update(['onboarding_completed' => true]);

        return redirect()->route('dashboard');
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Models"
cat > "app/Models/Company.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;

class Company extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'name',
        'legal_name',
        'logo',
        'email',
        'phone',
        'address',
        'city',
        'country',
        'currency',
        'timezone',
        'business_type',
        'tax_identifier',
        'invoice_prefix',
        'onboarding_completed',
        'status',
    ];

    protected function casts(): array
    {
        return [
            'onboarding_completed' => 'boolean',
        ];
    }

    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }

    public function subscription(): HasOne
    {
        return $this->hasOne(Subscription::class);
    }

    public function activityLogs(): HasMany
    {
        return $this->hasMany(ActivityLog::class);
    }

    // Relations utilisées par le panneau admin plateforme (statistiques
    // par entreprise) — voir App\Http\Controllers\Admin\CompanyController.
    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }

    public function customers(): HasMany
    {
        return $this->hasMany(Customer::class);
    }

    public function sales(): HasMany
    {
        return $this->hasMany(Sale::class);
    }

    /**
     * Devise formatée selon config('parallelium.currencies').
     * Ne jamais coder le symbole "Ar" en dur dans les vues : utiliser
     * $company->currencySymbol() ou le helper App\Support\Money.
     */
    public function currencySymbol(): string
    {
        return config("parallelium.currencies.{$this->currency}.symbol", $this->currency);
    }

    /**
     * Le champ business_type peut contenir soit un mot-clé de catalogue
     * standard (ex. "epicerie_ppn"), soit un texte libre saisi via
     * "Autre" à l'onboarding. Ce helper affiche toujours un libellé
     * lisible, jamais le mot-clé brut.
     */
    public function businessTypeLabel(): ?string
    {
        if (! $this->business_type) {
            return null;
        }

        return \App\Services\BusinessCatalogService::options()[$this->business_type] ?? $this->business_type;
    }

    /**
     * Numéro de document suivant (facture, vente, dépense), unique par
     * entreprise. Incrémente atomiquement le compteur correspondant.
     */
    public function nextDocumentNumber(string $type): string
    {
        $column = "next_{$type}_number";
        $prefixKey = $type === 'invoice' ? $this->invoice_prefix : config("parallelium.document_prefixes.{$type}");

        $number = $this->{$column};

        $this->increment($column);

        return sprintf('%s-%s-%06d', $prefixKey, now()->format('Y'), $number);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/onboarding"
cat > "resources/views/onboarding/show.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.onboarding title="Bienvenue — Parallelium">
    <p class="text-sm font-semibold text-brand-600">Étape 1 sur 1</p>
    <h1 class="mt-1 text-2xl font-bold text-slate-900">Bienvenue sur Parallelium</h1>
    <p class="mt-2 text-sm text-slate-500">Parlez-nous un peu de {{ $company->name }} pour personnaliser votre espace.</p>

    @if (session('status'))
        <x-alert type="success" class="mt-4">{{ session('status') }}</x-alert>
    @endif

    @php
        $isKnownType = array_key_exists($company->business_type, $businessTypes);
        $selected = old('business_type', $isKnownType ? $company->business_type : ($company->business_type ? 'autre' : null));
    @endphp

    <form method="POST" action="{{ route('onboarding.update') }}" class="mt-6 space-y-4" x-data="{ type: '{{ $selected }}' }">
        @csrf
        @method('PUT')

        <div>
            <x-label for="business_type">Type d'activité</x-label>
            <select id="business_type" name="business_type" x-model="type" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400">
                <option value="">Sélectionner...</option>
                @foreach ($businessTypes as $slug => $label)
                    <option value="{{ $slug }}" @selected($selected === $slug)>{{ $label }}</option>
                @endforeach
                <option value="autre" @selected($selected === 'autre')>Autre</option>
            </select>
            <p class="mt-1 text-xs text-slate-400">
                On vous proposera une liste de produits standards à ajouter selon votre choix.
            </p>
        </div>

        <div x-show="type === 'autre'" x-cloak>
            <x-label for="business_type_other">Précisez votre activité</x-label>
            <x-input id="business_type_other" name="business_type_other" value="{{ old('business_type_other', $isKnownType ? '' : $company->business_type) }}" placeholder="Ex. Atelier de couture, salon de coiffure..." />
        </div>

        <div>
            <x-label for="phone">Téléphone de l'entreprise</x-label>
            <x-input id="phone" name="phone" value="{{ old('phone', $company->phone) }}" placeholder="034 xx xxx xx" />
        </div>

        <div>
            <x-label for="currency">Devise</x-label>
            <select id="currency" name="currency" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400">
                @foreach (config('parallelium.currencies') as $code => $c)
                    <option value="{{ $code }}" @selected(old('currency', $company->currency) === $code)>{{ $c['label'] }} ({{ $c['symbol'] }})</option>
                @endforeach
            </select>
        </div>

        <x-button type="submit" class="w-full justify-center" size="lg">Enregistrer</x-button>
    </form>

    @if ($isKnownType)
        <x-card class="mt-4">
            <p class="text-sm font-semibold text-slate-700">Produits standards disponibles</p>
            <p class="mt-1 text-xs text-slate-500">
                Nous avons une liste de produits courants pour « {{ $businessTypes[$company->business_type] }} ».
                Sans prix ni référence — à vous de les compléter ensuite selon vos fournisseurs.
            </p>
            <form method="POST" action="{{ route('onboarding.seed-catalog') }}" class="mt-3">
                @csrf
                <x-button type="submit" variant="secondary" size="sm">Ajouter ces produits à mon catalogue</x-button>
            </form>
        </x-card>
    @endif

    <form method="POST" action="{{ route('onboarding.finish') }}" class="mt-3">
        @csrf
        <x-button type="submit" variant="secondary" class="w-full justify-center" size="lg">
            C'est prêt, direction le tableau de bord
            <x-icon name="chevron-right" class="text-xs" />
        </x-button>
    </form>

    <form method="POST" action="{{ route('onboarding.skip') }}" class="mt-2">
        @csrf
        <button type="submit" class="w-full text-center text-xs font-medium text-slate-400 hover:text-slate-600">
            Passer cette étape
        </button>
    </form>
</x-layouts.onboarding>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/admin/companies"
cat > "resources/views/admin/companies/show.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.admin title="{{ $company->name }}">
    <div class="mb-5 flex flex-wrap items-start justify-between gap-3">
        <div>
            <a href="{{ route('admin.companies.index') }}" class="text-xs font-medium text-brand-600 hover:underline">&larr; Toutes les entreprises</a>
            <h1 class="mt-1 text-xl font-bold text-slate-900">
                {{ $company->name }}
                <x-badge :tone="$company->status === 'active' ? 'success' : 'danger'">{{ ucfirst($company->status) }}</x-badge>
            </h1>
            <p class="text-sm text-slate-500">Inscrite le {{ $company->created_at->format('d/m/Y') }} · {{ $company->city ?? 'Ville non renseignée' }}</p>
        </div>

        <div class="flex items-center gap-2">
            <x-button :href="route('admin.companies.edit', $company)" variant="secondary" size="sm">Modifier</x-button>

            @if ($company->status === 'active')
                <form method="POST" action="{{ route('admin.companies.suspend', $company) }}" onsubmit="return confirm('Suspendre cette entreprise ? Ses utilisateurs seront déconnectés.');">
                    @csrf
                    <x-button type="submit" variant="danger" size="sm">Suspendre</x-button>
                </form>
            @else
                <form method="POST" action="{{ route('admin.companies.activate', $company) }}">
                    @csrf
                    <x-button type="submit" variant="secondary" size="sm">Réactiver</x-button>
                </form>
            @endif

            @if ($company->status !== 'closed')
                <form method="POST" action="{{ route('admin.companies.close', $company) }}" onsubmit="return confirm('Fermer définitivement cette entreprise ? Cette action est difficilement réversible.');">
                    @csrf
                    <x-button type="submit" variant="ghost" size="sm">Fermer définitivement</x-button>
                </form>
            @endif
        </div>
    </div>

    <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <x-stat-card label="Utilisateurs" :value="$company->users_count" icon="customers" />
        <x-stat-card label="Produits" :value="$company->products_count" icon="products" />
        <x-stat-card label="Clients" :value="$company->customers_count" icon="customers" />
        <x-stat-card label="Ventes ce mois" :value="\App\Support\Money::format($salesThisMonth->revenue ?? 0, $company->currency)" icon="money" />
    </div>

    <div class="mt-6 grid gap-4 lg:grid-cols-2">
        <x-card>
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Coordonnées</h3>
            <dl class="space-y-2 text-sm">
                <div class="flex justify-between"><dt class="text-slate-400">E-mail</dt><dd class="text-slate-700">{{ $company->email ?? '—' }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-400">Téléphone</dt><dd class="text-slate-700">{{ $company->phone ?? '—' }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-400">Devise</dt><dd class="text-slate-700">{{ $company->currency }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-400">Type d'activité</dt><dd class="text-slate-700">{{ $company->businessTypeLabel() ?? '—' }}</dd></div>
            </dl>
        </x-card>

        <x-card>
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Abonnement</h3>
            <p class="text-sm text-slate-500">
                Plan actuel : <span class="font-semibold text-brand-700">{{ $plans[$company->subscription?->plan]['label'] ?? '—' }}</span>
                · Statut : {{ $company->subscription?->status ?? '—' }}
            </p>

            <form method="POST" action="{{ route('admin.companies.plan', $company) }}" class="mt-3 flex items-center gap-2">
                @csrf
                <select name="plan" class="flex-1 rounded-xl border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400">
                    @foreach ($plans as $slug => $plan)
                        <option value="{{ $slug }}" @selected($company->subscription?->plan === $slug)>{{ $plan['label'] }}</option>
                    @endforeach
                </select>
                <x-button type="submit" size="sm">Appliquer</x-button>
            </form>
        </x-card>
    </div>

    <div class="mt-4 grid gap-4 lg:grid-cols-2">
        <x-card>
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Utilisateurs</h3>
            <div class="divide-y divide-slate-100">
                @foreach ($company->users as $user)
                    <div class="flex items-center justify-between py-2 text-sm">
                        <div>
                            <p class="font-medium text-slate-800">{{ $user->name }}</p>
                            <p class="text-xs text-slate-400">{{ $user->email }}</p>
                        </div>
                        <div class="flex items-center gap-2">
                            <x-badge tone="brand">{{ $user->role?->name ?? '—' }}</x-badge>
                            @unless ($user->is_active)
                                <x-badge tone="danger">Inactif</x-badge>
                            @endunless
                            @if ($user->is_active)
                                <form method="POST" action="{{ route('admin.companies.impersonate', [$company, $user]) }}">
                                    @csrf
                                    <button type="submit" class="text-xs font-medium text-brand-600 hover:underline">
                                        Se connecter en tant que
                                    </button>
                                </form>
                            @endif
                        </div>
                    </div>
                @endforeach
            </div>
        </x-card>

        <x-card>
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Activité récente</h3>
            @if ($recentActivity->isEmpty())
                <p class="text-sm text-slate-400">Aucune action administrative enregistrée pour l'instant.</p>
            @else
                <div class="divide-y divide-slate-100">
                    @foreach ($recentActivity as $log)
                        <div class="py-2 text-sm">
                            <p class="text-slate-700">{{ str_replace('admin.', '', $log->action) }}</p>
                            <p class="text-xs text-slate-400">
                                {{ $log->created_at->format('d/m/Y H:i') }}
                                @if ($log->properties['admin_email'] ?? null) · {{ $log->properties['admin_email'] }} @endif
                            </p>
                        </div>
                    @endforeach
                </div>
            @endif
        </x-card>
    </div>
</x-layouts.admin>
PARALLELIUM_FILE_EOF

mkdir -p "routes"
cat > "routes/web.php" << 'PARALLELIUM_FILE_EOF'
<?php

use App\Http\Controllers\Auth\AuthenticatedSessionController;
use App\Http\Controllers\Auth\NewPasswordController;
use App\Http\Controllers\Auth\PasswordResetLinkController;
use App\Http\Controllers\Auth\RegisteredCompanyController;
use App\Http\Controllers\CategoryController;
use App\Http\Controllers\CustomerController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\EmployeeController;
use App\Http\Controllers\ExpenseController;
use App\Http\Controllers\ImpersonationController;
use App\Http\Controllers\InvoiceController;
use App\Http\Controllers\OnboardingController;
use App\Http\Controllers\ProductController;
use App\Http\Controllers\ReportController;
use App\Http\Controllers\SaleController;
use App\Http\Controllers\SettingsController;
use App\Http\Controllers\StockController;
use Illuminate\Support\Facades\Route;

Route::redirect('/', '/login');

// --- Invités ---
Route::middleware('guest')->group(function () {
    Route::get('register', [RegisteredCompanyController::class, 'create'])->name('register');
    Route::post('register', [RegisteredCompanyController::class, 'store'])->middleware('throttle:6,1');

    Route::get('login', [AuthenticatedSessionController::class, 'create'])->name('login');
    Route::post('login', [AuthenticatedSessionController::class, 'store']);

    Route::get('forgot-password', [PasswordResetLinkController::class, 'create'])->name('password.request');
    Route::post('forgot-password', [PasswordResetLinkController::class, 'store'])->name('password.email')->middleware('throttle:6,1');

    Route::get('reset-password/{token}', [NewPasswordController::class, 'create'])->name('password.reset');
    Route::post('reset-password', [NewPasswordController::class, 'store'])->name('password.store')->middleware('throttle:6,1');
});

// --- Authentifiés ---
Route::middleware('auth')->group(function () {
    Route::post('logout', [AuthenticatedSessionController::class, 'destroy'])->name('logout');
    Route::post('impersonation/stop', [ImpersonationController::class, 'stop'])->name('impersonation.stop');

    Route::prefix('onboarding')->name('onboarding.')->group(function () {
        Route::get('/', [OnboardingController::class, 'show'])->name('show');
        Route::put('/', [OnboardingController::class, 'update'])->name('update');
        Route::post('seed-catalog', [OnboardingController::class, 'seedCatalog'])->name('seed-catalog');
        Route::post('finish', [OnboardingController::class, 'finish'])->name('finish');
        Route::post('skip', [OnboardingController::class, 'skip'])->name('skip');
    });

    Route::middleware('onboarding')->group(function () {
        Route::get('dashboard', DashboardController::class)->name('dashboard');

        Route::resource('categories', CategoryController::class)->only(['index', 'store', 'update', 'destroy']);

        Route::resource('products', ProductController::class)->except(['show']);

        Route::get('stock', [StockController::class, 'index'])->name('stock.index');
        Route::post('stock/{product}/adjust', [StockController::class, 'adjust'])->name('stock.adjust');

        Route::resource('customers', CustomerController::class);

        Route::resource('sales', SaleController::class)->only(['index', 'create', 'store', 'show']);
        Route::post('sales/{sale}/cancel', [SaleController::class, 'cancel'])->name('sales.cancel');

        Route::resource('expenses', ExpenseController::class)->except(['show']);

        Route::resource('invoices', InvoiceController::class)->only(['index', 'show']);
        Route::post('sales/{sale}/invoice', [InvoiceController::class, 'generate'])->name('invoices.generate');
        Route::get('invoices/{invoice}/download', [InvoiceController::class, 'download'])->name('invoices.download');

        Route::resource('employees', EmployeeController::class)->only(['index', 'create', 'store', 'edit', 'update', 'destroy']);
        Route::post('employees/{employee}/resend-invite', [EmployeeController::class, 'resendInvite'])->name('employees.resend-invite');

        Route::prefix('reports')->name('reports.')->group(function () {
            Route::get('/', [ReportController::class, 'index'])->name('index');
            Route::get('sales', [ReportController::class, 'sales'])->name('sales');
            Route::get('expenses', [ReportController::class, 'expenses'])->name('expenses');
            Route::get('products', [ReportController::class, 'products'])->name('products');
            Route::get('customers', [ReportController::class, 'customers'])->name('customers');
        });

        Route::get('settings', [SettingsController::class, 'index'])->name('settings.index');
        Route::post('settings/subscription', [SettingsController::class, 'changePlan'])->name('settings.subscription');
    });
});
PARALLELIUM_FILE_EOF

mkdir -p "tests/Feature"
cat > "tests/Feature/BusinessCatalogTest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Product;
use App\Models\Role;
use App\Models\Subscription;
use App\Models\User;
use App\Services\BusinessCatalogService;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BusinessCatalogTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([PermissionSeeder::class, RoleSeeder::class]);
    }

    protected function ownerFor(Company $company): User
    {
        $role = Role::whereNull('company_id')->where('slug', 'owner')->first();

        return User::factory()->create(['company_id' => $company->id, 'role_id' => $role->id]);
    }

    public function test_seeding_the_epicerie_catalog_creates_products_with_no_price_and_no_stock(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'business', 'status' => 'active']);

        $result = app(BusinessCatalogService::class)->seed($company, 'epicerie_ppn');

        $this->assertGreaterThan(20, $result['created']);
        $this->assertEquals(0, $result['skipped_limit']);

        $product = Product::where('company_id', $company->id)->first();
        $this->assertEquals(0, $product->purchase_price);
        $this->assertEquals(0, $product->selling_price);
        $this->assertEquals(0, $product->stock_quantity);

        $this->assertDatabaseHas('products', ['company_id' => $company->id, 'name' => 'News Maitso']);
        $this->assertDatabaseHas('products', ['company_id' => $company->id, 'name' => 'News Mena']);
    }

    public function test_seeding_twice_does_not_create_duplicates(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'business', 'status' => 'active']);

        $service = app(BusinessCatalogService::class);
        $first = $service->seed($company, 'epicerie_ppn');
        $second = $service->seed($company, 'epicerie_ppn');

        $this->assertEquals(0, $second['created']);
        $this->assertEquals($first['created'], $second['skipped_duplicate']);
    }

    public function test_seeding_respects_the_plan_product_limit(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'free', 'status' => 'active']); // limite 20

        $result = app(BusinessCatalogService::class)->seed($company, 'epicerie_ppn');

        $this->assertEquals(20, $result['created']);
        $this->assertGreaterThan(0, $result['skipped_limit']);
        $this->assertDatabaseCount('products', 20);
    }

    public function test_owner_can_seed_catalog_from_onboarding(): void
    {
        $company = Company::factory()->create(['business_type' => 'epicerie_ppn', 'onboarding_completed' => false]);
        Subscription::create(['company_id' => $company->id, 'plan' => 'business', 'status' => 'active']);
        $owner = $this->ownerFor($company);

        $this->actingAs($owner)
            ->post(route('onboarding.seed-catalog'))
            ->assertRedirect(route('onboarding.show'));

        $this->assertGreaterThan(0, Product::where('company_id', $company->id)->count());
    }

    public function test_a_free_text_business_type_displays_as_is_not_as_a_raw_slug(): void
    {
        $company = Company::factory()->create(['business_type' => 'Atelier de couture']);

        $this->assertEquals('Atelier de couture', $company->businessTypeLabel());
    }

    public function test_a_known_catalog_slug_displays_its_readable_label(): void
    {
        $company = Company::factory()->create(['business_type' => 'epicerie_ppn']);

        $this->assertEquals(BusinessCatalogService::options()['epicerie_ppn'], $company->businessTypeLabel());
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "tests/Feature"
cat > "tests/Feature/RolePermissionUiTest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Services\SaleService;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Un vendeur ne doit voir NI le chiffre d'affaires, NI un lien de
 * navigation vers une page à laquelle il n'a pas accès — jamais un lien
 * cliquable qui finit sur "non autorisé" (demande explicite du client).
 */
class RolePermissionUiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([PermissionSeeder::class, RoleSeeder::class]);
    }

    protected function userWithRole(Company $company, string $slug): User
    {
        $role = Role::whereNull('company_id')->where('slug', $slug)->first();

        return User::factory()->create(['company_id' => $company->id, 'role_id' => $role->id]);
    }

    public function test_a_seller_does_not_see_revenue_figures_on_the_dashboard(): void
    {
        $company = Company::factory()->create();
        $seller = $this->userWithRole($company, 'seller');
        $owner = $this->userWithRole($company, 'owner');

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 10, 'selling_price' => 50000]);
        app(SaleService::class)->create([
            'items' => [['product_id' => $product->id, 'quantity' => 2]],
            'paid_amount' => 100000,
            'payment_method' => 'cash',
        ], $owner);

        $response = $this->actingAs($seller)->get(route('dashboard'));

        $response->assertOk();
        $response->assertDontSee("Chiffre d'affaires");
        $response->assertDontSee('Résultat estimé');
        // Les ventes récentes restent visibles (le vendeur y a déjà accès
        // via sa permission sales.view) : seul le CA AGRÉGÉ est masqué.
        $response->assertSee('Dernières ventes');
    }

    public function test_a_manager_does_see_revenue_figures_on_the_dashboard(): void
    {
        $company = Company::factory()->create();
        $manager = $this->userWithRole($company, 'manager');

        $response = $this->actingAs($manager)->get(route('dashboard'));

        $response->assertOk();
        $response->assertSee("Chiffre d'affaires");
    }

    public function test_a_seller_does_not_see_a_link_to_reports_in_navigation(): void
    {
        $company = Company::factory()->create();
        $seller = $this->userWithRole($company, 'seller');

        $response = $this->actingAs($seller)->get(route('dashboard'));

        $response->assertOk();
        $response->assertDontSee(route('reports.index'), false);
        $response->assertDontSee(route('employees.index'), false);
        $response->assertDontSee(route('settings.index'), false);
    }

    public function test_a_seller_visiting_reports_directly_is_still_forbidden(): void
    {
        $company = Company::factory()->create();
        $seller = $this->userWithRole($company, 'seller');

        $this->actingAs($seller)->get(route('reports.index'))->assertForbidden();
    }

    public function test_an_accountant_sees_reports_link_but_not_sales_creation_quick_action(): void
    {
        $company = Company::factory()->create();
        $accountant = $this->userWithRole($company, 'accountant');

        $response = $this->actingAs($accountant)->get(route('dashboard'));

        $response->assertOk();
        $response->assertSee(route('reports.index'), false);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "tests/Feature"
cat > "tests/Feature/ReportTest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Expense;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Services\ReportService;
use App\Services\SaleService;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ReportTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([PermissionSeeder::class, RoleSeeder::class]);
    }

    protected function ownerFor(Company $company): User
    {
        $role = Role::whereNull('company_id')->where('slug', 'owner')->first();

        return User::factory()->create(['company_id' => $company->id, 'role_id' => $role->id]);
    }

    public function test_sales_report_totals_match_completed_sales_in_period(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 10, 'selling_price' => 5000]);
        app(SaleService::class)->create([
            'items' => [['product_id' => $product->id, 'quantity' => 2]],
            'paid_amount' => 6000,
            'payment_method' => 'cash',
        ], $owner);

        $report = app(ReportService::class)->salesReport(now()->startOfMonth(), now()->endOfMonth());

        $this->assertEquals(1, $report['count']);
        $this->assertEquals(10000, $report['revenue']);
        $this->assertEquals(6000, $report['paid']);
        $this->assertEquals(4000, $report['remaining']);
    }

    public function test_products_report_does_not_leak_across_companies(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();
        $ownerA = $this->ownerFor($companyA);
        $ownerB = $this->ownerFor($companyB);

        $productA = Product::factory()->create(['company_id' => $companyA->id, 'stock_quantity' => 10, 'selling_price' => 1000, 'name' => 'Produit A']);
        $productB = Product::factory()->create(['company_id' => $companyB->id, 'stock_quantity' => 10, 'selling_price' => 1000, 'name' => 'Produit B']);

        $this->actingAs($ownerB);
        app(SaleService::class)->create(['items' => [['product_id' => $productB->id, 'quantity' => 1]], 'paid_amount' => 1000, 'payment_method' => 'cash'], $ownerB);

        $this->actingAs($ownerA);
        app(SaleService::class)->create(['items' => [['product_id' => $productA->id, 'quantity' => 1]], 'paid_amount' => 1000, 'payment_method' => 'cash'], $ownerA);

        $report = app(ReportService::class)->productsReport(now()->startOfMonth(), now()->endOfMonth());

        $this->assertCount(1, $report['rows']);
        $this->assertEquals('Produit A', $report['rows']->first()->name);
    }

    public function test_expenses_report_groups_by_category(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        Expense::factory()->create(['company_id' => $company->id, 'category' => 'transport', 'amount' => 10000, 'expense_date' => now()]);
        Expense::factory()->create(['company_id' => $company->id, 'category' => 'transport', 'amount' => 5000, 'expense_date' => now()]);
        Expense::factory()->create(['company_id' => $company->id, 'category' => 'rent', 'amount' => 300000, 'expense_date' => now()]);

        $report = app(ReportService::class)->expensesReport(now()->startOfMonth(), now()->endOfMonth());

        $this->assertEquals(315000, $report['total']);
        $transport = $report['byCategory']->firstWhere('label', 'Transport');
        $this->assertEquals(15000, $transport['total']);
        $this->assertEquals(2, $transport['count']);
    }

    public function test_csv_export_is_downloadable_by_an_authorized_user(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);

        $response = $this->actingAs($owner)->get(route('reports.sales', ['export' => 'csv']));

        $response->assertOk();
        $response->assertHeader('content-type', 'text/csv; charset=UTF-8');
    }

    public function test_a_seller_cannot_access_reports(): void
    {
        $company = Company::factory()->create();
        $sellerRole = Role::whereNull('company_id')->where('slug', 'seller')->first();
        $seller = User::factory()->create(['company_id' => $company->id, 'role_id' => $sellerRole->id]);

        $this->actingAs($seller)->get(route('reports.index'))->assertForbidden();
    }

    public function test_comparing_two_periods_computes_both_reports_and_the_delta(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 100, 'selling_price' => 10000]);
        $saleService = app(SaleService::class);

        // Période A : 2 ventes (sold_at forcé après coup, la vente se crée "maintenant").
        $saleService->create(['items' => [['product_id' => $product->id, 'quantity' => 1]], 'paid_amount' => 10000, 'payment_method' => 'cash'], $owner);
        $saleA2 = $saleService->create(['items' => [['product_id' => $product->id, 'quantity' => 1]], 'paid_amount' => 10000, 'payment_method' => 'cash'], $owner);

        // Période B (mois dernier) : 1 vente, forcée dans le passé directement en base.
        $saleB = $saleService->create(['items' => [['product_id' => $product->id, 'quantity' => 1]], 'paid_amount' => 10000, 'payment_method' => 'cash'], $owner);
        $saleB->update(['sold_at' => now()->subMonthNoOverflow()->startOfMonth()->addDay()]);

        $report = app(ReportService::class);
        [$fromA, $toA] = [now()->startOfMonth(), now()->endOfMonth()];
        [$fromB, $toB] = [now()->subMonthNoOverflow()->startOfMonth(), now()->subMonthNoOverflow()->endOfMonth()];

        $comparison = $report->compareSales($fromA, $toA, $fromB, $toB);

        $this->assertEquals(2, $comparison['a']['count']);
        $this->assertEquals(1, $comparison['b']['count']);
        $this->assertEquals(20000, $comparison['a']['revenue']);
        $this->assertEquals(10000, $comparison['b']['revenue']);
        // +100% de CA (20 000 contre 10 000) et +100% de ventes (2 contre 1).
        $this->assertEquals(100.0, $comparison['revenue_change']);
        $this->assertEquals(100.0, $comparison['count_change']);
    }

    public function test_sales_report_compare_mode_is_reachable_via_the_route(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);

        $this->actingAs($owner)
            ->get(route('reports.sales', [
                'compare' => 1,
                'from' => now()->startOfMonth()->format('Y-m-d'),
                'to' => now()->endOfMonth()->format('Y-m-d'),
                'from_b' => now()->subMonthNoOverflow()->startOfMonth()->format('Y-m-d'),
                'to_b' => now()->subMonthNoOverflow()->endOfMonth()->format('Y-m-d'),
            ]))
            ->assertOk()
            ->assertSee('Comparer deux périodes');
    }
}
PARALLELIUM_FILE_EOF

echo "Termine. Lance maintenant :"
echo "  php artisan db:seed --class=Database\\Seeders\\PermissionSeeder"
echo "  php artisan db:seed --class=Database\\Seeders\\RoleSeeder"
echo "  php artisan view:clear"
