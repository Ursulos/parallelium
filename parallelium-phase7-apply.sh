#!/usr/bin/env bash
#
# Parallelium - Phase 7 (Dashboard : graphiques, tendances)
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
# Compatible Git Bash / WSL sous Windows.
set -e
echo "Application des fichiers Phase 7..."

mkdir -p "app/Services"
cat > "app/Services/DashboardService.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\Expense;
use App\Models\Product;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Support\Tenant;
use Illuminate\Support\Carbon;

/**
 * Centralise le calcul des indicateurs et graphiques du tableau de bord
 * (cahier des charges §20-§22) : le Controller reste léger, toute la
 * logique de calcul vit ici. Le dashboard n'affiche que des données
 * réelles — jamais de valeurs fictives (§30, §51).
 */
class DashboardService
{
    public function summary(): array
    {
        return [
            'kpis' => $this->kpis(),
            'lowStockProducts' => Product::active()->lowStock()->orderBy('stock_quantity')->limit(5)->get(),
            'recentSales' => Sale::with('customer')->latest('sold_at')->limit(5)->get(),
            'recentExpenses' => Expense::latest('expense_date')->limit(5)->get(),
            'charts' => [
                'salesLast7Days' => $this->salesLast7Days(),
                'salesByCategory' => $this->salesByCategory(),
                'expensesByCategory' => $this->expensesByCategory(),
                'topProducts' => $this->topProducts(),
            ],
        ];
    }

    protected function kpis(): array
    {
        $completedSales = Sale::completed();

        $revenueToday = (clone $completedSales)->whereDate('sold_at', today())->sum('total_amount');
        $revenueYesterday = (clone $completedSales)->whereDate('sold_at', today()->subDay())->sum('total_amount');

        $revenueMonth = (clone $completedSales)->whereBetween('sold_at', [now()->startOfMonth(), now()->endOfMonth()])->sum('total_amount');
        $revenueLastMonth = (clone $completedSales)->whereBetween('sold_at', [
            now()->subMonthNoOverflow()->startOfMonth(), now()->subMonthNoOverflow()->endOfMonth(),
        ])->sum('total_amount');

        $receivables = (clone $completedSales)->where('payment_status', '!=', 'paid')->sum('remaining_amount');
        $expensesMonth = Expense::whereBetween('expense_date', [now()->startOfMonth(), now()->endOfMonth()])->sum('amount');

        return [
            'revenue_today' => $revenueToday,
            'revenue_today_change' => $this->percentChange($revenueYesterday, $revenueToday),
            'revenue_month' => $revenueMonth,
            'revenue_month_change' => $this->percentChange($revenueLastMonth, $revenueMonth),
            'expenses_month' => $expensesMonth,
            'estimated_result' => $revenueMonth - $expensesMonth,
            'low_stock_count' => Product::active()->lowStock()->count(),
            'receivables' => $receivables,
            'customers_count' => Customer::active()->count(),
        ];
    }

    /**
     * Variation en pourcentage entre deux périodes, ou null si la période
     * précédente est à zéro (comparaison non pertinente — §51).
     */
    protected function percentChange(float $previous, float $current): ?float
    {
        if ($previous <= 0) {
            return null;
        }

        return round((($current - $previous) / $previous) * 100, 1);
    }

    protected function salesLast7Days(): array
    {
        $days = collect(range(6, 0))->map(fn ($i) => today()->subDays($i));

        $totals = Sale::completed()
            ->whereBetween('sold_at', [today()->subDays(6)->startOfDay(), today()->endOfDay()])
            ->selectRaw('DATE(sold_at) as day, SUM(total_amount) as total')
            ->groupBy('day')
            ->pluck('total', 'day');

        return $days->map(fn (Carbon $day) => [
            'label' => $day->translatedFormat('D'),
            'total' => (float) ($totals[$day->format('Y-m-d')] ?? 0),
        ])->all();
    }

    protected function salesByCategory(): array
    {
        // Requête via jointures brutes : le scope tenant automatique de
        // Sale/Product ne s'applique PAS ici (il ne joue que sur les
        // requêtes Eloquent passant par ces modèles), d'où le filtre
        // explicite sur company_id — jamais de fuite entre entreprises.
        return SaleItem::query()
            ->join('sales', 'sales.id', '=', 'sale_items.sale_id')
            ->join('products', 'products.id', '=', 'sale_items.product_id')
            ->leftJoin('categories', 'categories.id', '=', 'products.category_id')
            ->where('sales.company_id', Tenant::id())
            ->where('sales.sale_status', 'completed')
            ->whereBetween('sales.sold_at', [now()->startOfMonth(), now()->endOfMonth()])
            ->selectRaw("COALESCE(categories.name, 'Sans catégorie') as label, SUM(sale_items.subtotal) as total")
            ->groupBy('label')
            ->orderByDesc('total')
            ->limit(6)
            ->get()
            ->map(fn ($row) => ['label' => $row->label, 'total' => (float) $row->total])
            ->all();
    }

    protected function expensesByCategory(): array
    {
        return Expense::query()
            ->whereBetween('expense_date', [now()->startOfMonth(), now()->endOfMonth()])
            ->selectRaw('category, SUM(amount) as total')
            ->groupBy('category')
            ->orderByDesc('total')
            ->get()
            ->map(fn ($row) => [
                'label' => \App\Enums\ExpenseCategory::from($row->category)->label(),
                'total' => (float) $row->total,
            ])
            ->all();
    }

    protected function topProducts(): array
    {
        // Même remarque que salesByCategory : filtre tenant explicite
        // requis puisque ce sont des jointures brutes.
        return SaleItem::query()
            ->join('sales', 'sales.id', '=', 'sale_items.sale_id')
            ->join('products', 'products.id', '=', 'sale_items.product_id')
            ->where('sales.company_id', Tenant::id())
            ->where('sales.sale_status', 'completed')
            ->whereBetween('sales.sold_at', [now()->startOfMonth(), now()->endOfMonth()])
            ->selectRaw('products.name as label, SUM(sale_items.quantity) as quantity')
            ->groupBy('products.id', 'products.name')
            ->orderByDesc('quantity')
            ->limit(5)
            ->get()
            ->map(fn ($row) => ['label' => $row->label, 'quantity' => (int) $row->quantity])
            ->all();
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/DashboardController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use App\Services\DashboardService;
use App\Support\Tenant;

class DashboardController extends Controller
{
    public function __invoke(DashboardService $dashboardService)
    {
        $company = Tenant::current();

        $data = $dashboardService->summary();

        return view('dashboard', array_merge(['company' => $company], $data));
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "resources/views"
cat > "resources/views/dashboard.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Tableau de bord">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Bonjour {{ explode(' ', auth()->user()->name)[0] }}</h2>
        <p class="text-sm text-slate-500">Voici un aperçu de {{ $company->name }}.</p>
    </div>

    <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
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
        <x-stat-card label="Dépenses (mois)" :value="\App\Support\Money::format($kpis['expenses_month'])" icon="expenses" />
        <x-stat-card label="Résultat estimé" :value="\App\Support\Money::format($kpis['estimated_result'])" tone="brand" icon="result" />
    </div>

    <p class="mt-3 text-xs text-slate-400">
        Le résultat affiché est un indicateur de gestion interne, pas un résultat comptable officiel.
    </p>

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

    <div class="mt-4 grid gap-4 lg:grid-cols-2">
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
    </div>

    <div class="mt-6 grid gap-4 lg:grid-cols-2">
        <x-card>
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Chiffre d'affaires — 7 derniers jours</h3>
            @if (collect($charts['salesLast7Days'])->sum('total') > 0)
                <canvas id="chart-sales-7d" height="180"></canvas>
            @else
                <p class="py-8 text-center text-sm text-slate-400">Pas encore de ventes cette semaine.</p>
            @endif
        </x-card>

        <x-card>
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Top produits vendus (ce mois-ci)</h3>
            @if (count($charts['topProducts']) > 0)
                <canvas id="chart-top-products" height="180"></canvas>
            @else
                <p class="py-8 text-center text-sm text-slate-400">Aucune vente ce mois-ci.</p>
            @endif
        </x-card>

        <x-card>
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Ventes par catégorie (ce mois-ci)</h3>
            @if (count($charts['salesByCategory']) > 0)
                <canvas id="chart-sales-category" height="200"></canvas>
            @else
                <p class="py-8 text-center text-sm text-slate-400">Aucune vente ce mois-ci.</p>
            @endif
        </x-card>

        <x-card>
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Dépenses par catégorie (ce mois-ci)</h3>
            @if (count($charts['expensesByCategory']) > 0)
                <canvas id="chart-expenses-category" height="200"></canvas>
            @else
                <p class="py-8 text-center text-sm text-slate-400">Aucune dépense ce mois-ci.</p>
            @endif
        </x-card>
    </div>

    @if (collect($charts['salesLast7Days'])->sum('total') > 0 || count($charts['topProducts']) > 0 || count($charts['salesByCategory']) > 0 || count($charts['expensesByCategory']) > 0)
        <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.4/chart.umd.min.js" integrity="sha512-e3nkTaqZ4qhAtI22fMPCH7ELiC4qhBQCiCTgKXWBTx6jHU0y3TKO5+ez+IEK9nnMx7DdMg0jZQBcwSj2Hn45Sw==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
        <script>
            document.addEventListener('DOMContentLoaded', () => {
                const brand = '#6a35c2';
                const palette = ['#6a35c2', '#c22fb0', '#8760d1', '#dd5ed0', '#481f89', '#f5bff0'];

                const sales7d = @json($charts['salesLast7Days']);
                const topProducts = @json($charts['topProducts']);
                const salesByCategory = @json($charts['salesByCategory']);
                const expensesByCategory = @json($charts['expensesByCategory']);

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

echo "Termine. Lance maintenant : php artisan view:clear"
