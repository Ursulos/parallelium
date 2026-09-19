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
                // $row est une instance Expense : 'category' est déjà
                // castée en ExpenseCategory par le modèle, pas une chaîne.
                'label' => $row->category->label(),
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
