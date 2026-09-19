#!/usr/bin/env bash
#
# Parallelium - Phase 8 (Employes)
# Contient aussi un correctif CRITIQUE : app/Models/User.php n'avait
# jamais le scope multi-tenant depuis la Phase 1 (une entreprise pouvait
# voir les utilisateurs des autres entreprises dans certaines requetes).
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
# Compatible Git Bash / WSL sous Windows.
set -e
echo "Application des fichiers Phase 8..."

mkdir -p "app/Models"
cat > "app/Models/User.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable
{
    // BelongsToCompany applique le scope tenant automatiquement dès qu'un
    // utilisateur est authentifié (Tenant::check()). Avant l'authentification
    // (connexion, inscription, réinitialisation de mot de passe), Tenant::check()
    // est faux et le scope ne s'applique pas : la recherche par e-mail reste
    // globale, comme il se doit pour ces flux.
    use BelongsToCompany, HasFactory, Notifiable, SoftDeletes;

    protected $fillable = [
        'company_id',
        'role_id',
        'name',
        'email',
        'phone',
        'avatar',
        'password',
        'is_active',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'last_login_at' => 'datetime',
            'password' => 'hashed',
            'is_active' => 'boolean',
        ];
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function role(): BelongsTo
    {
        return $this->belongsTo(Role::class);
    }

    /**
     * Vérifie si l'utilisateur possède une permission donnée, via son rôle.
     * Source de vérité utilisée par les Gates (voir AuthServiceProvider).
     */
    public function hasPermission(string $slug): bool
    {
        if (! $this->role) {
            return false;
        }

        return $this->role->permissions()
            ->where('slug', $slug)
            ->exists();
    }

    public function isOwner(): bool
    {
        return $this->role?->slug === 'owner';
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Requests"
cat > "app/Http/Requests/InviteEmployeeRequest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Requests;

use App\Support\Tenant;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class InviteEmployeeRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('employees.manage');
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['nullable', 'string', 'max:30'],
            // Le rôle "owner" n'est jamais assignable depuis ce formulaire
            // (réservé au flux d'inscription) : seuls manager/seller/
            // accountant peuvent être invités.
            'role' => ['required', Rule::in(['manager', 'seller', 'accountant'])],
        ];
    }

    public function attributes(): array
    {
        return ['role' => 'rôle'];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Requests"
cat > "app/Http/Requests/UpdateEmployeeRequest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateEmployeeRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('employees.manage');
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', Rule::unique('users', 'email')->ignore($this->route('employee'))],
            'phone' => ['nullable', 'string', 'max:30'],
            'role' => ['required', Rule::in(['manager', 'seller', 'accountant'])],
            'is_active' => ['sometimes', 'boolean'],
        ];
    }

    public function attributes(): array
    {
        return ['role' => 'rôle'];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Services"
cat > "app/Services/EmployeeService.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Services;

use App\Models\Role;
use App\Models\User;
use App\Support\Tenant;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Invitation et gestion des employés (§23). Le rôle "owner" n'est jamais
 * assignable ici — un seul propriétaire par entreprise, défini à
 * l'inscription (voir RegistrationService).
 */
class EmployeeService
{
    public function invite(array $data): User
    {
        $company = Tenant::current();

        $this->guardUserLimit($company);

        return DB::transaction(function () use ($data, $company) {
            $role = Role::whereNull('company_id')->where('slug', $data['role'])->firstOrFail();

            $user = User::create([
                'company_id' => $company->id,
                'role_id' => $role->id,
                'name' => $data['name'],
                'email' => $data['email'],
                'phone' => $data['phone'] ?? null,
                // Mot de passe temporaire aléatoire : l'employé le
                // redéfinit via le lien "mot de passe oublié" envoyé
                // juste après (jamais communiqué en clair).
                'password' => Str::random(32),
                'is_active' => true,
            ]);

            Password::sendResetLink(['email' => $user->email]);

            return $user;
        });
    }

    public function update(User $employee, array $data): User
    {
        $role = Role::whereNull('company_id')->where('slug', $data['role'])->firstOrFail();

        $employee->update([
            'name' => $data['name'],
            'email' => $data['email'],
            'phone' => $data['phone'] ?? null,
            'role_id' => $role->id,
            'is_active' => $data['is_active'] ?? $employee->is_active,
        ]);

        return $employee->fresh('role');
    }

    public function deactivate(User $employee, User $actingUser): void
    {
        if ($employee->id === $actingUser->id) {
            throw new RuntimeException('Vous ne pouvez pas désactiver votre propre compte.');
        }

        if ($employee->isOwner()) {
            throw new RuntimeException('Le propriétaire de l\'entreprise ne peut pas être désactivé.');
        }

        $employee->update(['is_active' => false]);
        $employee->delete();
    }

    protected function guardUserLimit($company): void
    {
        $limit = $company->subscription?->limit('users');

        if ($limit === null) {
            return; // illimité
        }

        $currentCount = User::where('company_id', $company->id)->count();

        if ($currentCount >= $limit) {
            throw new RuntimeException("Le plan actuel autorise au maximum {$limit} utilisateur(s). Passez à un plan supérieur pour inviter plus d'employés.");
        }
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/EmployeeController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use App\Http\Requests\InviteEmployeeRequest;
use App\Http\Requests\UpdateEmployeeRequest;
use App\Models\Role;
use App\Models\User;
use App\Services\EmployeeService;
use RuntimeException;

class EmployeeController extends Controller
{
    public function index()
    {
        $this->authorize('employees.view');

        $employees = User::with('role')->orderBy('name')->paginate(20);
        $userLimit = auth()->user()->company->subscription?->limit('users');

        return view('employees.index', compact('employees', 'userLimit'));
    }

    public function create()
    {
        $this->authorize('employees.manage');

        $roles = Role::whereNull('company_id')->whereIn('slug', ['manager', 'seller', 'accountant'])->get();

        return view('employees.create', compact('roles'));
    }

    public function store(InviteEmployeeRequest $request, EmployeeService $employeeService)
    {
        try {
            $employeeService->invite($request->validated());
        } catch (RuntimeException $e) {
            return back()->withErrors(['role' => $e->getMessage()])->withInput();
        }

        return redirect()->route('employees.index')->with('status', "Invitation envoyée. L'employé peut définir son mot de passe via le lien reçu.");
    }

    public function edit(User $employee)
    {
        $this->authorize('employees.manage');

        $roles = Role::whereNull('company_id')->whereIn('slug', ['manager', 'seller', 'accountant'])->get();

        return view('employees.edit', compact('employee', 'roles'));
    }

    public function update(UpdateEmployeeRequest $request, User $employee, EmployeeService $employeeService)
    {
        if ($employee->isOwner()) {
            return back()->withErrors(['role' => "Le rôle du propriétaire ne peut pas être modifié ici."]);
        }

        $employeeService->update($employee, $request->validated());

        return redirect()->route('employees.index')->with('status', 'Employé mis à jour.');
    }

    public function destroy(User $employee, EmployeeService $employeeService)
    {
        $this->authorize('employees.manage');

        try {
            $employeeService->deactivate($employee, auth()->user());
        } catch (RuntimeException $e) {
            return back()->withErrors(['employee' => $e->getMessage()]);
        }

        return back()->with('status', 'Employé désactivé.');
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "tests/Feature"
cat > "tests/Feature/EmployeeTest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Role;
use App\Models\Subscription;
use App\Models\User;
use App\Services\EmployeeService;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Illuminate\Auth\Notifications\ResetPassword;
use RuntimeException;
use Tests\TestCase;

class EmployeeTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([PermissionSeeder::class, RoleSeeder::class]);
        Notification::fake();
    }

    protected function ownerFor(Company $company): User
    {
        $role = Role::whereNull('company_id')->where('slug', 'owner')->first();

        return User::factory()->create(['company_id' => $company->id, 'role_id' => $role->id]);
    }

    public function test_owner_can_invite_an_employee_with_a_role(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $employee = app(EmployeeService::class)->invite([
            'name' => 'Nouvel Employé',
            'email' => 'employe@example.com',
            'role' => 'seller',
        ]);

        $this->assertEquals($company->id, $employee->company_id);
        $this->assertEquals('seller', $employee->role->slug);
        Notification::assertSentTo($employee, ResetPassword::class);
    }

    public function test_invitation_is_blocked_once_the_plan_user_limit_is_reached(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'free', 'status' => 'active']);
        $owner = $this->ownerFor($company); // 1er utilisateur, plan free = 1 max
        $this->actingAs($owner);

        $this->expectException(RuntimeException::class);

        app(EmployeeService::class)->invite([
            'name' => 'Trop Nombreux',
            'email' => 'trop@example.com',
            'role' => 'seller',
        ]);
    }

    public function test_a_manager_cannot_manage_employees(): void
    {
        $company = Company::factory()->create();
        $managerRole = Role::whereNull('company_id')->where('slug', 'manager')->first();
        $manager = User::factory()->create(['company_id' => $company->id, 'role_id' => $managerRole->id]);

        $this->actingAs($manager)->get(route('employees.index'))->assertForbidden();
    }

    public function test_a_user_cannot_deactivate_their_own_account(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);

        $this->expectException(RuntimeException::class);
        app(EmployeeService::class)->deactivate($owner, $owner);
    }

    public function test_the_owner_cannot_be_deactivated(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $managerRole = Role::whereNull('company_id')->where('slug', 'manager')->first();
        $manager = User::factory()->create(['company_id' => $company->id, 'role_id' => $managerRole->id]);

        $this->expectException(RuntimeException::class);
        app(EmployeeService::class)->deactivate($owner, $manager);
    }

    public function test_a_company_cannot_see_another_companys_employees(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();

        $ownerA = $this->ownerFor($companyA);
        User::factory()->create(['company_id' => $companyB->id, 'name' => 'Employé B']);

        $response = $this->actingAs($ownerA)->get(route('employees.index'));

        $response->assertOk();
        $response->assertDontSee('Employé B');
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/employees"
cat > "resources/views/employees/index.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Employés">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Employés</h2>
            <p class="text-sm text-slate-500">
                {{ $employees->total() }} membre{{ $employees->total() > 1 ? 's' : '' }}
                @if ($userLimit) sur {{ $userLimit }} autorisé{{ $userLimit > 1 ? 's' : '' }} (plan actuel) @endif
            </p>
        </div>
        @can('employees.manage')
            <x-button :href="route('employees.create')" size="sm"><x-icon name="plus" /> Inviter un employé</x-button>
        @endcan
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
    @endif
    @if ($errors->any())
        <x-alert type="error" class="mb-4">{{ $errors->first() }}</x-alert>
    @endif

    <x-card :padded="false">
        <div class="divide-y divide-slate-100">
            @foreach ($employees as $employee)
                <div class="flex items-center justify-between gap-3 px-5 py-3">
                    <div class="flex min-w-0 items-center gap-3">
                        <span class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand-50 text-sm font-semibold text-brand-700">
                            {{ strtoupper(substr($employee->name, 0, 1)) }}
                        </span>
                        <div class="min-w-0">
                            <p class="truncate text-sm font-semibold text-slate-800">
                                {{ $employee->name }}
                                @if ($employee->id === auth()->id())
                                    <span class="text-xs font-normal text-slate-400">(vous)</span>
                                @endif
                            </p>
                            <p class="truncate text-xs text-slate-400">{{ $employee->email }}</p>
                        </div>
                    </div>

                    <div class="flex shrink-0 items-center gap-3">
                        <x-badge tone="brand">{{ $employee->role?->name ?? '—' }}</x-badge>
                        @if (! $employee->is_active)
                            <x-badge tone="danger">Désactivé</x-badge>
                        @endif
                        @can('employees.manage')
                            @unless ($employee->isOwner())
                                <a href="{{ route('employees.edit', $employee) }}" class="text-sm font-medium text-brand-600 hover:underline">Modifier</a>
                                @if ($employee->id !== auth()->id())
                                    <form method="POST" action="{{ route('employees.destroy', $employee) }}" onsubmit="return confirm('Désactiver cet employé ?');">
                                        @csrf
                                        @method('DELETE')
                                        <button type="submit" class="text-sm font-medium text-red-500 hover:underline">Désactiver</button>
                                    </form>
                                @endif
                            @endunless
                        @endcan
                    </div>
                </div>
            @endforeach
        </div>
    </x-card>

    <div class="mt-5">{{ $employees->links() }}</div>
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/employees"
cat > "resources/views/employees/create.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Inviter un employé">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Inviter un employé</h2>
        <p class="text-sm text-slate-500">Un e-mail lui sera envoyé pour définir son mot de passe.</p>
    </div>

    @if ($errors->any())
        <x-alert type="error" class="mb-4">
            <ul class="list-inside list-disc space-y-1">
                @foreach ($errors->all() as $error)
                    <li>{{ $error }}</li>
                @endforeach
            </ul>
        </x-alert>
    @endif

    <x-card>
        <form method="POST" action="{{ route('employees.store') }}" class="space-y-4">
            @csrf

            <div>
                <x-label for="name">Nom complet</x-label>
                <x-input id="name" name="name" value="{{ old('name') }}" required autofocus />
            </div>

            <div>
                <x-label for="email">Adresse e-mail</x-label>
                <x-input id="email" type="email" name="email" value="{{ old('email') }}" required />
            </div>

            <div>
                <x-label for="phone">Téléphone (optionnel)</x-label>
                <x-input id="phone" name="phone" value="{{ old('phone') }}" />
            </div>

            <div>
                <x-label for="role">Rôle</x-label>
                <select id="role" name="role" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400" required>
                    @foreach ($roles as $role)
                        <option value="{{ $role->slug }}" @selected(old('role') === $role->slug)>{{ $role->name }}</option>
                    @endforeach
                </select>
                <p class="mt-1 text-xs text-slate-400">
                    Manager : accès presque complet. Vendeur : ventes et clients uniquement. Comptable : rapports et données financières en lecture.
                </p>
            </div>

            <div class="flex items-center gap-3 pt-2">
                <x-button type="submit">Envoyer l'invitation</x-button>
                <x-button :href="route('employees.index')" variant="ghost" type="button">Annuler</x-button>
            </div>
        </form>
    </x-card>
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/employees"
cat > "resources/views/employees/edit.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Modifier l'employé">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">{{ $employee->name }}</h2>
    </div>

    @if ($errors->any())
        <x-alert type="error" class="mb-4">
            <ul class="list-inside list-disc space-y-1">
                @foreach ($errors->all() as $error)
                    <li>{{ $error }}</li>
                @endforeach
            </ul>
        </x-alert>
    @endif

    <x-card>
        <form method="POST" action="{{ route('employees.update', $employee) }}" class="space-y-4">
            @csrf
            @method('PUT')

            <div>
                <x-label for="name">Nom complet</x-label>
                <x-input id="name" name="name" value="{{ old('name', $employee->name) }}" required autofocus />
            </div>

            <div>
                <x-label for="email">Adresse e-mail</x-label>
                <x-input id="email" type="email" name="email" value="{{ old('email', $employee->email) }}" required />
            </div>

            <div>
                <x-label for="phone">Téléphone</x-label>
                <x-input id="phone" name="phone" value="{{ old('phone', $employee->phone) }}" />
            </div>

            <div>
                <x-label for="role">Rôle</x-label>
                <select id="role" name="role" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400" required>
                    @foreach ($roles as $role)
                        <option value="{{ $role->slug }}" @selected(old('role', $employee->role?->slug) === $role->slug)>{{ $role->name }}</option>
                    @endforeach
                </select>
            </div>

            <label class="flex items-center gap-2 text-sm text-slate-600">
                <input type="checkbox" name="is_active" value="1" @checked(old('is_active', $employee->is_active)) class="rounded border-slate-300 text-brand-600 focus:ring-brand-400">
                Compte actif (peut se connecter)
            </label>

            <div class="flex items-center gap-3 pt-2">
                <x-button type="submit">Enregistrer les modifications</x-button>
                <x-button :href="route('employees.index')" variant="ghost" type="button">Annuler</x-button>
            </div>
        </form>
    </x-card>
</x-layouts.app>
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
use App\Http\Controllers\InvoiceController;
use App\Http\Controllers\OnboardingController;
use App\Http\Controllers\ProductController;
use App\Http\Controllers\SaleController;
use App\Http\Controllers\StockController;
use Illuminate\Support\Facades\Route;

Route::redirect('/', '/login');

// --- Invités ---
Route::middleware('guest')->group(function () {
    Route::get('register', [RegisteredCompanyController::class, 'create'])->name('register');
    Route::post('register', [RegisteredCompanyController::class, 'store']);

    Route::get('login', [AuthenticatedSessionController::class, 'create'])->name('login');
    Route::post('login', [AuthenticatedSessionController::class, 'store']);

    Route::get('forgot-password', [PasswordResetLinkController::class, 'create'])->name('password.request');
    Route::post('forgot-password', [PasswordResetLinkController::class, 'store'])->name('password.email');

    Route::get('reset-password/{token}', [NewPasswordController::class, 'create'])->name('password.reset');
    Route::post('reset-password', [NewPasswordController::class, 'store'])->name('password.store');
});

// --- Authentifiés ---
Route::middleware('auth')->group(function () {
    Route::post('logout', [AuthenticatedSessionController::class, 'destroy'])->name('logout');

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

        // Les modules suivants (rapports, paramètres) sont ajoutés phase
        // par phase — voir le cahier des charges §56.
    });
});
PARALLELIUM_FILE_EOF

echo "Termine. Lance maintenant : php artisan view:clear"
