<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Models\Sale;
use App\Models\Subscription;
use App\Models\User;
use Illuminate\Support\Carbon;

class DashboardController extends Controller
{
    public function __invoke()
    {
        $plans = config('parallelium.plans');

        $stats = [
            'companies' => Company::count(),
            'active_companies' => Company::where('status', 'active')->count(),
            'suspended_companies' => Company::where('status', 'suspended')->count(),
            'total_users' => User::count(),
            'sales_this_month' => Sale::where('sale_status', 'completed')
                ->whereBetween('sold_at', [now()->startOfMonth(), now()->endOfMonth()])
                ->count(),
        ];

        // MRR estimatif : somme des prix mensuels des abonnements actifs
        // payants. Purement indicatif (pas de facturation réelle en V1 —
        // voir §32 du cahier des charges).
        $mrr = Subscription::where('status', 'active')
            ->get()
            ->sum(fn (Subscription $s) => $plans[$s->plan]['price'] ?? 0);

        $planBreakdown = Subscription::selectRaw('plan, COUNT(*) as count')
            ->groupBy('plan')
            ->pluck('count', 'plan');

        // Inscriptions des 14 derniers jours, pour visualiser la croissance.
        $signupsByDay = collect(range(13, 0))->map(function ($i) {
            $day = today()->subDays($i);

            return [
                'label' => $day->format('d/m'),
                'count' => Company::whereDate('created_at', $day)->count(),
            ];
        });

        $topCompanies = Company::withSum(['sales as month_revenue' => function ($q) {
            $q->where('sale_status', 'completed')
                ->whereBetween('sold_at', [now()->startOfMonth(), now()->endOfMonth()]);
        }], 'total_amount')
            ->orderByDesc('month_revenue')
            ->limit(5)
            ->get();

        return view('admin.dashboard', compact('stats', 'mrr', 'planBreakdown', 'signupsByDay', 'topCompanies', 'plans'));
    }
}
