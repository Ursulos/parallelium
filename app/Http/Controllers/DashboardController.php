<?php

namespace App\Http\Controllers;

use App\Models\Customer;
use App\Models\Product;
use App\Support\Tenant;

class DashboardController extends Controller
{
    public function __invoke()
    {
        $company = Tenant::current();

        // Les modules Ventes/Dépenses arrivent en Phase 4 et 5 : ces
        // indicateurs restent à zéro, jamais de données fictives, en
        // attendant que ces modules existent. Produits/Stock (Phase 2) et
        // Clients (Phase 3) alimentent désormais réellement le dashboard.
        $kpis = [
            'revenue_today' => 0,
            'revenue_month' => 0,
            'expenses_month' => 0,
            'estimated_result' => 0,
            'low_stock_count' => Product::active()->lowStock()->count(),
            'receivables' => 0,
            'customers_count' => Customer::active()->count(),
        ];

        $lowStockProducts = Product::active()->lowStock()->orderBy('stock_quantity')->limit(5)->get();

        return view('dashboard', compact('company', 'kpis', 'lowStockProducts'));
    }
}
