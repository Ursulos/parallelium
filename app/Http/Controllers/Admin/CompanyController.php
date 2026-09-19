<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Services\SubscriptionService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Panneau admin PLATEFORME : vue transversale sur toutes les
 * entreprises, hors du système de permissions par tenant (§32/§34 —
 * réservé au guard "admin", jamais accessible depuis un compte
 * d'entreprise).
 */
class CompanyController extends Controller
{
    public function index(Request $request)
    {
        $companies = Company::withCount(['users', 'products', 'customers'])
            ->with('subscription')
            ->when($request->filled('q'), fn ($q) => $q->where('name', 'like', '%'.$request->string('q').'%'))
            ->when($request->filled('status'), fn ($q) => $q->where('status', $request->string('status')))
            ->latest()
            ->paginate(20)
            ->withQueryString();

        $stats = [
            'total' => Company::count(),
            'active' => Company::where('status', 'active')->count(),
            'suspended' => Company::where('status', 'suspended')->count(),
            'paying' => Company::whereHas('subscription', fn ($q) => $q->where('plan', '!=', 'free'))->count(),
        ];

        $plans = config('parallelium.plans');

        return view('admin.companies.index', compact('companies', 'stats', 'plans'));
    }

    public function show(Company $company)
    {
        $company->loadCount(['users', 'products', 'customers'])
            ->load(['subscription', 'users' => fn ($q) => $q->orderBy('name')]);

        $salesThisMonth = $company->sales()
            ->where('sale_status', 'completed')
            ->whereBetween('sold_at', [now()->startOfMonth(), now()->endOfMonth()])
            ->selectRaw('COUNT(*) as count, COALESCE(SUM(total_amount), 0) as revenue')
            ->first();

        $plans = config('parallelium.plans');

        return view('admin.companies.show', compact('company', 'salesThisMonth', 'plans'));
    }

    public function suspend(Company $company)
    {
        $company->update(['status' => 'suspended']);

        return back()->with('status', "« {$company->name} » a été suspendue. Ses utilisateurs seront déconnectés à leur prochaine action.");
    }

    public function activate(Company $company)
    {
        $company->update(['status' => 'active']);

        return back()->with('status', "« {$company->name} » est de nouveau active.");
    }

    public function changePlan(Request $request, Company $company, SubscriptionService $subscriptionService)
    {
        $request->validate([
            'plan' => ['required', Rule::in(array_keys(config('parallelium.plans')))],
        ]);

        $subscriptionService->changePlan($company, $request->string('plan')->toString());

        return back()->with('status', "Plan de « {$company->name} » mis à jour.");
    }
}
