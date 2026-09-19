#!/usr/bin/env bash
#
# Parallelium - Panneau admin plateforme (guard separe)
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
# Compatible Git Bash / WSL sous Windows.
set -e
echo "Application des fichiers du panneau admin..."

mkdir -p "config"
cat > "config/auth.php" << 'PARALLELIUM_FILE_EOF'
<?php

use App\Models\Admin;
use App\Models\User;

return [

    /*
    |--------------------------------------------------------------------------
    | Authentication Defaults
    |--------------------------------------------------------------------------
    |
    | This option defines the default authentication "guard" and password
    | reset "broker" for your application. You may change these values
    | as required, but they're a perfect start for most applications.
    |
    */

    'defaults' => [
        'guard' => env('AUTH_GUARD', 'web'),
        'passwords' => env('AUTH_PASSWORD_BROKER', 'users'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Authentication Guards
    |--------------------------------------------------------------------------
    |
    | Next, you may define every authentication guard for your application.
    | Of course, a great default configuration has been defined for you
    | which utilizes session storage plus the Eloquent user provider.
    |
    | All authentication guards have a user provider, which defines how the
    | users are actually retrieved out of your database or other storage
    | system used by the application. Typically, Eloquent is utilized.
    |
    | Supported: "session"
    |
    */

    'guards' => [
        'web' => [
            'driver' => 'session',
            'provider' => 'users',
        ],

        // Guard totalement séparé du guard "web" (entreprises) : un compte
        // admin plateforme n'est JAMAIS un User de compagnie, et
        // inversement. Deux sessions, deux tables, deux pages de
        // connexion distinctes — aucune passerelle possible entre les deux.
        'admin' => [
            'driver' => 'session',
            'provider' => 'admins',
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | User Providers
    |--------------------------------------------------------------------------
    |
    | All authentication guards have a user provider, which defines how the
    | users are actually retrieved out of your database or other storage
    | system used by the application. Typically, Eloquent is utilized.
    |
    | If you have multiple user tables or models you may configure multiple
    | providers to represent the model / table. These providers may then
    | be assigned to any extra authentication guards you have defined.
    |
    | Supported: "database", "eloquent"
    |
    */

    'providers' => [
        'users' => [
            'driver' => 'eloquent',
            'model' => env('AUTH_MODEL', User::class),
        ],

        'admins' => [
            'driver' => 'eloquent',
            'model' => Admin::class,
        ],

        // 'users' => [
        //     'driver' => 'database',
        //     'table' => 'users',
        // ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Resetting Passwords
    |--------------------------------------------------------------------------
    |
    | These configuration options specify the behavior of Laravel's password
    | reset functionality, including the table utilized for token storage
    | and the user provider that is invoked to actually retrieve users.
    |
    | The expiry time is the number of minutes that each reset token will be
    | considered valid. This security feature keeps tokens short-lived so
    | they have less time to be guessed. You may change this as needed.
    |
    | The throttle setting is the number of seconds a user must wait before
    | generating more password reset tokens. This prevents the user from
    | quickly generating a very large amount of password reset tokens.
    |
    */

    'passwords' => [
        'users' => [
            'provider' => 'users',
            'table' => env('AUTH_PASSWORD_RESET_TOKEN_TABLE', 'password_reset_tokens'),
            'expire' => 60,
            'throttle' => 60,
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Password Confirmation Timeout
    |--------------------------------------------------------------------------
    |
    | Here you may define the number of seconds before a password confirmation
    | window expires and users are asked to re-enter their password via the
    | confirmation screen. By default, the timeout lasts for three hours.
    |
    */

    'password_timeout' => env('AUTH_PASSWORD_TIMEOUT', 10800),

];
PARALLELIUM_FILE_EOF

mkdir -p "bootstrap"
cat > "bootstrap/app.php" << 'PARALLELIUM_FILE_EOF'
<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
        then: function () {
            // Groupe "web" (session, cookies, CSRF, en-têtes de sécurité)
            // appliqué, mais SANS les middlewares tenant (onboarding,
            // EnsureCompanyIsActive ne s'applique qu'aux sessions du
            // guard "web" par entreprise — no-op ici, voir routes/admin.php).
            \Illuminate\Support\Facades\Route::middleware('web')
                ->group(__DIR__.'/../routes/admin.php');
        },
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'tenant.active' => \App\Http\Middleware\EnsureCompanyIsActive::class,
            'onboarding' => \App\Http\Middleware\RedirectIfOnboardingIncomplete::class,
        ]);

        $middleware->appendToGroup('web', [
            \App\Http\Middleware\EnsureCompanyIsActive::class,
            \App\Http\Middleware\SecurityHeaders::class,
        ]);

        // Un visiteur non connecté sur /admin/* doit atterrir sur la page
        // de connexion ADMIN, jamais sur celle des entreprises (et
        // inversement) — les deux guards ne doivent jamais se mélanger.
        $middleware->redirectGuestsTo(fn (Request $request) => $request->is('admin/*')
            ? route('admin.login')
            : route('login'));

        // Symétriquement : un admin déjà connecté qui rouvre /admin/login
        // repart vers la liste des entreprises, pas vers le dashboard tenant.
        $middleware->redirectUsersTo(fn (Request $request) => $request->is('admin/*')
            ? route('admin.companies.index')
            : route('dashboard'));
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );
    })->create();
PARALLELIUM_FILE_EOF

mkdir -p "database/migrations"
cat > "database/migrations/2026_01_07_000001_create_admins_table.php" << 'PARALLELIUM_FILE_EOF'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Table volontairement séparée de "users" : un administrateur
        // plateforme n'appartient à AUCUNE entreprise (pas de company_id)
        // et ne doit jamais pouvoir se confondre avec un compte tenant.
        Schema::create('admins', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('email')->unique();
            $table->timestamp('email_verified_at')->nullable();
            $table->string('password');
            $table->rememberToken();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admins');
    }
};
PARALLELIUM_FILE_EOF

mkdir -p "app/Models"
cat > "app/Models/Admin.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

/**
 * Administrateur PLATEFORME (l'éditeur de Parallelium), distinct des
 * utilisateurs d'entreprise (App\Models\User). Authentifié via le guard
 * "admin" (voir config/auth.php) — jamais mélangé avec le guard "web".
 */
class Admin extends Authenticatable
{
    use Notifiable;

    protected $fillable = ['name', 'email', 'password'];

    protected $hidden = ['password', 'remember_token'];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Models"
cat > "app/Models/Company.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;

class Company extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'name',
        'legal_name',
        'logo',
        'email',
        'phone',
        'address',
        'city',
        'country',
        'currency',
        'timezone',
        'business_type',
        'tax_identifier',
        'invoice_prefix',
        'onboarding_completed',
        'status',
    ];

    protected function casts(): array
    {
        return [
            'onboarding_completed' => 'boolean',
        ];
    }

    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }

    public function subscription(): HasOne
    {
        return $this->hasOne(Subscription::class);
    }

    public function activityLogs(): HasMany
    {
        return $this->hasMany(ActivityLog::class);
    }

    // Relations utilisées par le panneau admin plateforme (statistiques
    // par entreprise) — voir App\Http\Controllers\Admin\CompanyController.
    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }

    public function customers(): HasMany
    {
        return $this->hasMany(Customer::class);
    }

    public function sales(): HasMany
    {
        return $this->hasMany(Sale::class);
    }

    /**
     * Devise formatée selon config('parallelium.currencies').
     * Ne jamais coder le symbole "Ar" en dur dans les vues : utiliser
     * $company->currencySymbol() ou le helper App\Support\Money.
     */
    public function currencySymbol(): string
    {
        return config("parallelium.currencies.{$this->currency}.symbol", $this->currency);
    }

    /**
     * Numéro de document suivant (facture, vente, dépense), unique par
     * entreprise. Incrémente atomiquement le compteur correspondant.
     */
    public function nextDocumentNumber(string $type): string
    {
        $column = "next_{$type}_number";
        $prefixKey = $type === 'invoice' ? $this->invoice_prefix : config("parallelium.document_prefixes.{$type}");

        $number = $this->{$column};

        $this->increment($column);

        return sprintf('%s-%s-%06d', $prefixKey, now()->format('Y'), $number);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers/Admin"
cat > "app/Http/Controllers/Admin/AuthController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Auth\Events\Lockout;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function create()
    {
        return view('admin.auth.login');
    }

    public function store(Request $request)
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $key = Str::transliterate(Str::lower($credentials['email']).'|'.$request->ip());

        if (RateLimiter::tooManyAttempts($key, 5)) {
            event(new Lockout($request));
            $seconds = RateLimiter::availableIn($key);

            throw ValidationException::withMessages([
                'email' => "Trop de tentatives. Réessayez dans {$seconds} secondes.",
            ]);
        }

        if (! Auth::guard('admin')->attempt($credentials, $request->boolean('remember'))) {
            RateLimiter::hit($key);

            throw ValidationException::withMessages([
                'email' => 'Ces identifiants ne correspondent à aucun compte administrateur.',
            ]);
        }

        RateLimiter::clear($key);
        $request->session()->regenerate();

        return redirect()->route('admin.companies.index');
    }

    public function destroy(Request $request)
    {
        Auth::guard('admin')->logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('admin.login');
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers/Admin"
cat > "app/Http/Controllers/Admin/CompanyController.php" << 'PARALLELIUM_FILE_EOF'
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
PARALLELIUM_FILE_EOF

mkdir -p "routes"
cat > "routes/admin.php" << 'PARALLELIUM_FILE_EOF'
<?php

use App\Http\Controllers\Admin\AuthController;
use App\Http\Controllers\Admin\CompanyController;
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

        Route::redirect('/', '/admin/companies');

        Route::get('companies', [CompanyController::class, 'index'])->name('companies.index');
        Route::get('companies/{company}', [CompanyController::class, 'show'])->name('companies.show');
        Route::post('companies/{company}/suspend', [CompanyController::class, 'suspend'])->name('companies.suspend');
        Route::post('companies/{company}/activate', [CompanyController::class, 'activate'])->name('companies.activate');
        Route::post('companies/{company}/plan', [CompanyController::class, 'changePlan'])->name('companies.plan');
    });
});
PARALLELIUM_FILE_EOF

mkdir -p "database/seeders"
cat > "database/seeders/AdminSeeder.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Database\Seeders;

use App\Models\Admin;
use Illuminate\Database\Seeder;

class AdminSeeder extends Seeder
{
    public function run(): void
    {
        Admin::updateOrCreate(
            ['email' => 'admin@parallelium.app'],
            [
                'name' => 'Administrateur Parallelium',
                'password' => 'password',
            ]
        );
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "database/seeders"
cat > "database/seeders/DatabaseSeeder.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            PermissionSeeder::class,
            RoleSeeder::class,
            DemoCompanySeeder::class,
            AdminSeeder::class,
        ]);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "database/factories"
cat > "database/factories/AdminFactory.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Database\Factories;

use App\Models\Admin;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;

/**
 * @extends Factory<Admin>
 */
class AdminFactory extends Factory
{
    protected $model = Admin::class;

    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'password' => Hash::make('password'),
        ];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "tests/Feature/Admin"
cat > "tests/Feature/Admin/AdminPanelTest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Tests\Feature\Admin;

use App\Models\Admin;
use App\Models\Company;
use App\Models\Role;
use App\Models\Subscription;
use App\Models\User;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Le panneau admin plateforme est un système d'authentification à part
 * entière (guard "admin"), totalement étanche au guard "web" (comptes
 * d'entreprise). Ces tests vérifient explicitement cette étanchéité dans
 * les deux sens.
 */
class AdminPanelTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([PermissionSeeder::class, RoleSeeder::class]);
    }

    public function test_an_admin_can_log_in_and_list_companies(): void
    {
        $admin = Admin::factory()->create(['password' => 'password123']);
        Company::factory()->count(3)->create();

        $this->post(route('admin.login'), [
            'email' => $admin->email,
            'password' => 'password123',
        ])->assertRedirect(route('admin.companies.index'));

        $this->assertAuthenticatedAs($admin, 'admin');

        $this->actingAs($admin, 'admin')
            ->get(route('admin.companies.index'))
            ->assertOk();
    }

    public function test_a_company_owner_cannot_access_the_admin_panel(): void
    {
        $company = Company::factory()->create();
        $role = Role::whereNull('company_id')->where('slug', 'owner')->first();
        $owner = User::factory()->create(['company_id' => $company->id, 'role_id' => $role->id]);

        // Authentifié sur le guard "web" (entreprise), jamais sur "admin".
        $this->actingAs($owner)
            ->get(route('admin.companies.index'))
            ->assertRedirect(route('admin.login'));
    }

    public function test_an_admin_cannot_access_tenant_routes(): void
    {
        $admin = Admin::factory()->create();

        // Authentifié sur le guard "admin", jamais sur "web" : le
        // dashboard d'entreprise doit rester inaccessible.
        $this->actingAs($admin, 'admin')
            ->get(route('dashboard'))
            ->assertRedirect(route('login'));
    }

    public function test_admin_can_suspend_a_company_and_its_owner_gets_logged_out(): void
    {
        $admin = Admin::factory()->create();
        $company = Company::factory()->create(['status' => 'active']);
        $role = Role::whereNull('company_id')->where('slug', 'owner')->first();
        $owner = User::factory()->create(['company_id' => $company->id, 'role_id' => $role->id]);

        $this->actingAs($admin, 'admin')
            ->post(route('admin.companies.suspend', $company))
            ->assertRedirect();

        $this->assertEquals('suspended', $company->fresh()->status);

        // Le propriétaire, déjà connecté, est bloqué dès sa prochaine requête.
        $this->actingAs($owner)
            ->get(route('dashboard'))
            ->assertRedirect(route('login'));
    }

    public function test_admin_can_change_a_companys_plan(): void
    {
        $admin = Admin::factory()->create();
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'free', 'status' => 'active']);

        $this->actingAs($admin, 'admin')
            ->post(route('admin.companies.plan', $company), ['plan' => 'business'])
            ->assertRedirect();

        $this->assertEquals('business', $company->subscription->fresh()->plan);
    }
}
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
            <div class="flex items-center gap-2 text-sm font-extrabold text-white">
                <span class="flex h-8 w-8 items-center justify-center rounded-full bg-brand-gradient text-sm"><x-icon name="logo" /></span>
                Parallelium
                <span class="ml-1 rounded-full bg-white/10 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-slate-300">Administration</span>
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

mkdir -p "resources/views/admin/auth"
cat > "resources/views/admin/auth/login.blade.php" << 'PARALLELIUM_FILE_EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>Administration — Parallelium</title>
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="flex min-h-screen items-center justify-center bg-slate-950 px-4">
    <div class="w-full max-w-sm rounded-3xl bg-white p-8 shadow-2xl">
        <div class="mb-6 flex items-center gap-2 text-base font-extrabold text-brand-800">
            <span class="flex h-8 w-8 items-center justify-center rounded-full bg-brand-gradient text-sm text-white"><x-icon name="logo" /></span>
            Parallelium
            <span class="ml-1 rounded-full bg-slate-100 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-slate-500">Administration</span>
        </div>

        @if ($errors->any())
            <x-alert type="error" class="mb-4">{{ $errors->first() }}</x-alert>
        @endif

        <form method="POST" action="{{ route('admin.login') }}" class="space-y-4">
            @csrf

            <div>
                <x-label for="email">Adresse e-mail</x-label>
                <x-input id="email" type="email" name="email" value="{{ old('email') }}" required autofocus />
            </div>

            <div>
                <x-label for="password">Mot de passe</x-label>
                <x-input id="password" type="password" name="password" required />
            </div>

            <x-button type="submit" class="w-full justify-center" size="lg">Se connecter</x-button>
        </form>

        <p class="mt-6 text-center text-xs text-slate-400">
            Réservé aux administrateurs de la plateforme Parallelium.
        </p>
    </div>
</body>
</html>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/admin/companies"
cat > "resources/views/admin/companies/index.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.admin title="Entreprises">
    <div class="mb-5">
        <h1 class="text-xl font-bold text-slate-900">Entreprises</h1>
        <p class="text-sm text-slate-500">Toutes les entreprises inscrites sur Parallelium.</p>
    </div>

    <div class="mb-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <x-stat-card label="Entreprises" :value="$stats['total']" icon="customers" />
        <x-stat-card label="Actives" :value="$stats['active']" icon="success" />
        <x-stat-card label="Suspendues" :value="$stats['suspended']" icon="warning" />
        <x-stat-card label="Sur un plan payant" :value="$stats['paying']" icon="money" tone="brand" />
    </div>

    <form method="GET" class="mb-4 flex flex-wrap items-center gap-2">
        <x-input name="q" value="{{ request('q') }}" placeholder="Rechercher une entreprise..." class="max-w-xs" />
        <select name="status" class="rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400" onchange="this.form.submit()">
            <option value="">Tous les statuts</option>
            <option value="active" @selected(request('status') === 'active')>Active</option>
            <option value="suspended" @selected(request('status') === 'suspended')>Suspendue</option>
            <option value="closed" @selected(request('status') === 'closed')>Fermée</option>
        </select>
        <x-button type="submit" variant="ghost" size="sm">Filtrer</x-button>
    </form>

    @if ($companies->isEmpty())
        <x-empty-state icon="customers" title="Aucune entreprise trouvée." />
    @else
        <x-card :padded="false">
            <div class="divide-y divide-slate-100">
                @foreach ($companies as $company)
                    <a href="{{ route('admin.companies.show', $company) }}" class="flex items-center justify-between gap-3 px-5 py-3 hover:bg-slate-50">
                        <div class="min-w-0">
                            <p class="truncate text-sm font-semibold text-slate-800">
                                {{ $company->name }}
                                @if ($company->status !== 'active')
                                    <x-badge tone="danger" class="ml-1">{{ ucfirst($company->status) }}</x-badge>
                                @endif
                            </p>
                            <p class="text-xs text-slate-400">
                                {{ $company->users_count }} utilisateur{{ $company->users_count > 1 ? 's' : '' }} ·
                                {{ $company->products_count }} produits ·
                                {{ $company->customers_count }} clients
                            </p>
                        </div>
                        <x-badge tone="brand">{{ $plans[$company->subscription?->plan]['label'] ?? $company->subscription?->plan ?? '—' }}</x-badge>
                    </a>
                @endforeach
            </div>
        </x-card>

        <div class="mt-5">{{ $companies->links() }}</div>
    @endif
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

    <x-card class="mt-4">
        <h3 class="mb-3 text-sm font-semibold text-slate-700">Utilisateurs</h3>
        <div class="divide-y divide-slate-100">
            @foreach ($company->users as $user)
                <div class="flex items-center justify-between py-2 text-sm">
                    <div>
                        <p class="font-medium text-slate-800">{{ $user->name }}</p>
                        <p class="text-xs text-slate-400">{{ $user->email }}</p>
                    </div>
                    <div class="text-right">
                        <x-badge tone="brand">{{ $user->role?->name ?? '—' }}</x-badge>
                        @unless ($user->is_active)
                            <x-badge tone="danger">Inactif</x-badge>
                        @endunless
                    </div>
                </div>
            @endforeach
        </div>
    </x-card>
</x-layouts.admin>
PARALLELIUM_FILE_EOF

cat > "README.md" << 'PARALLELIUM_FILE_EOF'
# Parallelium

SaaS de gestion pour petites entreprises — ventes, stock, clients, dépenses,
factures et rapports, depuis un seul endroit, pensé mobile-first.

> Marché initial : petites entreprises malgaches (devise par défaut : Ariary / MGA).

---

## Sommaire

- [Stack technique](#stack-technique)
- [Prérequis](#prérequis)
- [Installation (Windows / XAMPP)](#installation-windows--xampp)
- [Configuration .env](#configuration-env)
- [Base de données](#base-de-données)
- [Lancement en local](#lancement-en-local)
- [Comptes de démonstration](#comptes-de-démonstration)
- [Administration plateforme](#administration-plateforme)
- [Tests](#tests)
- [Build production](#build-production)
- [PWA](#pwa)
- [Structure du projet](#structure-du-projet)
- [État d'avancement](#état-davancement)
- [Sécurité](#sécurité)

---

## Stack technique

| Domaine | Choix |
|---|---|
| Backend | PHP 8.3+ (compatible 8.4), Laravel 12 |
| Base de données | MySQL / MariaDB |
| Templates | Blade |
| Interactivité | Alpine.js |
| CSS | Tailwind CSS v4 (via `@tailwindcss/vite`) |
| Build | Vite |
| PWA | Web App Manifest + Service Worker |

Architecture : `Controller -> Form Request -> Service -> Model -> Database`.
Isolation multi-tenant stricte via `company_id` (voir `app/Support/Tenant.php`
et `app/Models/Concerns/BelongsToCompany.php`).

---

## Prérequis

- **XAMPP** (Apache + MySQL + PHP 8.3 ou plus récent) — apachefriends.org
- **Composer** — getcomposer.org
- **Node.js 20+** et npm — nodejs.org
- **Git** (optionnel mais recommandé)

Ce projet est développé et testé pour un environnement **Windows + XAMPP**.
Toutes les commandes ci-dessous fonctionnent dans PowerShell ou l'invite de
commandes Windows.

---

## Installation (Windows / XAMPP)

1. Copiez le dossier du projet dans `C:\xampp\htdocs\parallelium`
   (ou n'importe quel dossier — `php artisan serve` ne nécessite pas
   d'être sous `htdocs`).

2. Ouvrez le **panneau de contrôle XAMPP** et démarrez **Apache** et **MySQL**.

3. Installez les dépendances PHP :

   ```
   composer install
   ```

4. Installez les dépendances front-end :

   ```
   npm install
   ```

5. Copiez le fichier d'environnement :

   ```
   copy .env.example .env
   ```

6. Générez la clé d'application :

   ```
   php artisan key:generate
   ```

---

## Configuration .env

Ouvrez `http://localhost/phpmyadmin` et créez une base de données nommée
`parallelium` (utf8mb4_unicode_ci).

Dans le fichier `.env`, vérifiez/ajustez :

```
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=parallelium
DB_USERNAME=root
DB_PASSWORD=
```

(Ce sont les identifiants par défaut de XAMPP — root sans mot de passe.)

---

## Base de données

```
php artisan migrate
php artisan db:seed
```

`db:seed` crée :

- les **permissions** et **rôles système** (owner, manager, seller, accountant) ;
- une entreprise de démonstration **"Parallelium Demo"** avec 3 utilisateurs.

---

## Lancement en local

Dans deux terminaux séparés :

```
php artisan serve
```

```
npm run dev
```

Puis ouvrez **http://localhost:8000**.

---

## Comptes de démonstration

| Rôle | E-mail | Mot de passe |
|---|---|---|
| Propriétaire | owner@parallelium.demo | password |
| Manager | manager@parallelium.demo | password |
| Vendeur | seller@parallelium.demo | password |

---

## Administration plateforme

Un panneau **admin plateforme** (l'éditeur de Parallelium), distinct des
comptes d'entreprise, permet de voir toutes les entreprises inscrites, les
suspendre/réactiver, et changer leur plan manuellement.

- URL : **`/admin/login`**
- Compte créé par le seeder : `admin@parallelium.app` / `password`
- Authentification **totalement séparée** (guard `admin`, table `admins`) :
  un compte d'entreprise ne peut jamais accéder à `/admin/*`, et
  inversement (voir `tests/Feature/Admin/AdminPanelTest.php`).

⚠️ **Change le mot de passe de ce compte avant toute mise en ligne
publique** — modifie-le directement en base ou via `php artisan tinker` :

```
php artisan tinker
>>> \App\Models\Admin::first()->update(['password' => 'un-mot-de-passe-fort']);
```

---

## Tests

```
php artisan test
```

Les tests couvrent en priorité l'inscription et **l'isolation multi-tenant**
(garantie la plus critique du produit) — voir `tests/Feature/`.

---

## Build production

```
npm run build
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

---

## PWA

Parallelium est installable :

- Sur mobile (Chrome/Safari) : menu du navigateur -> "Ajouter à l'écran d'accueil".
- Sur desktop (Chrome/Edge) : icône d'installation dans la barre d'adresse.

Le service worker (`public/sw.js`) met en cache l'app shell (icônes, manifest)
pour un démarrage plus rapide. **L'application ne fonctionne pas hors ligne** :
toute la logique métier (ventes, stock, paiements) nécessite le serveur.
L'offline complet est prévu pour une version future.

---

## Structure du projet

```
app/
  Http/
    Controllers/        Contrôleurs légers (délèguent aux Services)
    Controllers/Auth/   Inscription, connexion, mot de passe
    Requests/           Validation (Form Requests)
    Middleware/         EnsureCompanyIsActive, RedirectIfOnboardingIncomplete
  Models/
    Concerns/           BelongsToCompany (isolation multi-tenant)
  Services/             Logique métier (RegistrationService, ...)
  Support/              Tenant (contexte entreprise courante), Money (formatage devise)
config/
  parallelium.php       Devise, préfixes de numérotation, plans d'abonnement
database/
  migrations/
  seeders/
resources/
  css/app.css           Design tokens de marque (dégradé, couleurs, police)
  views/
    components/         Design system (Button, Card, Input, Badge, EmptyState, StatCard...)
    layouts/             guest (auth), app (sidebar + bottom nav), onboarding
    auth/
    onboarding/
routes/
  web.php
tests/
  Feature/
public/
  manifest.json, sw.js, icons/
```

---

## État d'avancement

Développement mené **phase par phase** (voir le cahier des charges complet
fourni en amont). Ne jamais passer à la phase suivante avec des erreurs connues.

- [x] **Phase 1 — Infrastructure** : Laravel, MySQL, Tailwind, Alpine, auth,
      layout desktop/mobile, design system, multi-tenant, rôles/permissions,
      onboarding, PWA (manifest + service worker), seeders, tests d'isolation.
- [x] **Phase 2 — Produits, catégories, stock** : StockService (mouvements
      tracés), ProductService, alertes de stock faible.
- [x] **Phase 3 — Clients** : fiche client, recherche, limite de crédit.
- [x] **Phase 4 — Ventes** : panier, SaleService transactionnel, paiement
      partiel/crédit, annulation avec restauration de stock.
- [x] **Phase 5 — Dépenses** : catégories fixes, justificatif sécurisé
      (type MIME, taille, nom de fichier généré).
- [x] **Phase 6 — Facturation** : génération depuis une vente, PDF
      (barryvdh/laravel-dompdf), numérotation par entreprise.
- [x] **Phase 7 — Dashboard** : DashboardService, tendances de période,
      4 graphiques (CA 7 jours, ventes/catégorie, dépenses/catégorie, top
      produits).
- [x] **Phase 8 — Employés** : invitation par e-mail, rôles, limite de plan.
- [x] **Phase 9 — Rapports** : ventes/dépenses/produits/clients, filtres
      de période, export CSV et PDF.
- [x] **Phase 10 — Abonnements** : SubscriptionService centralisé, page
      Paramètres/tarification (Free / Starter 15 000 Ar / Business 45 000 Ar).
- [x] **Phase 11 — PWA avancée** : page hors-ligne honnête, bannière
      d'installation (Android + iOS), détection de mise à jour, shortcuts.
- [x] **Phase 12 — Tests, sécurité, optimisation, polish** : voir
      [Sécurité](#sécurité) ci-dessous.

**Non prévu pour la V1** (voir §5 du cahier des charges) : comptabilité
complète, fiscalité, paie, RH avancée, CRM avancé, marketplace, apps
natives, IA avancée. L'architecture (multi-tenant, services, logs
d'activité) est conçue pour permettre leur ajout ultérieur sans réécriture.

---

## Sécurité

Ce qui est couvert dès la V1 (cahier des charges §33) :

- **Isolation multi-tenant** : scope Eloquent automatique sur toutes les
  ressources métier (`BelongsToCompany`), y compris via le model binding
  implicite de route — accéder à la ressource d'une autre entreprise par
  son ID renvoie une 404, jamais une fuite de données. Exception notable :
  `User` n'a **jamais** ce scope automatique (il provoquerait une boucle
  infinie à la connexion, voir le commentaire dans `app/Models/User.php`) ;
  son isolation est assurée manuellement dans `EmployeeController`.
- **CSRF** : jeton sur tous les formulaires (protection Laravel par défaut).
- **Authentification** : mots de passe hachés (bcrypt), limitation du taux
  de tentatives sur la connexion (5/minute) et sur l'inscription /
  réinitialisation de mot de passe (6/minute).
- **Autorisation** : chaque action passe par une permission (`$this->
  authorize('sales.create')`), jamais par une vérification de rôle codée
  en dur dans une vue.
- **Validation serveur systématique** : tous les montants (sous-total,
  remise, total, paiement) sont **recalculés côté serveur** à partir des
  prix en base, jamais acceptés tels quels depuis le navigateur (§49).
- **Uploads** : type MIME et taille strictement limités (justificatifs de
  dépense), nom de fichier généré par Laravel — jamais le nom original.
- **Mass assignment** : chaque écriture passe par un Form Request avec une
  liste explicite de champs validés ; un champ comme `company_id` n'est
  jamais dans cette liste, donc jamais modifiable depuis le formulaire.
- **En-têtes HTTP** : `X-Frame-Options`, `X-Content-Type-Options`,
  `Referrer-Policy`, `Permissions-Policy` sur toutes les réponses
  (`App\Http\Middleware\SecurityHeaders`).
- **Erreurs** : pages 404/403/419/500/503 personnalisées, aucune trace
  technique affichée à l'utilisateur (à condition que `APP_DEBUG=false`
  en production — voir plus bas).

**Avant une mise en production**, en plus des points ci-dessus :

- `.env` : `APP_ENV=production`, `APP_DEBUG=false`, `APP_KEY` généré.
- HTTPS obligatoire (cookies de session sécurisés).
- Sauvegardes régulières de la base MySQL.
- `php artisan config:cache && php artisan route:cache && php artisan view:cache`.
PARALLELIUM_FILE_EOF

echo "Termine. Lance maintenant :"
echo "  php artisan migrate"
echo "  php artisan db:seed --class=Database\\Seeders\\AdminSeeder"
echo "  php artisan view:clear"
echo "Puis va sur /admin/login (admin@parallelium.app / password)"
