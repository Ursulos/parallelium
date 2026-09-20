<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Company;
use App\Models\User;
use App\Services\SubscriptionService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
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
        $recentActivity = ActivityLog::where('company_id', $company->id)->latest('created_at')->limit(10)->get();

        return view('admin.companies.show', compact('company', 'salesThisMonth', 'plans', 'recentActivity'));
    }

    public function edit(Company $company)
    {
        return view('admin.companies.edit', compact('company'));
    }

    public function update(Request $request, Company $company)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['nullable', 'email', 'max:255'],
            'phone' => ['nullable', 'string', 'max:30'],
            'city' => ['nullable', 'string', 'max:255'],
            'currency' => ['required', Rule::in(array_keys(config('parallelium.currencies')))],
        ]);

        $company->update($data);
        $this->logAction($company, 'admin.company_updated', ['fields' => array_keys($data)]);

        return redirect()->route('admin.companies.show', $company)->with('status', 'Entreprise mise à jour.');
    }

    public function suspend(Company $company)
    {
        $company->update(['status' => 'suspended']);
        $this->logAction($company, 'admin.company_suspended');

        return back()->with('status', "« {$company->name} » a été suspendue. Ses utilisateurs seront déconnectés à leur prochaine action.");
    }

    public function activate(Company $company)
    {
        $company->update(['status' => 'active']);
        $this->logAction($company, 'admin.company_activated');

        return back()->with('status', "« {$company->name} » est de nouveau active.");
    }

    public function close(Company $company)
    {
        $company->update(['status' => 'closed']);
        $this->logAction($company, 'admin.company_closed');

        return back()->with('status', "« {$company->name} » a été fermée définitivement.");
    }

    public function changePlan(Request $request, Company $company, SubscriptionService $subscriptionService)
    {
        $request->validate([
            'plan' => ['required', Rule::in(array_keys(config('parallelium.plans')))],
        ]);

        $plan = $request->string('plan')->toString();
        $subscriptionService->changePlan($company, $plan);
        $this->logAction($company, 'admin.plan_changed', ['plan' => $plan]);

        return back()->with('status', "Plan de « {$company->name} » mis à jour.");
    }

    /**
     * "Se connecter en tant que" — bascule la session sur le guard "web"
     * en tant qu'utilisateur de l'entreprise, à des fins de support. La
     * session admin (guard "admin") reste intacte en parallèle : les deux
     * guards cohabitent dans la même session sans jamais se confondre
     * (voir aussi ImpersonationController::stop côté tenant).
     */
    public function impersonate(Request $request, Company $company, User $user)
    {
        abort_if($user->company_id !== $company->id, 404);

        $admin = $request->user('admin');

        session([
            'impersonating_admin_id' => $admin->id,
            'impersonating_admin_name' => $admin->name,
            'impersonating_company_id' => $company->id,
        ]);

        Auth::guard('web')->login($user);
        $this->logAction($company, 'admin.impersonation_started', ['target_user_id' => $user->id, 'admin_email' => $admin->email]);

        return redirect()->route('dashboard');
    }

    protected function logAction(Company $company, string $action, array $properties = []): void
    {
        $admin = auth('admin')->user();

        ActivityLog::create([
            'company_id' => $company->id,
            'user_id' => null,
            'action' => $action,
            'properties' => array_merge($properties, [
                'admin_id' => $admin?->id,
                'admin_email' => $admin?->email,
            ]),
            'ip_address' => request()->ip(),
        ]);
    }
}
