#!/usr/bin/env bash
#
# Parallelium - Phase 5 (Depenses)
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
# Compatible Git Bash / WSL sous Windows.
set -e
echo "Application des fichiers Phase 5..."

mkdir -p "app/Enums"
cat > "app/Enums/ExpenseCategory.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Enums;

enum ExpenseCategory: string
{
    case Merchandise = 'merchandise';
    case Transport = 'transport';
    case Rent = 'rent';
    case Salaries = 'salaries';
    case Electricity = 'electricity';
    case Internet = 'internet';
    case Supplies = 'supplies';
    case Marketing = 'marketing';
    case Maintenance = 'maintenance';
    case Other = 'other';

    public function label(): string
    {
        return match ($this) {
            self::Merchandise => 'Achat marchandises',
            self::Transport => 'Transport',
            self::Rent => 'Loyer',
            self::Salaries => 'Salaires',
            self::Electricity => 'Électricité',
            self::Internet => 'Internet',
            self::Supplies => 'Fournitures',
            self::Marketing => 'Marketing',
            self::Maintenance => 'Maintenance',
            self::Other => 'Autres',
        };
    }

    public static function options(): array
    {
        return array_combine(
            array_map(fn (self $c) => $c->value, self::cases()),
            array_map(fn (self $c) => $c->label(), self::cases()),
        );
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "database/migrations"
cat > "database/migrations/2026_01_05_000001_create_expenses_table.php" << 'PARALLELIUM_FILE_EOF'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('expenses', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('expense_number')->nullable();
            // Catégories fixes (§17 du cahier des charges) : pas de table
            // dédiée pour la V1, contrairement aux catégories produits qui,
            // elles, sont gérées par entreprise.
            $table->string('category');
            $table->string('supplier_name')->nullable();
            $table->decimal('amount', 14, 2);
            $table->string('payment_method');
            $table->text('description')->nullable();
            // Chemin de stockage interne (nom de fichier sécurisé, généré
            // par Laravel) — jamais le nom original envoyé par l'utilisateur.
            $table->string('receipt_path')->nullable();
            $table->date('expense_date');
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['company_id', 'expense_number']);
            $table->index(['company_id', 'category']);
            $table->index(['company_id', 'expense_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('expenses');
    }
};
PARALLELIUM_FILE_EOF

mkdir -p "app/Models"
cat > "app/Models/Expense.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use App\Enums\ExpenseCategory;
use App\Enums\PaymentMethod;
use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Facades\Storage;

class Expense extends Model
{
    use BelongsToCompany, SoftDeletes;

    protected $fillable = [
        'company_id', 'user_id', 'expense_number', 'category', 'supplier_name',
        'amount', 'payment_method', 'description', 'receipt_path', 'expense_date',
    ];

    protected function casts(): array
    {
        return [
            'category' => ExpenseCategory::class,
            'payment_method' => PaymentMethod::class,
            'amount' => 'decimal:2',
            'expense_date' => 'date',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function receiptUrl(): ?string
    {
        return $this->receipt_path ? Storage::disk('public')->url($this->receipt_path) : null;
    }

    public function scopeBetweenDates(Builder $query, $from, $to): Builder
    {
        return $query->whereBetween('expense_date', [$from, $to]);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Requests"
cat > "app/Http/Requests/StoreExpenseRequest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Requests;

use App\Enums\ExpenseCategory;
use App\Enums\PaymentMethod;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreExpenseRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('expenses.create');
    }

    public function rules(): array
    {
        return [
            'category' => ['required', Rule::in(array_column(ExpenseCategory::cases(), 'value'))],
            'supplier_name' => ['nullable', 'string', 'max:255'],
            'amount' => ['required', 'numeric', 'min:0.01'],
            'payment_method' => ['required', Rule::in(array_column(PaymentMethod::cases(), 'value'))],
            'description' => ['nullable', 'string', 'max:1000'],
            'expense_date' => ['required', 'date', 'before_or_equal:today'],
            // Justificatif : type MIME et taille strictement limités
            // (cahier des charges §33).
            'receipt' => ['nullable', 'file', 'mimes:jpg,jpeg,png,pdf', 'max:5120'],
        ];
    }

    public function attributes(): array
    {
        return [
            'supplier_name' => 'fournisseur',
            'expense_date' => 'date de la dépense',
            'receipt' => 'justificatif',
        ];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Requests"
cat > "app/Http/Requests/UpdateExpenseRequest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Requests;

use App\Enums\ExpenseCategory;
use App\Enums\PaymentMethod;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateExpenseRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('expenses.update');
    }

    public function rules(): array
    {
        return [
            'category' => ['required', Rule::in(array_column(ExpenseCategory::cases(), 'value'))],
            'supplier_name' => ['nullable', 'string', 'max:255'],
            'amount' => ['required', 'numeric', 'min:0.01'],
            'payment_method' => ['required', Rule::in(array_column(PaymentMethod::cases(), 'value'))],
            'description' => ['nullable', 'string', 'max:1000'],
            'expense_date' => ['required', 'date', 'before_or_equal:today'],
            'receipt' => ['nullable', 'file', 'mimes:jpg,jpeg,png,pdf', 'max:5120'],
        ];
    }

    public function attributes(): array
    {
        return [
            'supplier_name' => 'fournisseur',
            'expense_date' => 'date de la dépense',
            'receipt' => 'justificatif',
        ];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/ExpenseController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use App\Enums\ExpenseCategory;
use App\Http\Requests\StoreExpenseRequest;
use App\Http\Requests\UpdateExpenseRequest;
use App\Models\Expense;
use App\Support\Tenant;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ExpenseController extends Controller
{
    public function index(Request $request)
    {
        $this->authorize('expenses.view');

        $expenses = Expense::with('user')
            ->when($request->filled('category'), fn ($q) => $q->where('category', $request->string('category')))
            ->when($request->filled('from'), fn ($q) => $q->whereDate('expense_date', '>=', $request->date('from')))
            ->when($request->filled('to'), fn ($q) => $q->whereDate('expense_date', '<=', $request->date('to')))
            ->latest('expense_date')
            ->paginate(15)
            ->withQueryString();

        $totalThisMonth = Expense::whereBetween('expense_date', [now()->startOfMonth(), now()->endOfMonth()])->sum('amount');

        return view('expenses.index', compact('expenses', 'totalThisMonth'));
    }

    public function create()
    {
        $this->authorize('expenses.create');

        return view('expenses.create');
    }

    public function store(StoreExpenseRequest $request)
    {
        $data = $request->validated();
        $data['user_id'] = $request->user()->id;
        $data['expense_number'] = Tenant::current()->nextDocumentNumber('expense');

        if ($request->hasFile('receipt')) {
            // Laravel génère un nom de fichier haché : jamais le nom
            // original envoyé par l'utilisateur (cahier des charges §33).
            $data['receipt_path'] = $request->file('receipt')->store('receipts/'.Tenant::id(), 'public');
        }

        Expense::create($data);

        return redirect()->route('expenses.index')->with('status', 'Dépense enregistrée.');
    }

    public function edit(Expense $expense)
    {
        $this->authorize('expenses.update');

        return view('expenses.edit', compact('expense'));
    }

    public function update(UpdateExpenseRequest $request, Expense $expense)
    {
        $data = $request->validated();

        if ($request->hasFile('receipt')) {
            if ($expense->receipt_path) {
                Storage::disk('public')->delete($expense->receipt_path);
            }
            $data['receipt_path'] = $request->file('receipt')->store('receipts/'.Tenant::id(), 'public');
        }

        $expense->update($data);

        return redirect()->route('expenses.index')->with('status', 'Dépense mise à jour.');
    }

    public function destroy(Expense $expense)
    {
        $this->authorize('expenses.delete');

        if ($expense->receipt_path) {
            Storage::disk('public')->delete($expense->receipt_path);
        }

        $expense->delete();

        return back()->with('status', 'Dépense supprimée.');
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "database/factories"
cat > "database/factories/ExpenseFactory.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Database\Factories;

use App\Models\Expense;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Expense>
 */
class ExpenseFactory extends Factory
{
    protected $model = Expense::class;

    public function definition(): array
    {
        return [
            'expense_number' => 'EXP-'.now()->year.'-'.str_pad((string) fake()->unique()->numberBetween(1, 999999), 6, '0', STR_PAD_LEFT),
            'category' => 'other',
            'amount' => fake()->numberBetween(5000, 200000),
            'payment_method' => 'cash',
            'expense_date' => now(),
        ];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "tests/Feature"
cat > "tests/Feature/ExpenseTest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Expense;
use App\Models\Role;
use App\Models\User;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ExpenseTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([PermissionSeeder::class, RoleSeeder::class]);
        Storage::fake('public');
    }

    protected function ownerFor(Company $company): User
    {
        $role = Role::whereNull('company_id')->where('slug', 'owner')->first();

        return User::factory()->create(['company_id' => $company->id, 'role_id' => $role->id]);
    }

    public function test_owner_can_create_an_expense_with_a_receipt(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);

        $receipt = UploadedFile::fake()->create('facture.pdf', 200, 'application/pdf');

        $response = $this->actingAs($owner)->post(route('expenses.store'), [
            'category' => 'transport',
            'amount' => 25000,
            'payment_method' => 'cash',
            'expense_date' => now()->format('Y-m-d'),
            'receipt' => $receipt,
        ]);

        $response->assertRedirect(route('expenses.index'));

        $expense = Expense::first();
        $this->assertNotNull($expense);
        $this->assertEquals(25000, $expense->amount);
        $this->assertNotNull($expense->receipt_path);
        Storage::disk('public')->assertExists($expense->receipt_path);
        // Le nom de fichier stocké ne doit jamais être le nom original envoyé.
        $this->assertStringNotContainsString('facture.pdf', $expense->receipt_path);
    }

    public function test_a_disallowed_file_type_is_rejected(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);

        $file = UploadedFile::fake()->create('script.exe', 10, 'application/x-msdownload');

        $this->actingAs($owner)->post(route('expenses.store'), [
            'category' => 'transport',
            'amount' => 1000,
            'payment_method' => 'cash',
            'expense_date' => now()->format('Y-m-d'),
            'receipt' => $file,
        ])->assertSessionHasErrors('receipt');

        $this->assertDatabaseCount('expenses', 0);
    }

    public function test_a_seller_cannot_view_expenses(): void
    {
        $company = Company::factory()->create();
        $sellerRole = Role::whereNull('company_id')->where('slug', 'seller')->first();
        $seller = User::factory()->create(['company_id' => $company->id, 'role_id' => $sellerRole->id]);

        $this->actingAs($seller)->get(route('expenses.index'))->assertForbidden();
    }

    public function test_a_company_cannot_see_another_companys_expenses(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();

        Expense::factory()->create(['company_id' => $companyA->id, 'amount' => 1000]);
        Expense::factory()->create(['company_id' => $companyB->id, 'amount' => 2000]);

        $ownerA = $this->ownerFor($companyA);
        $this->actingAs($ownerA);

        $this->assertEquals(1000, Expense::sum('amount'));
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/expenses"
cat > "resources/views/expenses/index.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Dépenses">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Dépenses</h2>
            <p class="text-sm text-slate-500">
                Total ce mois : <span class="font-semibold text-slate-700"><x-money :amount="$totalThisMonth" /></span>
            </p>
        </div>
        <x-button :href="route('expenses.create')" size="sm"><x-icon name="plus" /> Nouvelle dépense</x-button>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
    @endif

    <form method="GET" class="mb-4 flex flex-wrap items-center gap-2">
        <select name="category" class="rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400" onchange="this.form.submit()">
            <option value="">Toutes les catégories</option>
            @foreach (\App\Enums\ExpenseCategory::options() as $value => $label)
                <option value="{{ $value }}" @selected(request('category') === $value)>{{ $label }}</option>
            @endforeach
        </select>
        <input type="date" name="from" value="{{ request('from') }}" class="rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400" onchange="this.form.submit()">
        <input type="date" name="to" value="{{ request('to') }}" class="rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400" onchange="this.form.submit()">
        <x-button type="submit" variant="ghost" size="sm">Filtrer</x-button>
    </form>

    @if ($expenses->isEmpty())
        <x-empty-state icon="expenses" title="Aucune dépense pour le moment." description="Enregistrez votre première dépense pour suivre vos sorties d'argent.">
            <x-slot:action>
                <x-button :href="route('expenses.create')">Nouvelle dépense</x-button>
            </x-slot:action>
        </x-empty-state>
    @else
        <x-card :padded="false">
            <div class="divide-y divide-slate-100">
                @foreach ($expenses as $expense)
                    <div class="flex items-center justify-between gap-3 px-5 py-3">
                        <div class="min-w-0">
                            <p class="truncate text-sm font-semibold text-slate-800">{{ $expense->category->label() }}</p>
                            <p class="truncate text-xs text-slate-400">
                                {{ $expense->supplier_name ?? 'Sans fournisseur' }} · {{ $expense->expense_date->format('d/m/Y') }}
                                @if ($expense->receipt_path) · <a href="{{ $expense->receiptUrl() }}" target="_blank" class="text-brand-600 hover:underline">Justificatif</a> @endif
                            </p>
                        </div>
                        <div class="flex shrink-0 items-center gap-3">
                            <p class="font-semibold text-slate-900"><x-money :amount="$expense->amount" /></p>
                            <a href="{{ route('expenses.edit', $expense) }}" class="text-sm font-medium text-brand-600 hover:underline">Modifier</a>
                            <form method="POST" action="{{ route('expenses.destroy', $expense) }}" onsubmit="return confirm('Supprimer cette dépense ?');">
                                @csrf
                                @method('DELETE')
                                <button type="submit" class="text-sm font-medium text-red-500 hover:underline">Supprimer</button>
                            </form>
                        </div>
                    </div>
                @endforeach
            </div>
        </x-card>

        <div class="mt-5">{{ $expenses->links() }}</div>
    @endif
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/expenses"
cat > "resources/views/expenses/_form.blade.php" << 'PARALLELIUM_FILE_EOF'
@csrf
@if ($expense ?? null)
    @method('PUT')
@endif

<div class="grid gap-4 sm:grid-cols-2">
    <div>
        <x-label for="category">Catégorie</x-label>
        <select id="category" name="category" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400" required>
            @foreach (\App\Enums\ExpenseCategory::options() as $value => $label)
                <option value="{{ $value }}" @selected(old('category', $expense->category->value ?? '') === $value)>{{ $label }}</option>
            @endforeach
        </select>
    </div>

    <div>
        <x-label for="amount">Montant</x-label>
        <x-input id="amount" type="number" step="0.01" min="0.01" name="amount" value="{{ old('amount', $expense->amount ?? '') }}" required />
    </div>

    <div>
        <x-label for="supplier_name">Fournisseur (optionnel)</x-label>
        <x-input id="supplier_name" name="supplier_name" value="{{ old('supplier_name', $expense->supplier_name ?? '') }}" />
    </div>

    <div>
        <x-label for="expense_date">Date</x-label>
        <x-input id="expense_date" type="date" name="expense_date" value="{{ old('expense_date', ($expense->expense_date ?? now())->format('Y-m-d')) }}" required />
    </div>

    <div>
        <x-label for="payment_method">Mode de paiement</x-label>
        <select id="payment_method" name="payment_method" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400" required>
            @foreach (\App\Enums\PaymentMethod::options() as $value => $label)
                <option value="{{ $value }}" @selected(old('payment_method', $expense->payment_method->value ?? 'cash') === $value)>{{ $label }}</option>
            @endforeach
        </select>
    </div>

    <div>
        <x-label for="receipt">Justificatif (optionnel)</x-label>
        <input id="receipt" type="file" name="receipt" accept=".jpg,.jpeg,.png,.pdf"
               class="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm text-slate-600 file:mr-3 file:rounded-lg file:border-0 file:bg-brand-50 file:px-3 file:py-1.5 file:text-sm file:font-medium file:text-brand-700 focus:outline-none focus:ring-2 focus:ring-brand-400">
        <p class="mt-1 text-xs text-slate-400">JPG, PNG ou PDF, 5 Mo maximum.</p>
        @if (($expense->receipt_path ?? null))
            <a href="{{ $expense->receiptUrl() }}" target="_blank" class="mt-1 inline-block text-xs font-medium text-brand-600 hover:underline">Voir le justificatif actuel</a>
        @endif
    </div>

    <div class="sm:col-span-2">
        <x-label for="description">Description (optionnel)</x-label>
        <textarea id="description" name="description" rows="3" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400">{{ old('description', $expense->description ?? '') }}</textarea>
    </div>
</div>

<div class="mt-6 flex items-center gap-3">
    <x-button type="submit">{{ ($expense ?? null) ? 'Enregistrer les modifications' : 'Ajouter la dépense' }}</x-button>
    <x-button :href="route('expenses.index')" variant="ghost" type="button">Annuler</x-button>
</div>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/expenses"
cat > "resources/views/expenses/create.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Nouvelle dépense">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Nouvelle dépense</h2>
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
        <form method="POST" action="{{ route('expenses.store') }}" enctype="multipart/form-data">
            @php($expense = null)
            @include('expenses._form')
        </form>
    </x-card>
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/expenses"
cat > "resources/views/expenses/edit.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Modifier la dépense">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Modifier la dépense</h2>
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
        <form method="POST" action="{{ route('expenses.update', $expense) }}" enctype="multipart/form-data">
            @include('expenses._form')
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
use App\Http\Controllers\ExpenseController;
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

        // Les modules suivants (factures, rapports, employés, paramètres)
        // sont ajoutés phase par phase — voir le cahier des charges §56.
    });
});
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/DashboardController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use App\Models\Customer;
use App\Models\Expense;
use App\Models\Product;
use App\Models\Sale;
use App\Support\Tenant;

class DashboardController extends Controller
{
    public function __invoke()
    {
        $company = Tenant::current();

        $completedSales = Sale::completed();

        $revenueToday = (clone $completedSales)->whereDate('sold_at', today())->sum('total_amount');
        $revenueMonth = (clone $completedSales)->whereBetween('sold_at', [now()->startOfMonth(), now()->endOfMonth()])->sum('total_amount');
        $receivables = (clone $completedSales)->where('payment_status', '!=', 'paid')->sum('remaining_amount');

        $expensesMonth = Expense::whereBetween('expense_date', [now()->startOfMonth(), now()->endOfMonth()])->sum('amount');

        $kpis = [
            'revenue_today' => $revenueToday,
            'revenue_month' => $revenueMonth,
            'expenses_month' => $expensesMonth,
            'estimated_result' => $revenueMonth - $expensesMonth,
            'low_stock_count' => Product::active()->lowStock()->count(),
            'receivables' => $receivables,
            'customers_count' => Customer::active()->count(),
        ];

        $lowStockProducts = Product::active()->lowStock()->orderBy('stock_quantity')->limit(5)->get();
        $recentSales = Sale::with('customer')->latest('sold_at')->limit(5)->get();
        $recentExpenses = Expense::latest('expense_date')->limit(5)->get();

        return view('dashboard', compact('company', 'kpis', 'lowStockProducts', 'recentSales', 'recentExpenses'));
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
        <x-card class="lg:col-span-2" :padded="false">
            <div class="flex items-center justify-between px-5 pt-5">
                <h3 class="text-sm font-semibold text-slate-700">Dernières ventes</h3>
                @can('sales.view')
                    <a href="{{ route('sales.index') }}" class="text-xs font-medium text-brand-600 hover:underline">Voir tout</a>
                @endcan
            </div>

            @if ($recentSales->isEmpty())
                <x-empty-state
                    class="m-5"
                    icon="sales"
                    title="Aucune vente pour le moment."
                    description="Vos ventes récentes apparaîtront ici automatiquement.">
                    @can('sales.create')
                        <x-slot:action>
                            <x-button :href="route('sales.create')">Nouvelle vente</x-button>
                        </x-slot:action>
                    @endcan
                </x-empty-state>
            @else
                <div class="mt-2 divide-y divide-slate-100">
                    @foreach ($recentSales as $sale)
                        <a href="{{ route('sales.show', $sale) }}" class="flex items-center justify-between px-5 py-2.5 text-sm hover:bg-slate-50">
                            <div class="min-w-0">
                                <p class="truncate font-medium text-slate-800">{{ $sale->customer?->name ?? 'Client de passage' }}</p>
                                <p class="text-xs text-slate-400">{{ $sale->sale_number }} · {{ $sale->sold_at->format('d/m H:i') }}</p>
                            </div>
                            <p class="shrink-0 font-semibold text-slate-800"><x-money :amount="$sale->total_amount" /></p>
                        </a>
                    @endforeach
                </div>
                <div class="h-2"></div>
            @endif
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
            @if ($kpis['receivables'] > 0)
                <p class="mt-3 text-2xl font-bold text-amber-600"><x-money :amount="$kpis['receivables']" /></p>
                <p class="mt-1 text-xs text-slate-400">Montant restant à encaisser sur les ventes à crédit.</p>
            @elseif ($kpis['customers_count'] > 0)
                <div class="mt-3 flex items-center justify-between rounded-xl border border-slate-100 bg-slate-50 px-3 py-2 text-sm">
                    <span class="text-slate-600">{{ $kpis['customers_count'] }} client{{ $kpis['customers_count'] > 1 ? 's' : '' }} enregistré{{ $kpis['customers_count'] > 1 ? 's' : '' }}, aucune créance en cours.</span>
                </div>
            @else
                <x-empty-state class="mt-4" icon="customers" title="Aucun client pour le moment." description="Ajoutez votre premier client pour commencer." />
            @endif
        </x-card>

        <x-card>
            <h3 class="text-sm font-semibold text-slate-700">Dernières dépenses</h3>
            @if ($recentExpenses->isEmpty())
                <x-empty-state class="mt-4" icon="expenses" title="Aucune dépense pour le moment." description="Enregistrez votre première dépense pour la voir apparaître ici." />
            @else
                <div class="mt-3 space-y-2">
                    @foreach ($recentExpenses as $expense)
                        <a href="{{ route('expenses.index') }}" class="flex items-center justify-between rounded-xl border border-slate-100 px-3 py-2 text-sm hover:bg-slate-50">
                            <span class="text-slate-600">{{ $expense->category->label() }}</span>
                            <span class="font-semibold text-slate-800"><x-money :amount="$expense->amount" /></span>
                        </a>
                    @endforeach
                </div>
                <a href="{{ route('expenses.index') }}" class="mt-3 block text-center text-xs font-medium text-brand-600 hover:underline">
                    Voir toutes les dépenses
                </a>
            @endif
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
use App\Models\Expense;
use App\Models\Product;
use App\Models\Role;
use App\Models\Sale;
use App\Models\Subscription;
use App\Models\User;
use App\Services\ProductService;
use App\Services\SaleService;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Auth;

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
        $this->seedSales($company);
        $this->seedExpenses($company);
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

    /**
     * Quelques ventes de démonstration, créées via SaleService (pas de
     * données fictives injectées directement : le stock et les créances
     * sont donc cohérents partout ailleurs dans l'appli).
     */
    protected function seedSales(Company $company): void
    {
        if (Sale::withoutTenantScope()->where('company_id', $company->id)->exists()) {
            return;
        }

        $owner = User::where('company_id', $company->id)->where('email', 'owner@parallelium.demo')->first();
        $products = Product::withoutTenantScope()->where('company_id', $company->id)->get()->keyBy('sku');
        $customer = Customer::withoutTenantScope()->where('company_id', $company->id)->where('name', 'Épicerie Faneva')->first();

        if (! $owner || $products->isEmpty()) {
            return;
        }

        // SaleService s'appuie sur le contexte tenant courant (utilisateur
        // authentifié) : on se connecte temporairement en tant que owner
        // de la démo le temps de créer ces ventes.
        $previousUserId = Auth::id();
        Auth::loginUsingId($owner->id);

        $saleService = app(SaleService::class);

        // Vente au comptant, payée intégralement.
        $sale1 = $saleService->create([
            'items' => [
                ['product_id' => $products['RIZ-001']->id, 'quantity' => 3],
                ['product_id' => $products['EAU-001']->id, 'quantity' => 6],
            ],
            'paid_amount' => (3 * $products['RIZ-001']->selling_price) + (6 * $products['EAU-001']->selling_price),
            'payment_method' => 'cash',
        ], $owner);

        // Vente à crédit (partiellement payée) pour un client fidèle.
        $totalCredit = (2 * $products['HUI-001']->selling_price) + (5 * $products['THB-001']->selling_price);
        $saleService->create([
            'customer_id' => $customer?->id,
            'items' => [
                ['product_id' => $products['HUI-001']->id, 'quantity' => 2],
                ['product_id' => $products['THB-001']->id, 'quantity' => 5],
            ],
            'paid_amount' => round($totalCredit / 2),
            'payment_method' => 'mvola',
        ], $owner);

        // Vente annulée (pour illustrer la restauration de stock tracée).
        $sale3 = $saleService->create([
            'items' => [
                ['product_id' => $products['SAV-001']->id, 'quantity' => 1],
            ],
            'paid_amount' => $products['SAV-001']->selling_price,
            'payment_method' => 'cash',
        ], $owner);
        $saleService->cancel($sale3, $owner);

        if ($previousUserId) {
            Auth::loginUsingId($previousUserId);
        } else {
            Auth::logout();
        }
    }

    protected function seedExpenses(Company $company): void
    {
        if (Expense::withoutTenantScope()->where('company_id', $company->id)->exists()) {
            return;
        }

        $owner = User::where('company_id', $company->id)->where('email', 'owner@parallelium.demo')->first();

        if (! $owner) {
            return;
        }

        $expenses = [
            ['category' => 'rent', 'supplier_name' => 'Bailleur Analakely', 'amount' => 350000, 'days_ago' => 3],
            ['category' => 'transport', 'supplier_name' => null, 'amount' => 25000, 'days_ago' => 1],
            ['category' => 'electricity', 'supplier_name' => 'Jirama', 'amount' => 60000, 'days_ago' => 5],
            ['category' => 'merchandise', 'supplier_name' => 'Grossiste Analakely', 'amount' => 420000, 'days_ago' => 7],
        ];

        foreach ($expenses as $i => $e) {
            Expense::create([
                'company_id' => $company->id,
                'user_id' => $owner->id,
                'expense_number' => $company->nextDocumentNumber('expense'),
                'category' => $e['category'],
                'supplier_name' => $e['supplier_name'],
                'amount' => $e['amount'],
                'payment_method' => 'cash',
                'expense_date' => now()->subDays($e['days_ago']),
            ]);
        }
    }
}
PARALLELIUM_FILE_EOF

echo "Termine. Lance maintenant :"
echo "  php artisan storage:link"
echo "  php artisan migrate"
echo "  php artisan db:seed --class=Database\\Seeders\\DemoCompanySeeder"
echo "  php artisan view:clear"
