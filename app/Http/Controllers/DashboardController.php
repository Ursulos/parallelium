<?php

namespace App\Http\Controllers;

use App\Support\Tenant;

class DashboardController extends Controller
{
    public function __invoke()
    {
        $company = Tenant::current();

        // Les modules Ventes/Dépenses/Stock arrivent en Phase 2 à 7 :
        // ces indicateurs sont à zéro par défaut, jamais des données
        // fictives, en attendant que ces modules existent.
        $kpis = [
            'revenue_today' => 0,
            'revenue_month' => 0,
            'expenses_month' => 0,
            'estimated_result' => 0,
            'low_stock_count' => 0,
            'receivables' => 0,
            'customers_count' => 0,
        ];

        return view('dashboard', compact('company', 'kpis'));
    }
}
