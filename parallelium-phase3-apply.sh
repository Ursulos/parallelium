#!/usr/bin/env bash
#
# Parallelium - Phase 3 (Clients)
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
# Compatible Git Bash / WSL sous Windows.
set -e
echo "Application des fichiers Phase 3..."

mkdir -p "database/migrations"
cat > "database/migrations/2026_01_03_000001_create_customers_table.php" << 'PARALLELIUM_FILE_EOF'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('phone')->nullable();
            $table->string('email')->nullable();
            $table->string('address')->nullable();
            $table->text('notes')->nullable();
            // Limite de crédit optionnelle : au-delà, le module Ventes
            // (Phase 4) pourra avertir avant d'accorder une vente à crédit.
            $table->decimal('credit_limit', 14, 2)->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();

            $table->index(['company_id', 'is_active']);
            $table->index(['company_id', 'phone']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customers');
    }
};
PARALLELIUM_FILE_EOF

mkdir -p "app/Models"
cat > "app/Models/Customer.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Customer extends Model
{
    use BelongsToCompany, HasFactory, SoftDeletes;

    protected $fillable = [
        'company_id', 'name', 'phone', 'email', 'address', 'notes', 'credit_limit', 'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'credit_limit' => 'decimal:2',
        ];
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }

    public function scopeSearch(Builder $query, ?string $term): Builder
    {
        if (! $term) {
            return $query;
        }

        return $query->where(function (Builder $q) use ($term) {
            $q->where('name', 'like', "%{$term}%")
                ->orWhere('phone', 'like', "%{$term}%")
                ->orWhere('email', 'like', "%{$term}%");
        });
    }

    // Les relations vers les ventes/factures (historique d'achats, montant
    // payé, créances) sont ajoutées en Phase 4 (Ventes) et Phase 6
    // (Facturation), une fois ces modules réellement en place — voir §13.
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Requests"
cat > "app/Http/Requests/StoreCustomerRequest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreCustomerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('customers.create');
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:30'],
            'email' => ['nullable', 'email', 'max:255'],
            'address' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'credit_limit' => ['nullable', 'numeric', 'min:0'],
        ];
    }

    public function attributes(): array
    {
        return ['credit_limit' => 'limite de crédit'];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Requests"
cat > "app/Http/Requests/UpdateCustomerRequest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateCustomerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('customers.update');
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:30'],
            'email' => ['nullable', 'email', 'max:255'],
            'address' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'credit_limit' => ['nullable', 'numeric', 'min:0'],
            'is_active' => ['sometimes', 'boolean'],
        ];
    }

    public function attributes(): array
    {
        return ['credit_limit' => 'limite de crédit'];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/CustomerController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreCustomerRequest;
use App\Http\Requests\UpdateCustomerRequest;
use App\Models\Customer;
use Illuminate\Http\Request;

class CustomerController extends Controller
{
    public function index(Request $request)
    {
        $this->authorize('customers.view');

        $customers = Customer::search($request->string('q')->toString())
            ->orderBy('name')
            ->paginate(15)
            ->withQueryString();

        return view('customers.index', compact('customers'));
    }

    public function create()
    {
        $this->authorize('customers.create');

        return view('customers.create');
    }

    public function store(StoreCustomerRequest $request)
    {
        $customer = Customer::create($request->validated());

        return redirect()->route('customers.show', $customer)->with('status', 'Client ajouté.');
    }

    public function show(Customer $customer)
    {
        $this->authorize('customers.view');

        // Historique des ventes, montant payé et créances arriveront avec
        // le module Ventes (Phase 4) puis Facturation (Phase 6). Pas de
        // données fictives en attendant : tout reste explicitement vide.
        return view('customers.show', compact('customer'));
    }

    public function edit(Customer $customer)
    {
        $this->authorize('customers.update');

        return view('customers.edit', compact('customer'));
    }

    public function update(UpdateCustomerRequest $request, Customer $customer)
    {
        $customer->update($request->validated());

        return redirect()->route('customers.show', $customer)->with('status', 'Client mis à jour.');
    }

    public function destroy(Customer $customer)
    {
        $this->authorize('customers.delete');

        $customer->update(['is_active' => false]);
        $customer->delete();

        return redirect()->route('customers.index')->with('status', 'Client supprimé.');
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "database/factories"
cat > "database/factories/CustomerFactory.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Database\Factories;

use App\Models\Customer;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Customer>
 */
class CustomerFactory extends Factory
{
    protected $model = Customer::class;

    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'phone' => fake()->numerify('034 ## ### ##'),
            'is_active' => true,
        ];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "tests/Feature"
cat > "tests/Feature/CustomerTest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Customer;
use App\Models\Role;
use App\Models\User;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CustomerTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([PermissionSeeder::class, RoleSeeder::class]);
    }

    protected function ownerFor(Company $company): User
    {
        $role = Role::whereNull('company_id')->where('slug', 'owner')->first();

        return User::factory()->create(['company_id' => $company->id, 'role_id' => $role->id]);
    }

    public function test_owner_can_create_a_customer(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);

        $response = $this->actingAs($owner)->post(route('customers.store'), [
            'name' => 'Client Test',
            'phone' => '034 00 000 00',
        ]);

        $customer = Customer::first();
        $response->assertRedirect(route('customers.show', $customer));
        $this->assertDatabaseHas('customers', ['name' => 'Client Test', 'company_id' => $company->id]);
    }

    public function test_a_company_cannot_see_another_companys_customers(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();

        Customer::factory()->create(['company_id' => $companyA->id, 'name' => 'Client A']);
        Customer::factory()->create(['company_id' => $companyB->id, 'name' => 'Client B']);

        $userA = $this->ownerFor($companyA);

        $customers = $this->actingAs($userA)->get(route('customers.index'));

        $customers->assertSee('Client A');
        $customers->assertDontSee('Client B');
    }

    public function test_a_seller_without_permission_cannot_delete_a_customer(): void
    {
        $company = Company::factory()->create();
        $sellerRole = Role::whereNull('company_id')->where('slug', 'seller')->first();
        $seller = User::factory()->create(['company_id' => $company->id, 'role_id' => $sellerRole->id]);
        $customer = Customer::factory()->create(['company_id' => $company->id]);

        $this->actingAs($seller)
            ->delete(route('customers.destroy', $customer))
            ->assertForbidden();

        $this->assertNotSoftDeleted($customer);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/customers"
cat > "resources/views/customers/index.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Clients">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Clients</h2>
            <p class="text-sm text-slate-500">{{ $customers->total() }} client{{ $customers->total() > 1 ? 's' : '' }}.</p>
        </div>

        <x-button :href="route('customers.create')" size="sm"><x-icon name="plus" /> Nouveau client</x-button>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
    @endif

    <form method="GET" class="mb-4 flex items-center gap-2">
        <div class="relative flex-1 max-w-sm">
            <x-icon name="search" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <x-input name="q" value="{{ request('q') }}" placeholder="Rechercher un client, téléphone, e-mail..." class="pl-10" />
        </div>
        <x-button type="submit" variant="ghost" size="sm">Rechercher</x-button>
    </form>

    @if ($customers->isEmpty())
        <x-empty-state icon="customers" title="Aucun client pour le moment." description="Ajoutez votre premier client pour suivre ses achats et ses créances.">
            <x-slot:action>
                <x-button :href="route('customers.create')">Ajouter un client</x-button>
            </x-slot:action>
        </x-empty-state>
    @else
        <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            @foreach ($customers as $customer)
                <a href="{{ route('customers.show', $customer) }}">
                    <x-card class="h-full transition hover:border-brand-200 hover:shadow-md">
                        <div class="flex items-center gap-3">
                            <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-50 text-sm font-semibold text-brand-700">
                                {{ strtoupper(substr($customer->name, 0, 1)) }}
                            </span>
                            <div class="min-w-0">
                                <p class="truncate font-semibold text-slate-800">{{ $customer->name }}</p>
                                <p class="truncate text-xs text-slate-400">{{ $customer->phone ?? $customer->email ?? 'Aucun contact' }}</p>
                            </div>
                        </div>
                    </x-card>
                </a>
            @endforeach
        </div>

        <div class="mt-5">{{ $customers->links() }}</div>
    @endif
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/customers"
cat > "resources/views/customers/_form.blade.php" << 'PARALLELIUM_FILE_EOF'
@csrf
@if ($customer ?? null)
    @method('PUT')
@endif

<div class="grid gap-4 sm:grid-cols-2">
    <div class="sm:col-span-2">
        <x-label for="name">Nom du client</x-label>
        <x-input id="name" name="name" value="{{ old('name', $customer->name ?? '') }}" required autofocus />
    </div>

    <div>
        <x-label for="phone">Téléphone</x-label>
        <x-input id="phone" name="phone" value="{{ old('phone', $customer->phone ?? '') }}" placeholder="034 xx xxx xx" />
    </div>

    <div>
        <x-label for="email">E-mail</x-label>
        <x-input id="email" type="email" name="email" value="{{ old('email', $customer->email ?? '') }}" placeholder="Optionnel" />
    </div>

    <div class="sm:col-span-2">
        <x-label for="address">Adresse</x-label>
        <x-input id="address" name="address" value="{{ old('address', $customer->address ?? '') }}" />
    </div>

    <div>
        <x-label for="credit_limit">Limite de crédit (optionnel)</x-label>
        <x-input id="credit_limit" type="number" step="0.01" min="0" name="credit_limit" value="{{ old('credit_limit', $customer->credit_limit ?? '') }}" placeholder="Aucune limite" />
    </div>

    <div class="sm:col-span-2">
        <x-label for="notes">Notes</x-label>
        <textarea id="notes" name="notes" rows="3" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400">{{ old('notes', $customer->notes ?? '') }}</textarea>
    </div>
</div>

<div class="mt-6 flex items-center gap-3">
    <x-button type="submit">{{ ($customer ?? null) ? 'Enregistrer les modifications' : 'Ajouter le client' }}</x-button>
    <x-button :href="($customer ?? null) ? route('customers.show', $customer) : route('customers.index')" variant="ghost" type="button">Annuler</x-button>
</div>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/customers"
cat > "resources/views/customers/create.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Nouveau client">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Nouveau client</h2>
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
        <form method="POST" action="{{ route('customers.store') }}">
            @php($customer = null)
            @include('customers._form')
        </form>
    </x-card>
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/customers"
cat > "resources/views/customers/edit.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Modifier le client">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">{{ $customer->name }}</h2>
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
        <form method="POST" action="{{ route('customers.update', $customer) }}">
            @include('customers._form')
        </form>
    </x-card>
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/customers"
cat > "resources/views/customers/show.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="{{ $customer->name }}">
    <div class="mb-5 flex flex-wrap items-start justify-between gap-3">
        <div class="flex items-center gap-3">
            <span class="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-brand-50 text-lg font-semibold text-brand-700">
                {{ strtoupper(substr($customer->name, 0, 1)) }}
            </span>
            <div>
                <h2 class="text-xl font-bold text-slate-900">{{ $customer->name }}</h2>
                <p class="text-sm text-slate-500">{{ $customer->phone ?? 'Pas de téléphone' }} @if($customer->email) · {{ $customer->email }} @endif</p>
            </div>
        </div>

        <div class="flex items-center gap-2">
            <x-button :href="route('customers.edit', $customer)" variant="secondary" size="sm">Modifier</x-button>
            <form method="POST" action="{{ route('customers.destroy', $customer) }}" onsubmit="return confirm('Supprimer ce client ?');">
                @csrf
                @method('DELETE')
                <x-button type="submit" variant="ghost" size="sm">Supprimer</x-button>
            </form>
        </div>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
    @endif

    <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <x-stat-card label="Total des achats" value="—" icon="money" />
        <x-stat-card label="Montant payé" value="—" icon="revenue" />
        <x-stat-card label="Montant restant" value="—" icon="credit" />
        <x-stat-card label="Dernière commande" value="—" icon="sales" />
    </div>
    <p class="mt-2 text-xs text-slate-400">
        Ces indicateurs s'alimenteront automatiquement dès que le module Ventes sera disponible (Phase 4).
    </p>

    @if ($customer->credit_limit)
        <x-alert type="info" class="mt-4">
            Limite de crédit fixée à <x-money :amount="$customer->credit_limit" />.
        </x-alert>
    @endif

    @if ($customer->address || $customer->notes)
        <x-card class="mt-4">
            @if ($customer->address)
                <p class="text-sm"><span class="font-medium text-slate-600">Adresse :</span> {{ $customer->address }}</p>
            @endif
            @if ($customer->notes)
                <p class="mt-2 text-sm text-slate-500">{{ $customer->notes }}</p>
            @endif
        </x-card>
    @endif

    <div class="mt-6 grid gap-4 lg:grid-cols-2">
        <x-card>
            <h3 class="mb-2 text-sm font-semibold text-slate-700">Historique des ventes</h3>
            <x-empty-state icon="sales" title="Aucune vente pour le moment." description="Le module Ventes arrive en Phase 4." />
        </x-card>

        <x-card>
            <h3 class="mb-2 text-sm font-semibold text-slate-700">Factures</h3>
            <x-empty-state icon="invoices" title="Aucune facture pour le moment." description="Le module Facturation arrive en Phase 6." />
        </x-card>
    </div>
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
use App\Http\Controllers\OnboardingController;
use App\Http\Controllers\ProductController;
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

        // Les modules suivants (ventes, dépenses, factures, rapports,
        // employés, paramètres) sont ajoutés phase par phase — voir le
        // cahier des charges §56.
    });
});
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/DashboardController.php" << 'PARALLELIUM_FILE_EOF'
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
PARALLELIUM_FILE_EOF

mkdir -p "resources/views"
cat > "resources/views/dashboard.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Tableau de bord">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Bonjour {{ explode(' ', auth()->user()->name)[0] }}</h2>
        <p class="text-sm text-slate-500">Voici un aperçu de {{ $company->name }}.</p>
    </div>

    <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <x-stat-card label="Chiffre d'affaires (jour)" :value="\App\Support\Money::format($kpis['revenue_today'])" icon="money" />
        <x-stat-card label="Chiffre d'affaires (mois)" :value="\App\Support\Money::format($kpis['revenue_month'])" icon="revenue" />
        <x-stat-card label="Dépenses (mois)" :value="\App\Support\Money::format($kpis['expenses_month'])" icon="expenses" />
        <x-stat-card label="Résultat estimé" :value="\App\Support\Money::format($kpis['estimated_result'])" tone="brand" icon="result" />
    </div>

    <p class="mt-3 text-xs text-slate-400">
        Le résultat affiché est un indicateur de gestion interne, pas un résultat comptable officiel.
    </p>

    <div class="mt-6 grid gap-4 lg:grid-cols-3">
        <x-card class="lg:col-span-2">
            <div class="flex items-center justify-between">
                <h3 class="text-sm font-semibold text-slate-700">Dernières ventes</h3>
            </div>

            <x-empty-state
                class="mt-4"
                icon="sales"
                title="Aucune vente pour le moment."
                description="Le module Ventes arrive en Phase 4. Vos ventes récentes apparaîtront ici automatiquement.">
            </x-empty-state>
        </x-card>

        <x-card>
            <h3 class="text-sm font-semibold text-slate-700">Stock faible</h3>
            @if ($lowStockProducts->isEmpty())
                <x-empty-state
                    class="mt-4"
                    icon="package"
                    title="Aucune alerte de stock."
                    description="Vous serez averti ici dès qu'un produit passera sous son seuil minimum." />
            @else
                <div class="mt-3 space-y-2">
                    @foreach ($lowStockProducts as $product)
                        <a href="{{ route('stock.index', ['product_id' => $product->id]) }}" class="flex items-center justify-between rounded-xl border border-amber-100 bg-amber-50 px-3 py-2 text-sm">
                            <span class="font-medium text-amber-900">{{ $product->name }}</span>
                            <span class="text-amber-700">{{ $product->stock_quantity }} / {{ $product->minimum_stock }}</span>
                        </a>
                    @endforeach
                </div>
                <a href="{{ route('products.index', ['low_stock' => 1]) }}" class="mt-3 block text-center text-xs font-medium text-brand-600 hover:underline">
                    Voir tous les produits en stock faible
                </a>
            @endif
        </x-card>
    </div>

    <div class="mt-4 grid gap-4 lg:grid-cols-2">
        <x-card>
            <h3 class="text-sm font-semibold text-slate-700">Créances clients</h3>
            @if ($kpis['customers_count'] > 0)
                <div class="mt-3 flex items-center justify-between rounded-xl border border-slate-100 bg-slate-50 px-3 py-2 text-sm">
                    <span class="text-slate-600">{{ $kpis['customers_count'] }} client{{ $kpis['customers_count'] > 1 ? 's' : '' }} enregistré{{ $kpis['customers_count'] > 1 ? 's' : '' }}</span>
                    <a href="{{ route('customers.index') }}" class="font-medium text-brand-600 hover:underline">Voir</a>
                </div>
                <p class="mt-2 text-xs text-slate-400">Les créances s'afficheront ici dès que le module Ventes sera disponible.</p>
            @else
                <x-empty-state class="mt-4" icon="customers" title="Aucun client pour le moment." description="Ajoutez votre premier client pour commencer." />
            @endif
        </x-card>

        <x-card>
            <h3 class="text-sm font-semibold text-slate-700">Dernières dépenses</h3>
            <x-empty-state class="mt-4" icon="expenses" title="Aucune dépense pour le moment." description="Le module Dépenses arrive en Phase 5." />
        </x-card>
    </div>
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "database/seeders"
cat > "database/seeders/DemoCompanySeeder.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Company;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Role;
use App\Models\Subscription;
use App\Models\User;
use App\Services\ProductService;
use Illuminate\Database\Seeder;

/**
 * Jeu de données de démonstration ("Parallelium Demo") pour que le
 * tableau de bord soit immédiatement intéressant après installation.
 * Les données Ventes/Clients/Dépenses seront enrichies au fil des
 * phases 3 à 5 (voir §56 du cahier des charges), quand ces modules
 * existeront réellement.
 */
class DemoCompanySeeder extends Seeder
{
    public function run(): void
    {
        $company = Company::updateOrCreate(
            ['name' => 'Parallelium Demo'],
            [
                'legal_name' => 'Parallelium Demo SARL',
                'email' => 'demo@parallelium.app',
                'phone' => '034 41 853 25',
                'address' => 'Lot II A 12 Bis, Antananarivo',
                'city' => 'Antananarivo',
                'country' => 'Madagascar',
                'currency' => 'MGA',
                'timezone' => 'Indian/Antananarivo',
                'business_type' => 'Commerce de détail',
                'invoice_prefix' => 'PAR',
                'onboarding_completed' => true,
                'status' => 'active',
            ]
        );

        Subscription::updateOrCreate(
            ['company_id' => $company->id],
            ['plan' => 'starter', 'status' => 'active', 'current_period_ends_at' => now()->addMonth()]
        );

        $roles = Role::whereNull('company_id')->pluck('id', 'slug');

        $demoUsers = [
            ['name' => 'Rasoa Andriamamy', 'email' => 'owner@parallelium.demo', 'role' => 'owner'],
            ['name' => 'Nirina Rakoto', 'email' => 'manager@parallelium.demo', 'role' => 'manager'],
            ['name' => 'Fara Randria', 'email' => 'seller@parallelium.demo', 'role' => 'seller'],
        ];

        foreach ($demoUsers as $demoUser) {
            User::updateOrCreate(
                ['email' => $demoUser['email']],
                [
                    'company_id' => $company->id,
                    'role_id' => $roles[$demoUser['role']],
                    'name' => $demoUser['name'],
                    'password' => 'password',
                    'is_active' => true,
                    'email_verified_at' => now(),
                ]
            );
        }

        $this->seedCatalog($company);
        $this->seedCustomers($company);
    }

    protected function seedCatalog(Company $company): void
    {
        if (Product::withoutTenantScope()->where('company_id', $company->id)->exists()) {
            return; // déjà peuplé, ne pas dupliquer si on reseed
        }

        $categories = [
            'Épicerie' => 'Produits alimentaires de base',
            'Boissons' => 'Boissons fraîches et sèches',
            'Hygiène' => 'Produits d\'hygiène et d\'entretien',
        ];

        $categoryIds = [];
        foreach ($categories as $name => $description) {
            $categoryIds[$name] = Category::create([
                'company_id' => $company->id,
                'name' => $name,
                'description' => $description,
                'is_active' => true,
            ])->id;
        }

        $products = [
            ['name' => 'Riz local 1kg', 'category' => 'Épicerie', 'sku' => 'RIZ-001', 'purchase' => 2800, 'sell' => 3500, 'stock' => 120, 'min' => 20, 'unit' => 'kg'],
            ['name' => 'Huile alimentaire 1L', 'category' => 'Épicerie', 'sku' => 'HUI-001', 'purchase' => 6500, 'sell' => 8000, 'stock' => 40, 'min' => 10, 'unit' => 'litre'],
            ['name' => 'Sucre 1kg', 'category' => 'Épicerie', 'sku' => 'SUC-001', 'purchase' => 3200, 'sell' => 4000, 'stock' => 4, 'min' => 15, 'unit' => 'kg'],
            ['name' => 'Eau minérale 1.5L', 'category' => 'Boissons', 'sku' => 'EAU-001', 'purchase' => 1200, 'sell' => 1800, 'stock' => 96, 'min' => 24, 'unit' => 'unite'],
            ['name' => 'THB 65cl', 'category' => 'Boissons', 'sku' => 'THB-001', 'purchase' => 2500, 'sell' => 3500, 'stock' => 60, 'min' => 12, 'unit' => 'unite'],
            ['name' => 'Savon de Marseille', 'category' => 'Hygiène', 'sku' => 'SAV-001', 'purchase' => 1500, 'sell' => 2200, 'stock' => 3, 'min' => 10, 'unit' => 'unite'],
        ];

        $productService = app(ProductService::class);

        foreach ($products as $p) {
            $productService->create([
                'company_id' => $company->id,
                'category_id' => $categoryIds[$p['category']],
                'name' => $p['name'],
                'sku' => $p['sku'],
                'purchase_price' => $p['purchase'],
                'selling_price' => $p['sell'],
                'stock_quantity' => $p['stock'],
                'minimum_stock' => $p['min'],
                'unit' => $p['unit'],
                'is_active' => true,
            ]);
        }
    }

    protected function seedCustomers(Company $company): void
    {
        if (Customer::withoutTenantScope()->where('company_id', $company->id)->exists()) {
            return;
        }

        $customers = [
            ['name' => 'Hery Rakotondrabe', 'phone' => '034 12 345 67', 'address' => 'Analakely, Antananarivo'],
            ['name' => 'Voahangy Ramaroson', 'phone' => '033 98 765 43', 'address' => 'Ankorondrano, Antananarivo'],
            ['name' => 'Épicerie Faneva', 'phone' => '032 44 556 78', 'email' => 'faneva@example.com', 'credit_limit' => 100000],
        ];

        foreach ($customers as $c) {
            Customer::create([
                'company_id' => $company->id,
                'name' => $c['name'],
                'phone' => $c['phone'] ?? null,
                'email' => $c['email'] ?? null,
                'address' => $c['address'] ?? null,
                'credit_limit' => $c['credit_limit'] ?? null,
                'is_active' => true,
            ]);
        }
    }
}
PARALLELIUM_FILE_EOF

echo "Termine. Lance maintenant :"
echo "  php artisan migrate"
echo "  php artisan db:seed --class=Database\\Seeders\\DemoCompanySeeder"
echo "  php artisan view:clear"
