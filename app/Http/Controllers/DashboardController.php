<?php

namespace App\Http\Controllers;

use App\Models\Customer;
use App\Models\Expense;
use App\Models\Product;
use App\Models\Sale;
use App\Support\Tenant;

class DashboardController extends Controller
{
    public function __invoke()
    {
        $company = Tenant::current();

        $completedSales = Sale::completed();

        $revenueToday = (clone $completedSales)->whereDate('sold_at', today())->sum('total_amount');
        $revenueMonth = (clone $completedSales)->whereBetween('sold_at', [now()->startOfMonth(), now()->endOfMonth()])->sum('total_amount');
        $receivables = (clone $completedSales)->where('payment_status', '!=', 'paid')->sum('remaining_amount');

        $expensesMonth = Expense::whereBetween('expense_date', [now()->startOfMonth(), now()->endOfMonth()])->sum('amount');

        $kpis = [
            'revenue_today' => $revenueToday,
            'revenue_month' => $revenueMonth,
            'expenses_month' => $expensesMonth,
            'estimated_result' => $revenueMonth - $expensesMonth,
            'low_stock_count' => Product::active()->lowStock()->count(),
            'receivables' => $receivables,
            'customers_count' => Customer::active()->count(),
        ];

        $lowStockProducts = Product::active()->lowStock()->orderBy('stock_quantity')->limit(5)->get();
        $recentSales = Sale::with('customer')->latest('sold_at')->limit(5)->get();
        $recentExpenses = Expense::latest('expense_date')->limit(5)->get();

        return view('dashboard', compact('company', 'kpis', 'lowStockProducts', 'recentSales', 'recentExpenses'));
    }
}
