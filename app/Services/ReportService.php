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
