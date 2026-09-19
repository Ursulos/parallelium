#!/usr/bin/env bash
#
# Parallelium - Correctif CRITIQUE : 500 apres connexion
# Cause : le trait BelongsToCompany ajoute a User (Phase 8) provoquait
# une recursion infinie (Tenant::check() -> Auth::user() -> User query
# -> scope -> Tenant::check() -> ...). Retire le trait, remet un filtrage
# tenant explicite + un garde-fou 404 anti cross-tenant.
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
set -e
echo "Application du correctif..."

mkdir -p "app/Models"
cat > "app/Models/User.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable
{
    // IMPORTANT : ne JAMAIS ajouter le trait BelongsToCompany ici.
    // Le guard d'authentification résout l'utilisateur courant via
    // Auth::user(), qui interroge ce modèle. Or BelongsToCompany
    // détermine l'entreprise courante via Tenant::check(), qui appelle
    // lui-même Auth::user() — cela crée une récursion infinie dès la
    // connexion (500 systématique après login). L'isolation tenant sur
    // User se fait donc à la main : ->where('company_id', Tenant::id())
    // explicitement partout où c'est nécessaire (voir EmployeeController).
    use HasFactory, Notifiable, SoftDeletes;

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

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/EmployeeController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use App\Http\Requests\InviteEmployeeRequest;
use App\Http\Requests\UpdateEmployeeRequest;
use App\Models\Role;
use App\Models\User;
use App\Services\EmployeeService;
use App\Support\Tenant;
use RuntimeException;

class EmployeeController extends Controller
{
    public function index()
    {
        $this->authorize('employees.view');

        // Filtre explicite : User n'a jamais de scope tenant automatique
        // (voir la note dans app/Models/User.php).
        $employees = User::where('company_id', Tenant::id())->with('role')->orderBy('name')->paginate(20);
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
        $this->ensureSameCompany($employee);

        $roles = Role::whereNull('company_id')->whereIn('slug', ['manager', 'seller', 'accountant'])->get();

        return view('employees.edit', compact('employee', 'roles'));
    }

    public function update(UpdateEmployeeRequest $request, User $employee, EmployeeService $employeeService)
    {
        $this->ensureSameCompany($employee);

        if ($employee->isOwner()) {
            return back()->withErrors(['role' => "Le rôle du propriétaire ne peut pas être modifié ici."]);
        }

        $employeeService->update($employee, $request->validated());

        return redirect()->route('employees.index')->with('status', 'Employé mis à jour.');
    }

    public function destroy(User $employee, EmployeeService $employeeService)
    {
        $this->authorize('employees.manage');
        $this->ensureSameCompany($employee);

        try {
            $employeeService->deactivate($employee, auth()->user());
        } catch (RuntimeException $e) {
            return back()->withErrors(['employee' => $e->getMessage()]);
        }

        return back()->with('status', 'Employé désactivé.');
    }

    /**
     * User n'ayant pas de scope tenant automatique (voir app/Models/User.php),
     * le model binding de route peut résoudre un utilisateur de N'IMPORTE
     * QUELLE entreprise. Ce garde-fou est donc obligatoire sur toute action
     * ciblant un employé précis par son ID.
     */
    protected function ensureSameCompany(User $employee): void
    {
        abort_if($employee->company_id !== Tenant::id(), 404);
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

    public function test_a_company_cannot_edit_or_deactivate_another_companys_employee(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();

        $ownerA = $this->ownerFor($companyA);
        $sellerRole = Role::whereNull('company_id')->where('slug', 'seller')->first();
        $employeeB = User::factory()->create(['company_id' => $companyB->id, 'role_id' => $sellerRole->id]);

        $this->actingAs($ownerA);

        $this->get(route('employees.edit', $employeeB))->assertNotFound();
        $this->delete(route('employees.destroy', $employeeB))->assertNotFound();
        $this->assertNotSoftDeleted($employeeB);
    }
}
PARALLELIUM_FILE_EOF

echo "Termine. Lance maintenant : php artisan view:clear"
echo "Puis reessaie de te connecter."
