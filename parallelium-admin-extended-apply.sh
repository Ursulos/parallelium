#!/usr/bin/env bash
#
# Parallelium - Extension du panneau admin (dashboard, gestion des admins,
# edition/fermeture d'entreprise, impersonation, audit log)
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
# Compatible Git Bash / WSL sous Windows.
set -e
echo "Application des fichiers..."

mkdir -p "app/Http/Controllers/Admin"
cat > "app/Http/Controllers/Admin/DashboardController.php" << 'PARALLELIUM_FILE_EOF'
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
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers/Admin"
cat > "app/Http/Controllers/Admin/AdminUserController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Admin;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class AdminUserController extends Controller
{
    public function index()
    {
        $admins = Admin::orderBy('name')->paginate(20);

        return view('admin.admins.index', compact('admins'));
    }

    public function create()
    {
        return view('admin.admins.create');
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:admins,email'],
            'password' => ['required', 'confirmed', Password::defaults()],
        ]);

        Admin::create($data);

        return redirect()->route('admin.admins.index')->with('status', 'Administrateur ajouté.');
    }

    public function destroy(Request $request, Admin $admin)
    {
        if ($admin->id === $request->user('admin')->id) {
            return back()->withErrors(['admin' => 'Vous ne pouvez pas supprimer votre propre compte.']);
        }

        if (Admin::count() <= 1) {
            return back()->withErrors(['admin' => 'Impossible de supprimer le dernier compte administrateur.']);
        }

        $admin->delete();

        return back()->with('status', 'Administrateur supprimé.');
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers/Admin"
cat > "app/Http/Controllers/Admin/CompanyController.php" << 'PARALLELIUM_FILE_EOF'
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
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/ImpersonationController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

/**
 * Fin de la session "se connecter en tant que" démarrée depuis le
 * panneau admin plateforme (voir Admin\CompanyController::impersonate).
 * La session du guard "admin" cohabite avec celle du guard "web" dans le
 * même cookie de session : on ne fait ici que fermer la session "web" et
 * nettoyer les indicateurs, la session admin reste intacte.
 */
class ImpersonationController extends Controller
{
    public function stop(Request $request)
    {
        $companyId = session('impersonating_company_id');

        session()->forget(['impersonating_admin_id', 'impersonating_admin_name', 'impersonating_company_id']);

        // Guard::logout() ne retire QUE la clé de session propre au guard
        // "web" — jamais session()->invalidate(), qui effacerait aussi la
        // session du guard "admin" logée dans le même cookie.
        Auth::guard('web')->logout();
        $request->session()->regenerateToken();

        return $companyId
            ? redirect()->route('admin.companies.show', $companyId)
            : redirect()->route('admin.companies.index');
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "routes"
cat > "routes/admin.php" << 'PARALLELIUM_FILE_EOF'
<?php

use App\Http\Controllers\Admin\AdminUserController;
use App\Http\Controllers\Admin\AuthController;
use App\Http\Controllers\Admin\CompanyController;
use App\Http\Controllers\Admin\DashboardController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Routes ADMIN PLATEFORME
|--------------------------------------------------------------------------
|
| Complètement séparées des routes tenant (routes/web.php) : guard
| "admin" dédié, aucun chevauchement de session ni de permissions avec
| le système de rôles par entreprise (owner/manager/seller/accountant).
|
*/

Route::prefix('admin')->name('admin.')->group(function () {
    Route::middleware('guest:admin')->group(function () {
        Route::get('login', [AuthController::class, 'create'])->name('login');
        Route::post('login', [AuthController::class, 'store'])->middleware('throttle:10,1');
    });

    Route::middleware('auth:admin')->group(function () {
        Route::post('logout', [AuthController::class, 'destroy'])->name('logout');

        Route::redirect('/', '/admin/dashboard');
        Route::get('dashboard', DashboardController::class)->name('dashboard');

        Route::get('companies', [CompanyController::class, 'index'])->name('companies.index');
        Route::get('companies/{company}', [CompanyController::class, 'show'])->name('companies.show');
        Route::get('companies/{company}/edit', [CompanyController::class, 'edit'])->name('companies.edit');
        Route::put('companies/{company}', [CompanyController::class, 'update'])->name('companies.update');
        Route::post('companies/{company}/suspend', [CompanyController::class, 'suspend'])->name('companies.suspend');
        Route::post('companies/{company}/activate', [CompanyController::class, 'activate'])->name('companies.activate');
        Route::post('companies/{company}/close', [CompanyController::class, 'close'])->name('companies.close');
        Route::post('companies/{company}/plan', [CompanyController::class, 'changePlan'])->name('companies.plan');
        Route::post('companies/{company}/impersonate/{user}', [CompanyController::class, 'impersonate'])->name('companies.impersonate');

        Route::get('admins', [AdminUserController::class, 'index'])->name('admins.index');
        Route::get('admins/create', [AdminUserController::class, 'create'])->name('admins.create');
        Route::post('admins', [AdminUserController::class, 'store'])->name('admins.store');
        Route::delete('admins/{admin}', [AdminUserController::class, 'destroy'])->name('admins.destroy');
    });
});
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

mkdir -p "resources/views/components/layouts"
cat > "resources/views/components/layouts/admin.blade.php" << 'PARALLELIUM_FILE_EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>{{ $title ?? 'Administration' }} — Parallelium</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.6.0/css/all.min.css" integrity="sha512-Kc323vGBEqzTmouAECnVceyQqyqdsSiqLQISBL29aUW4U/M7pSPA/gEUZQqv1cwx4OnYxTxve5UMg5GT6L4JJg==" crossorigin="anonymous" referrerpolicy="no-referrer">
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="min-h-screen bg-slate-50">
    <header class="border-b border-slate-100 bg-slate-950">
        <div class="mx-auto flex max-w-6xl items-center justify-between px-4 py-3 lg:px-8">
            <div class="flex items-center gap-6">
                <div class="flex items-center gap-2 text-sm font-extrabold text-white">
                    <span class="flex h-8 w-8 items-center justify-center rounded-full bg-brand-gradient text-sm"><x-icon name="logo" /></span>
                    Parallelium
                    <span class="ml-1 rounded-full bg-white/10 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-slate-300">Administration</span>
                </div>

                @auth('admin')
                    <nav class="hidden items-center gap-4 text-xs font-medium text-slate-300 sm:flex">
                        <a href="{{ route('admin.dashboard') }}" class="hover:text-white {{ request()->routeIs('admin.dashboard') ? 'text-white' : '' }}">Dashboard</a>
                        <a href="{{ route('admin.companies.index') }}" class="hover:text-white {{ request()->routeIs('admin.companies.*') ? 'text-white' : '' }}">Entreprises</a>
                        <a href="{{ route('admin.admins.index') }}" class="hover:text-white {{ request()->routeIs('admin.admins.*') ? 'text-white' : '' }}">Administrateurs</a>
                    </nav>
                @endauth
            </div>

            @auth('admin')
                <form method="POST" action="{{ route('admin.logout') }}">
                    @csrf
                    <button type="submit" class="text-xs font-medium text-slate-300 hover:text-white">Se déconnecter</button>
                </form>
            @endauth
        </div>
    </header>

    <main class="mx-auto max-w-6xl px-4 py-6 lg:px-8">
        @if (session('status'))
            <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
        @endif
        @if ($errors->any())
            <x-alert type="error" class="mb-4">{{ $errors->first() }}</x-alert>
        @endif

        {{ $slot }}
    </main>
</body>
</html>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/components"
cat > "resources/views/components/impersonation-banner.blade.php" << 'PARALLELIUM_FILE_EOF'
@if (session('impersonating_admin_id'))
    <div class="fixed inset-x-0 top-0 z-50 flex items-center justify-center gap-3 bg-amber-500 px-4 py-2 text-center text-xs font-semibold text-amber-950">
        <span>
            Support Parallelium : vous naviguez en tant que <strong>{{ auth()->user()->name }}</strong>
            ({{ session('impersonating_admin_name') }} est connecté en administrateur)
        </span>
        <form method="POST" action="{{ route('impersonation.stop') }}">
            @csrf
            <button type="submit" class="rounded-full bg-amber-950/10 px-3 py-1 hover:bg-amber-950/20">
                Revenir à l'administration
            </button>
        </form>
    </div>
@endif
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/components/layouts"
cat > "resources/views/components/layouts/app.blade.php" << 'PARALLELIUM_FILE_EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>{{ $title ?? 'Parallelium' }}</title>
    <x-pwa-head />
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="min-h-screen bg-slate-50 {{ session('impersonating_admin_id') ? 'pt-9' : '' }}" x-cloak>
    <x-impersonation-banner />

    <div class="flex min-h-screen">
        <x-app-sidebar />

        <div class="flex min-w-0 flex-1 flex-col">
            <x-app-header :title="$title ?? null" />

            <main class="flex-1 px-4 pb-28 pt-4 lg:px-8 lg:pb-8 lg:pt-6">
                @if (session('status'))
                    <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
                @endif

                {{ $slot }}
            </main>
        </div>
    </div>

    <x-app-bottom-nav />
    <x-quick-actions-sheet />
    <x-pwa-install-banner />
    <x-pwa-update-banner />
</body>
</html>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/admin"
cat > "resources/views/admin/dashboard.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.admin title="Dashboard">
    <div class="mb-5">
        <h1 class="text-xl font-bold text-slate-900">Vue d'ensemble</h1>
        <p class="text-sm text-slate-500">Toute la plateforme Parallelium, en un coup d'œil.</p>
    </div>

    <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <x-stat-card label="Entreprises" :value="$stats['companies']" icon="customers" />
        <x-stat-card label="Actives" :value="$stats['active_companies']" icon="success" />
        <x-stat-card label="Suspendues" :value="$stats['suspended_companies']" icon="warning" />
        <x-stat-card label="Utilisateurs (total)" :value="$stats['total_users']" icon="products" />
    </div>

    <div class="mt-3 grid grid-cols-2 gap-3">
        <x-stat-card label="MRR estimatif" :value="\App\Support\Money::format($mrr)" icon="money" tone="brand" />
        <x-stat-card label="Ventes ce mois (toutes entreprises)" :value="$stats['sales_this_month']" icon="sales" />
    </div>

    <p class="mt-2 text-xs text-slate-400">
        Le MRR est une estimation basée sur les abonnements actifs et leurs prix catalogue — aucun prélèvement réel n'est encore connecté (§32).
    </p>

    <div class="mt-6 grid gap-4 lg:grid-cols-3">
        <x-card class="lg:col-span-2">
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Inscriptions — 14 derniers jours</h3>
            @if ($signupsByDay->sum('count') > 0)
                <canvas id="chart-signups" height="180"></canvas>
            @else
                <p class="py-8 text-center text-sm text-slate-400">Aucune inscription récente.</p>
            @endif
        </x-card>

        <x-card>
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Répartition par plan</h3>
            <div class="space-y-2">
                @forelse ($planBreakdown as $plan => $count)
                    <div class="flex items-center justify-between text-sm">
                        <span class="text-slate-600">{{ $plans[$plan]['label'] ?? $plan }}</span>
                        <span class="font-semibold text-slate-800">{{ $count }}</span>
                    </div>
                @empty
                    <p class="text-sm text-slate-400">Aucun abonnement pour le moment.</p>
                @endforelse
            </div>
        </x-card>
    </div>

    <x-card class="mt-4">
        <h3 class="mb-3 text-sm font-semibold text-slate-700">Top 5 entreprises (CA ce mois)</h3>
        @if ($topCompanies->isEmpty() || $topCompanies->first()->month_revenue == 0)
            <p class="text-sm text-slate-400">Aucune vente enregistrée ce mois-ci.</p>
        @else
            <div class="divide-y divide-slate-100">
                @foreach ($topCompanies as $company)
                    @if ($company->month_revenue > 0)
                        <a href="{{ route('admin.companies.show', $company) }}" class="flex items-center justify-between py-2.5 text-sm hover:bg-slate-50">
                            <span class="font-medium text-slate-800">{{ $company->name }}</span>
                            <span class="font-semibold text-slate-900">{{ \App\Support\Money::format($company->month_revenue, $company->currency) }}</span>
                        </a>
                    @endif
                @endforeach
            </div>
        @endif
    </x-card>

    @if ($signupsByDay->sum('count') > 0)
        <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.4/chart.umd.min.js" integrity="sha512-e3nkTaqZ4qhAtI22fMPCH7ELiC4qhBQCiCTgKXWBTx6jHU0y3TKO5+ez+IEK9nnMx7DdMg0jZQBcwSj2Hn45Sw==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
        <script>
            document.addEventListener('DOMContentLoaded', () => {
                const data = @json($signupsByDay);
                new Chart(document.getElementById('chart-signups'), {
                    type: 'bar',
                    data: {
                        labels: data.map(d => d.label),
                        datasets: [{ data: data.map(d => d.count), backgroundColor: '#6a35c2', borderRadius: 6 }],
                    },
                    options: {
                        plugins: { legend: { display: false } },
                        scales: { y: { beginAtZero: true, ticks: { precision: 0 } } },
                    },
                });
            });
        </script>
    @endif
</x-layouts.admin>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/admin/admins"
cat > "resources/views/admin/admins/index.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.admin title="Administrateurs">
    <div class="mb-5 flex items-center justify-between">
        <div>
            <h1 class="text-xl font-bold text-slate-900">Administrateurs</h1>
            <p class="text-sm text-slate-500">Comptes ayant accès au panneau d'administration plateforme.</p>
        </div>
        <x-button :href="route('admin.admins.create')" size="sm"><x-icon name="plus" /> Ajouter</x-button>
    </div>

    <x-card :padded="false">
        <div class="divide-y divide-slate-100">
            @foreach ($admins as $admin)
                <div class="flex items-center justify-between px-5 py-3">
                    <div>
                        <p class="text-sm font-semibold text-slate-800">
                            {{ $admin->name }}
                            @if ($admin->id === auth('admin')->id())
                                <span class="text-xs font-normal text-slate-400">(vous)</span>
                            @endif
                        </p>
                        <p class="text-xs text-slate-400">{{ $admin->email }}</p>
                    </div>
                    @if ($admin->id !== auth('admin')->id())
                        <form method="POST" action="{{ route('admin.admins.destroy', $admin) }}" onsubmit="return confirm('Supprimer ce compte administrateur ?');">
                            @csrf
                            @method('DELETE')
                            <button type="submit" class="text-sm font-medium text-red-500 hover:underline">Supprimer</button>
                        </form>
                    @endif
                </div>
            @endforeach
        </div>
    </x-card>

    <div class="mt-5">{{ $admins->links() }}</div>
</x-layouts.admin>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/admin/admins"
cat > "resources/views/admin/admins/create.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.admin title="Nouvel administrateur">
    <div class="mb-5">
        <h1 class="text-xl font-bold text-slate-900">Nouvel administrateur</h1>
    </div>

    <x-card>
        <form method="POST" action="{{ route('admin.admins.store') }}" class="space-y-4">
            @csrf
            <div>
                <x-label for="name">Nom</x-label>
                <x-input id="name" name="name" value="{{ old('name') }}" required autofocus />
            </div>
            <div>
                <x-label for="email">Adresse e-mail</x-label>
                <x-input id="email" type="email" name="email" value="{{ old('email') }}" required />
            </div>
            <div>
                <x-label for="password">Mot de passe</x-label>
                <x-input id="password" type="password" name="password" required />
            </div>
            <div>
                <x-label for="password_confirmation">Confirmer le mot de passe</x-label>
                <x-input id="password_confirmation" type="password" name="password_confirmation" required />
            </div>
            <div class="flex items-center gap-3 pt-2">
                <x-button type="submit">Créer le compte</x-button>
                <x-button :href="route('admin.admins.index')" variant="ghost" type="button">Annuler</x-button>
            </div>
        </form>
    </x-card>
</x-layouts.admin>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/admin/companies"
cat > "resources/views/admin/companies/edit.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.admin title="Modifier {{ $company->name }}">
    <div class="mb-5">
        <a href="{{ route('admin.companies.show', $company) }}" class="text-xs font-medium text-brand-600 hover:underline">&larr; {{ $company->name }}</a>
        <h1 class="mt-1 text-xl font-bold text-slate-900">Modifier l'entreprise</h1>
    </div>

    <x-card>
        <form method="POST" action="{{ route('admin.companies.update', $company) }}" class="space-y-4">
            @csrf
            @method('PUT')

            <div>
                <x-label for="name">Nom</x-label>
                <x-input id="name" name="name" value="{{ old('name', $company->name) }}" required autofocus />
            </div>

            <div class="grid gap-4 sm:grid-cols-2">
                <div>
                    <x-label for="email">E-mail</x-label>
                    <x-input id="email" type="email" name="email" value="{{ old('email', $company->email) }}" />
                </div>
                <div>
                    <x-label for="phone">Téléphone</x-label>
                    <x-input id="phone" name="phone" value="{{ old('phone', $company->phone) }}" />
                </div>
                <div>
                    <x-label for="city">Ville</x-label>
                    <x-input id="city" name="city" value="{{ old('city', $company->city) }}" />
                </div>
                <div>
                    <x-label for="currency">Devise</x-label>
                    <select id="currency" name="currency" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400">
                        @foreach (config('parallelium.currencies') as $code => $c)
                            <option value="{{ $code }}" @selected(old('currency', $company->currency) === $code)>{{ $c['label'] }}</option>
                        @endforeach
                    </select>
                </div>
            </div>

            <div class="flex items-center gap-3 pt-2">
                <x-button type="submit">Enregistrer</x-button>
                <x-button :href="route('admin.companies.show', $company)" variant="ghost" type="button">Annuler</x-button>
            </div>
        </form>
    </x-card>
</x-layouts.admin>
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
                <div class="flex justify-between"><dt class="text-slate-400">Type d'activité</dt><dd class="text-slate-700">{{ $company->business_type ?? '—' }}</dd></div>
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

mkdir -p "tests/Feature/Admin"
cat > "tests/Feature/Admin/AdminControlTest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Tests\Feature\Admin;

use App\Models\Admin;
use App\Models\ActivityLog;
use App\Models\Company;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminControlTest extends TestCase
{
    use RefreshDatabase;

    protected function ownerFor(Company $company): User
    {
        $role = Role::firstOrCreate(
            ['company_id' => null, 'slug' => 'owner'],
            ['name' => 'Propriétaire', 'is_system' => true]
        );

        return User::factory()->create(['company_id' => $company->id, 'role_id' => $role->id, 'is_active' => true]);
    }

    public function test_admin_dashboard_shows_platform_wide_stats(): void
    {
        $admin = Admin::factory()->create();
        Company::factory()->count(3)->create(['status' => 'active']);

        $this->actingAs($admin, 'admin')
            ->get(route('admin.dashboard'))
            ->assertOk()
            ->assertSee('Vue d\'ensemble');
    }

    public function test_admin_can_create_and_delete_another_admin(): void
    {
        $admin = Admin::factory()->create();

        $this->actingAs($admin, 'admin')->post(route('admin.admins.store'), [
            'name' => 'Second Admin',
            'email' => 'second@parallelium.app',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ])->assertRedirect(route('admin.admins.index'));

        $second = Admin::where('email', 'second@parallelium.app')->first();
        $this->assertNotNull($second);

        $this->actingAs($admin, 'admin')
            ->delete(route('admin.admins.destroy', $second))
            ->assertRedirect();

        $this->assertNull(Admin::find($second->id));
    }

    public function test_admin_cannot_delete_their_own_account(): void
    {
        $admin = Admin::factory()->create();
        Admin::factory()->create(); // pour ne pas être le dernier compte

        $this->actingAs($admin, 'admin')
            ->delete(route('admin.admins.destroy', $admin))
            ->assertSessionHasErrors('admin');

        $this->assertNotNull(Admin::find($admin->id));
    }

    public function test_admin_cannot_delete_the_last_remaining_admin(): void
    {
        $admin = Admin::factory()->create();
        $other = Admin::factory()->create();

        // Supprime tous les autres pour ne laisser que $other, tenté seul.
        Admin::where('id', '!=', $other->id)->delete();

        $this->actingAs($other, 'admin')
            ->delete(route('admin.admins.destroy', $other))
            ->assertSessionHasErrors('admin');
    }

    public function test_admin_can_edit_a_company(): void
    {
        $admin = Admin::factory()->create();
        $company = Company::factory()->create(['name' => 'Ancien nom']);

        $this->actingAs($admin, 'admin')->put(route('admin.companies.update', $company), [
            'name' => 'Nouveau nom',
            'currency' => 'MGA',
        ])->assertRedirect(route('admin.companies.show', $company));

        $this->assertEquals('Nouveau nom', $company->fresh()->name);
    }

    public function test_admin_can_close_a_company_permanently(): void
    {
        $admin = Admin::factory()->create();
        $company = Company::factory()->create(['status' => 'active']);

        $this->actingAs($admin, 'admin')
            ->post(route('admin.companies.close', $company))
            ->assertRedirect();

        $this->assertEquals('closed', $company->fresh()->status);
    }

    public function test_admin_can_impersonate_a_company_user_and_stop(): void
    {
        $admin = Admin::factory()->create();
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);

        $this->actingAs($admin, 'admin')
            ->post(route('admin.companies.impersonate', [$company, $owner]))
            ->assertRedirect(route('dashboard'));

        $this->assertAuthenticatedAs($owner, 'web');
        // La session admin reste valide en parallèle.
        $this->assertAuthenticatedAs($admin, 'admin');

        $this->assertDatabaseHas('activity_logs', [
            'company_id' => $company->id,
            'action' => 'admin.impersonation_started',
        ]);

        $this->post(route('impersonation.stop'))
            ->assertRedirect(route('admin.companies.show', $company));

        $this->assertGuest('web');
        // Toujours connecté côté admin après l'arrêt de l'impersonation.
        $this->assertAuthenticatedAs($admin, 'admin');
    }

    public function test_admin_cannot_impersonate_a_user_from_a_different_company(): void
    {
        $admin = Admin::factory()->create();
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();
        $ownerB = $this->ownerFor($companyB);

        $this->actingAs($admin, 'admin')
            ->post(route('admin.companies.impersonate', [$companyA, $ownerB]))
            ->assertNotFound();
    }
}
PARALLELIUM_FILE_EOF

echo "Termine. Lance maintenant : php artisan view:clear"
echo "Pas de nouvelle migration necessaire (ActivityLog existait deja)."
