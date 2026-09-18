#!/usr/bin/env bash
#
# Parallelium - Phase 4 (Ventes)
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
# Compatible Git Bash / WSL sous Windows.
set -e
echo "Application des fichiers Phase 4..."

mkdir -p "app/Enums"
cat > "app/Enums/PaymentMethod.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Enums;

enum PaymentMethod: string
{
    case Cash = 'cash';
    case Mvola = 'mvola';
    case OrangeMoney = 'orange_money';
    case AirtelMoney = 'airtel_money';
    case Card = 'card';
    case BankTransfer = 'bank_transfer';
    case Other = 'other';

    public function label(): string
    {
        return match ($this) {
            self::Cash => 'Espèces',
            self::Mvola => 'MVola',
            self::OrangeMoney => 'Orange Money',
            self::AirtelMoney => 'Airtel Money',
            self::Card => 'Carte',
            self::BankTransfer => 'Virement',
            self::Other => 'Autre',
        };
    }

    public static function options(): array
    {
        return array_combine(
            array_map(fn (self $m) => $m->value, self::cases()),
            array_map(fn (self $m) => $m->label(), self::cases()),
        );
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Enums"
cat > "app/Enums/PaymentStatus.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Enums;

enum PaymentStatus: string
{
    case Unpaid = 'unpaid';
    case PartiallyPaid = 'partially_paid';
    case Paid = 'paid';

    public function label(): string
    {
        return match ($this) {
            self::Unpaid => 'Impayée',
            self::PartiallyPaid => 'Partiellement payée',
            self::Paid => 'Payée',
        };
    }

    public function tone(): string
    {
        return match ($this) {
            self::Unpaid => 'danger',
            self::PartiallyPaid => 'warning',
            self::Paid => 'success',
        };
    }

    public static function fromAmounts(float $total, float $paid): self
    {
        if ($paid <= 0) {
            return self::Unpaid;
        }

        return $paid >= $total ? self::Paid : self::PartiallyPaid;
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Enums"
cat > "app/Enums/SaleStatus.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Enums;

enum SaleStatus: string
{
    case Completed = 'completed';
    case Cancelled = 'cancelled';

    public function label(): string
    {
        return match ($this) {
            self::Completed => 'Terminée',
            self::Cancelled => 'Annulée',
        };
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "database/migrations"
cat > "database/migrations/2026_01_04_000001_create_sales_table.php" << 'PARALLELIUM_FILE_EOF'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sales', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('customer_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();

            // Pas de contrainte FK vers invoices pour l'instant (module
            // Facturation prévu en Phase 6) : la colonne est prête, la
            // contrainte sera ajoutée quand la table existera.
            $table->unsignedBigInteger('invoice_id')->nullable();

            $table->string('sale_number')->nullable();

            // Tous les montants sont RECALCULÉS côté serveur (voir
            // SaleService) — jamais fait confiance à ce qu'envoie le
            // navigateur (cahier des charges §49).
            $table->decimal('subtotal', 14, 2)->default(0);
            $table->decimal('discount', 14, 2)->default(0);
            $table->decimal('tax_amount', 14, 2)->nullable();
            $table->decimal('total_amount', 14, 2)->default(0);
            $table->decimal('paid_amount', 14, 2)->default(0);
            $table->decimal('remaining_amount', 14, 2)->default(0);

            $table->string('payment_status')->default('unpaid'); // unpaid | partially_paid | paid
            $table->string('sale_status')->default('completed'); // completed | cancelled
            $table->string('payment_method');
            $table->text('notes')->nullable();
            $table->timestamp('sold_at')->useCurrent();
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['company_id', 'sale_number']);
            $table->index(['company_id', 'sale_status', 'sold_at']);
            $table->index(['company_id', 'payment_status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sales');
    }
};
PARALLELIUM_FILE_EOF

mkdir -p "database/migrations"
cat > "database/migrations/2026_01_04_000002_create_sale_items_table.php" << 'PARALLELIUM_FILE_EOF'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sale_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sale_id')->constrained()->cascadeOnDelete();
            $table->foreignId('product_id')->constrained();
            $table->unsignedInteger('quantity');
            // Prix unitaire figé au moment de la vente (copié depuis le
            // produit côté serveur) : un changement de prix plus tard ne
            // doit jamais modifier l'historique des ventes déjà faites.
            $table->decimal('unit_price', 14, 2);
            $table->decimal('discount', 14, 2)->default(0);
            $table->decimal('subtotal', 14, 2);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sale_items');
    }
};
PARALLELIUM_FILE_EOF

mkdir -p "app/Models"
cat > "app/Models/Sale.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use App\Enums\PaymentMethod;
use App\Enums\PaymentStatus;
use App\Enums\SaleStatus;
use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Sale extends Model
{
    use BelongsToCompany, SoftDeletes;

    protected $fillable = [
        'company_id', 'customer_id', 'user_id', 'invoice_id', 'sale_number',
        'subtotal', 'discount', 'tax_amount', 'total_amount', 'paid_amount', 'remaining_amount',
        'payment_status', 'sale_status', 'payment_method', 'notes', 'sold_at',
    ];

    protected function casts(): array
    {
        return [
            'payment_status' => PaymentStatus::class,
            'sale_status' => SaleStatus::class,
            'payment_method' => PaymentMethod::class,
            'subtotal' => 'decimal:2',
            'discount' => 'decimal:2',
            'tax_amount' => 'decimal:2',
            'total_amount' => 'decimal:2',
            'paid_amount' => 'decimal:2',
            'remaining_amount' => 'decimal:2',
            'sold_at' => 'datetime',
        ];
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(SaleItem::class);
    }

    public function isCancelled(): bool
    {
        return $this->sale_status === SaleStatus::Cancelled;
    }

    public function scopeCompleted(Builder $query): Builder
    {
        return $query->where('sale_status', SaleStatus::Completed->value);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Models"
cat > "app/Models/SaleItem.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SaleItem extends Model
{
    protected $fillable = ['sale_id', 'product_id', 'quantity', 'unit_price', 'discount', 'subtotal'];

    protected function casts(): array
    {
        return [
            'unit_price' => 'decimal:2',
            'discount' => 'decimal:2',
            'subtotal' => 'decimal:2',
        ];
    }

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Services"
cat > "app/Services/SaleService.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Services;

use App\Enums\PaymentStatus;
use App\Enums\SaleStatus;
use App\Enums\StockMovementType;
use App\Models\Product;
use App\Models\Sale;
use App\Models\User;
use App\Support\Tenant;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * Flux d'une vente (cahier des charges §15) :
 * vérifier le stock -> calculer le montant -> créer la vente -> créer les
 * lignes -> enregistrer le paiement -> diminuer le stock -> créer le
 * mouvement de stock -> mettre à jour les indicateurs.
 *
 * RÈGLE CAPITALE (§49) : le serveur recalcule TOUJOURS le sous-total, la
 * remise, le total, le paiement et le reste. Le prix unitaire vient de
 * Product::selling_price en base, jamais d'une valeur envoyée par le
 * navigateur. Toute l'opération est atomique (DB::transaction) : si une
 * étape échoue, tout est annulé.
 */
class SaleService
{
    public function __construct(protected StockService $stockService)
    {
    }

    public function create(array $data, User $user): Sale
    {
        return DB::transaction(function () use ($data, $user) {
            $company = Tenant::current();

            // 1. Charger les produits réels (jamais les prix du frontend),
            //    avec verrou pour éviter une vente en double sur un stock
            //    limité (course entre deux ventes simultanées).
            $productIds = collect($data['items'])->pluck('product_id');
            $products = Product::whereIn('id', $productIds)->lockForUpdate()->get()->keyBy('id');

            $subtotal = 0;
            $lines = [];

            foreach ($data['items'] as $item) {
                $product = $products->get($item['product_id']);

                if (! $product) {
                    throw new RuntimeException('Produit introuvable.');
                }

                // 2. Vérifier le stock.
                if ($product->stock_quantity < $item['quantity']) {
                    throw new RuntimeException("Stock insuffisant pour « {$product->name} » (disponible : {$product->stock_quantity}).");
                }

                $lineDiscount = (float) ($item['discount'] ?? 0);
                $lineSubtotal = ($product->selling_price * $item['quantity']) - $lineDiscount;

                $lines[] = [
                    'product' => $product,
                    'quantity' => (int) $item['quantity'],
                    'unit_price' => $product->selling_price,
                    'discount' => $lineDiscount,
                    'subtotal' => $lineSubtotal,
                ];

                $subtotal += $lineSubtotal;
            }

            // 3. Calculer le montant total (remise globale déduite).
            $globalDiscount = (float) ($data['discount'] ?? 0);
            $totalAmount = max(0, $subtotal - $globalDiscount);

            $paidAmount = (float) ($data['paid_amount'] ?? 0);
            if ($paidAmount > $totalAmount) {
                throw new RuntimeException('Le montant payé ne peut pas dépasser le total de la vente.');
            }

            $remainingAmount = $totalAmount - $paidAmount;

            // 4. Créer la vente.
            $sale = Sale::create([
                'company_id' => $company->id,
                'customer_id' => $data['customer_id'] ?? null,
                'user_id' => $user->id,
                'sale_number' => $company->nextDocumentNumber('sale'),
                'subtotal' => $subtotal,
                'discount' => $globalDiscount,
                'total_amount' => $totalAmount,
                'paid_amount' => $paidAmount,
                'remaining_amount' => $remainingAmount,
                'payment_status' => PaymentStatus::fromAmounts($totalAmount, $paidAmount),
                'sale_status' => SaleStatus::Completed,
                'payment_method' => $data['payment_method'],
                'notes' => $data['notes'] ?? null,
                'sold_at' => now(),
            ]);

            // 5. Créer les lignes + 6/7. Diminuer le stock et tracer le mouvement.
            foreach ($lines as $line) {
                $sale->items()->create([
                    'product_id' => $line['product']->id,
                    'quantity' => $line['quantity'],
                    'unit_price' => $line['unit_price'],
                    'discount' => $line['discount'],
                    'subtotal' => $line['subtotal'],
                ]);

                $this->stockService->record(
                    $line['product'],
                    StockMovementType::Sale,
                    -$line['quantity'],
                    "Vente {$sale->sale_number}",
                    $sale,
                    $user,
                );
            }

            return $sale->fresh(['items.product', 'customer']);
        });
    }

    /**
     * Annule une vente : restaure le stock (mouvement "return" tracé,
     * jamais un simple update silencieux — §54) et marque la vente comme
     * annulée. Les ventes déjà annulées ne peuvent pas l'être à nouveau.
     */
    public function cancel(Sale $sale, User $user): Sale
    {
        return DB::transaction(function () use ($sale, $user) {
            if ($sale->isCancelled()) {
                throw new RuntimeException('Cette vente est déjà annulée.');
            }

            foreach ($sale->items()->with('product')->get() as $item) {
                if (! $item->product) {
                    continue;
                }

                $this->stockService->record(
                    $item->product,
                    StockMovementType::Return,
                    $item->quantity,
                    "Annulation vente {$sale->sale_number}",
                    $sale,
                    $user,
                );
            }

            $sale->update(['sale_status' => SaleStatus::Cancelled]);

            return $sale->fresh();
        });
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Requests"
cat > "app/Http/Requests/StoreSaleRequest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Requests;

use App\Enums\PaymentMethod;
use App\Support\Tenant;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreSaleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('sales.create');
    }

    public function rules(): array
    {
        return [
            'customer_id' => [
                'nullable',
                Rule::exists('customers', 'id')->where('company_id', Tenant::id()),
            ],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => [
                'required',
                Rule::exists('products', 'id')->where('company_id', Tenant::id()),
            ],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.discount' => ['nullable', 'numeric', 'min:0'],
            'discount' => ['nullable', 'numeric', 'min:0'],
            // paid_amount et payment_method sont saisis par l'utilisateur,
            // mais le TOTAL est toujours recalculé côté serveur (voir
            // SaleService) : on ne valide ici que la forme, pas le montant.
            'paid_amount' => ['required', 'numeric', 'min:0'],
            'payment_method' => ['required', Rule::in(array_column(PaymentMethod::cases(), 'value'))],
            'notes' => ['nullable', 'string', 'max:1000'],
        ];
    }

    public function attributes(): array
    {
        return [
            'customer_id' => 'client',
            'items' => 'produits',
            'paid_amount' => 'montant payé',
            'payment_method' => 'mode de paiement',
        ];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/SaleController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreSaleRequest;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Sale;
use App\Services\SaleService;
use Illuminate\Http\Request;
use RuntimeException;

class SaleController extends Controller
{
    public function index(Request $request)
    {
        $this->authorize('sales.view');

        $sales = Sale::with(['customer', 'user'])
            ->when($request->filled('status'), fn ($q) => $q->where('payment_status', $request->string('status')))
            ->latest('sold_at')
            ->paginate(15)
            ->withQueryString();

        return view('sales.index', compact('sales'));
    }

    public function create()
    {
        $this->authorize('sales.create');

        $products = Product::active()
            ->where('stock_quantity', '>', 0)
            ->orderBy('name')
            ->get(['id', 'name', 'sku', 'selling_price', 'stock_quantity', 'minimum_stock', 'unit']);

        $customers = Customer::active()->orderBy('name')->get(['id', 'name', 'phone']);

        return view('sales.create', compact('products', 'customers'));
    }

    public function store(StoreSaleRequest $request, SaleService $saleService)
    {
        try {
            $sale = $saleService->create($request->validated(), $request->user());
        } catch (RuntimeException $e) {
            return back()->withErrors(['items' => $e->getMessage()])->withInput();
        }

        return redirect()->route('sales.show', $sale)->with('status', 'Vente enregistrée.');
    }

    public function show(Sale $sale)
    {
        $this->authorize('sales.view');

        $sale->load(['items.product', 'customer', 'user']);

        return view('sales.show', compact('sale'));
    }

    public function cancel(Sale $sale, SaleService $saleService)
    {
        $this->authorize('sales.cancel');

        try {
            $saleService->cancel($sale, request()->user());
        } catch (RuntimeException $e) {
            return back()->withErrors(['sale' => $e->getMessage()]);
        }

        return back()->with('status', 'Vente annulée, le stock a été restauré.');
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "database/factories"
cat > "database/factories/SaleFactory.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Database\Factories;

use App\Models\Sale;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Sale>
 */
class SaleFactory extends Factory
{
    protected $model = Sale::class;

    public function definition(): array
    {
        return [
            'sale_number' => 'SALE-'.now()->year.'-'.str_pad((string) fake()->unique()->numberBetween(1, 999999), 6, '0', STR_PAD_LEFT),
            'subtotal' => 0,
            'discount' => 0,
            'total_amount' => 0,
            'paid_amount' => 0,
            'remaining_amount' => 0,
            'payment_status' => 'unpaid',
            'sale_status' => 'completed',
            'payment_method' => 'cash',
            'sold_at' => now(),
        ];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "tests/Feature"
cat > "tests/Feature/SaleTest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Services\SaleService;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use RuntimeException;
use Tests\TestCase;

class SaleTest extends TestCase
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

    public function test_creating_a_sale_decreases_stock_and_records_a_movement(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 10, 'selling_price' => 5000]);

        $sale = app(SaleService::class)->create([
            'items' => [['product_id' => $product->id, 'quantity' => 3]],
            'paid_amount' => 15000,
            'payment_method' => 'cash',
        ], $owner);

        $this->assertEquals(7, $product->fresh()->stock_quantity);
        $this->assertEquals(15000, $sale->total_amount);
        $this->assertEquals('paid', $sale->payment_status->value);
        $this->assertDatabaseHas('stock_movements', [
            'product_id' => $product->id,
            'quantity' => -3,
            'reference_type' => $sale->getMorphClass(),
            'reference_id' => $sale->id,
        ]);
    }

    public function test_sale_fails_when_stock_is_insufficient(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 2]);

        try {
            app(SaleService::class)->create([
                'items' => [['product_id' => $product->id, 'quantity' => 5]],
                'paid_amount' => 0,
                'payment_method' => 'cash',
            ], $owner);
            $this->fail('Une exception RuntimeException était attendue.');
        } catch (RuntimeException $e) {
            $this->assertStringContainsString('Stock insuffisant', $e->getMessage());
        }

        $this->assertEquals(2, $product->fresh()->stock_quantity);
        $this->assertDatabaseCount('sales', 0);
    }

    public function test_partial_payment_computes_remaining_amount_and_status(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 10, 'selling_price' => 10000]);
        $customer = Customer::factory()->create(['company_id' => $company->id]);

        $sale = app(SaleService::class)->create([
            'customer_id' => $customer->id,
            'items' => [['product_id' => $product->id, 'quantity' => 2]],
            'paid_amount' => 15000,
            'payment_method' => 'mvola',
        ], $owner);

        $this->assertEquals(20000, $sale->total_amount);
        $this->assertEquals(5000, $sale->remaining_amount);
        $this->assertEquals('partially_paid', $sale->payment_status->value);
        $this->assertEquals(20000, $customer->fresh()->totalPurchases());
        $this->assertEquals(5000, $customer->fresh()->totalRemaining());
    }

    public function test_cancelling_a_sale_restores_stock(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 10, 'selling_price' => 1000]);

        $saleService = app(SaleService::class);
        $sale = $saleService->create([
            'items' => [['product_id' => $product->id, 'quantity' => 4]],
            'paid_amount' => 4000,
            'payment_method' => 'cash',
        ], $owner);

        $this->assertEquals(6, $product->fresh()->stock_quantity);

        $saleService->cancel($sale, $owner);

        $this->assertEquals(10, $product->fresh()->stock_quantity);
        $this->assertEquals('cancelled', $sale->fresh()->sale_status->value);
    }

    public function test_a_company_cannot_see_another_companys_sales(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();

        $ownerA = $this->ownerFor($companyA);
        $ownerB = $this->ownerFor($companyB);

        $this->actingAs($ownerB);
        $productB = Product::factory()->create(['company_id' => $companyB->id, 'stock_quantity' => 5]);
        app(SaleService::class)->create([
            'items' => [['product_id' => $productB->id, 'quantity' => 1]],
            'paid_amount' => 0,
            'payment_method' => 'cash',
        ], $ownerB);

        $this->actingAs($ownerA);

        $this->assertCount(0, \App\Models\Sale::all());
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/sales"
cat > "resources/views/sales/create.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Nouvelle vente">
    <div x-data="saleForm({
            products: {{ \Illuminate\Support\Js::from($products) }},
            currencySymbol: {{ \Illuminate\Support\Js::from(auth()->user()->company->currencySymbol()) }},
        })" x-init="init()">

        <div class="mb-5 flex items-center justify-between">
            <div>
                <h2 class="text-xl font-bold text-slate-900">Nouvelle vente</h2>
                <p class="text-sm text-slate-500">Sélectionnez les produits, le reste est calculé automatiquement.</p>
            </div>
            <x-button :href="route('sales.index')" variant="ghost" size="sm">Annuler</x-button>
        </div>

        @if ($errors->any())
            <x-alert type="error" class="mb-4">{{ $errors->first() }}</x-alert>
        @endif

        <form method="POST" action="{{ route('sales.store') }}">
            @csrf

            <div class="grid gap-4 lg:grid-cols-5">
                {{-- Catalogue --}}
                <div class="lg:col-span-3">
                    <div class="relative mb-3">
                        <x-icon name="search" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                        <input type="text" x-model="search" placeholder="Rechercher un produit ou un SKU..."
                               class="w-full rounded-xl border border-slate-200 py-3 pl-10 pr-4 text-base focus:outline-none focus:ring-2 focus:ring-brand-400">
                    </div>

                    <div class="grid grid-cols-2 gap-2 sm:grid-cols-3">
                        <template x-for="product in filteredProducts()" :key="product.id">
                            <button type="button" x-on:click="addToCart(product)"
                                    class="rounded-2xl border border-slate-100 bg-white p-3 text-left transition hover:border-brand-200 hover:shadow-sm active:scale-95">
                                <p class="truncate text-sm font-semibold text-slate-800" x-text="product.name"></p>
                                <p class="mt-0.5 text-xs text-slate-400" x-text="product.stock_quantity + ' ' + product.unit + ' dispo.'"></p>
                                <p class="mt-1 text-sm font-bold text-brand-700" x-text="formatMoney(product.selling_price)"></p>
                            </button>
                        </template>
                    </div>

                    <p x-show="filteredProducts().length === 0" x-cloak class="mt-4 text-center text-sm text-slate-400">
                        Aucun produit ne correspond à la recherche.
                    </p>
                </div>

                {{-- Panier --}}
                <div class="lg:col-span-2">
                    <x-card>
                        <h3 class="mb-3 text-sm font-semibold text-slate-700">Panier</h3>

                        <p x-show="cart.length === 0" x-cloak class="rounded-xl border border-dashed border-slate-200 py-8 text-center text-sm text-slate-400">
                            Ajoutez des produits depuis le catalogue.
                        </p>

                        <div class="space-y-2" x-show="cart.length > 0">
                            <template x-for="(item, index) in cart" :key="item.product_id">
                                <div class="flex items-center gap-2 rounded-xl border border-slate-100 p-2">
                                    <div class="min-w-0 flex-1">
                                        <p class="truncate text-sm font-medium text-slate-800" x-text="item.name"></p>
                                        <p class="text-xs text-slate-400" x-text="formatMoney(item.unit_price) + ' / ' + item.unit"></p>
                                    </div>

                                    <div class="flex items-center gap-1">
                                        <button type="button" x-on:click="changeQuantity(index, -1)" class="flex h-7 w-7 items-center justify-center rounded-full bg-slate-100 text-slate-600">-</button>
                                        <input type="number" min="1" :max="item.max" x-model.number="item.quantity" x-on:change="clampQuantity(index)" class="w-12 rounded-lg border border-slate-200 py-1 text-center text-sm">
                                        <button type="button" x-on:click="changeQuantity(index, 1)" class="flex h-7 w-7 items-center justify-center rounded-full bg-slate-100 text-slate-600">+</button>
                                    </div>

                                    <p class="w-20 shrink-0 text-right text-sm font-semibold text-slate-800" x-text="formatMoney(item.quantity * item.unit_price)"></p>

                                    <button type="button" x-on:click="removeFromCart(index)" class="shrink-0 text-slate-300 hover:text-red-500">
                                        <x-icon name="error" />
                                    </button>

                                    <input type="hidden" :name="'items[' + index + '][product_id]'" :value="item.product_id">
                                    <input type="hidden" :name="'items[' + index + '][quantity]'" :value="item.quantity">
                                </div>
                            </template>
                        </div>

                        <div class="mt-4 space-y-2 border-t border-slate-100 pt-3 text-sm">
                            <div class="flex justify-between text-slate-500">
                                <span>Sous-total</span>
                                <span x-text="formatMoney(subtotal())"></span>
                            </div>
                            <div class="flex items-center justify-between text-slate-500">
                                <span>Remise</span>
                                <input type="number" name="discount" min="0" step="0.01" x-model.number="discount" class="w-24 rounded-lg border border-slate-200 py-1 text-right text-sm">
                            </div>
                            <div class="flex justify-between text-base font-bold text-slate-900">
                                <span>Total</span>
                                <span x-text="formatMoney(total())"></span>
                            </div>
                        </div>

                        <div class="mt-4 space-y-3 border-t border-slate-100 pt-3">
                            <div>
                                <x-label for="customer_id">Client (optionnel)</x-label>
                                <select id="customer_id" name="customer_id" class="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400">
                                    <option value="">Client de passage</option>
                                    @foreach ($customers as $customer)
                                        <option value="{{ $customer->id }}">{{ $customer->name }}</option>
                                    @endforeach
                                </select>
                            </div>

                            <div>
                                <x-label for="payment_method">Paiement</x-label>
                                <select id="payment_method" name="payment_method" class="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400">
                                    @foreach (\App\Enums\PaymentMethod::options() as $value => $label)
                                        <option value="{{ $value }}">{{ $label }}</option>
                                    @endforeach
                                </select>
                            </div>

                            <div>
                                <x-label for="paid_amount">Montant payé</x-label>
                                <input id="paid_amount" type="number" name="paid_amount" min="0" step="0.01" x-model.number="paidAmount"
                                       class="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400">
                                <button type="button" x-on:click="paidAmount = total()" class="mt-1 text-xs font-medium text-brand-600 hover:underline">Payé en totalité</button>
                            </div>

                            <div class="flex justify-between rounded-xl bg-slate-50 px-3 py-2 text-sm">
                                <span class="text-slate-500">Reste à payer</span>
                                <span class="font-semibold" :class="remaining() > 0 ? 'text-amber-600' : 'text-emerald-600'" x-text="formatMoney(remaining())"></span>
                            </div>

                            <div>
                                <x-label for="notes">Note (optionnel)</x-label>
                                <input id="notes" name="notes" class="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400">
                            </div>
                        </div>

                        <x-button type="submit" class="mt-4 w-full justify-center" size="lg" x-bind:disabled="cart.length === 0">
                            Enregistrer la vente
                        </x-button>
                    </x-card>
                </div>
            </div>
        </form>
    </div>

    <script>
        function saleForm(config) {
            return {
                allProducts: config.products,
                currencySymbol: config.currencySymbol,
                search: '',
                cart: [],
                discount: 0,
                paidAmount: 0,

                init() {},

                filteredProducts() {
                    const term = this.search.trim().toLowerCase();
                    let list = this.allProducts;
                    if (term) {
                        list = list.filter(p =>
                            p.name.toLowerCase().includes(term) ||
                            (p.sku && p.sku.toLowerCase().includes(term))
                        );
                    }
                    return list.slice(0, 24);
                },

                addToCart(product) {
                    const existing = this.cart.find(i => i.product_id === product.id);
                    if (existing) {
                        this.changeQuantity(this.cart.indexOf(existing), 1);
                        return;
                    }
                    if (product.stock_quantity < 1) return;

                    this.cart.push({
                        product_id: product.id,
                        name: product.name,
                        unit: product.unit,
                        unit_price: parseFloat(product.selling_price),
                        quantity: 1,
                        max: product.stock_quantity,
                    });
                },

                removeFromCart(index) {
                    this.cart.splice(index, 1);
                },

                changeQuantity(index, delta) {
                    const item = this.cart[index];
                    const next = item.quantity + delta;
                    if (next < 1) { this.removeFromCart(index); return; }
                    item.quantity = Math.min(next, item.max);
                },

                clampQuantity(index) {
                    const item = this.cart[index];
                    if (item.quantity < 1) item.quantity = 1;
                    if (item.quantity > item.max) item.quantity = item.max;
                },

                subtotal() {
                    return this.cart.reduce((sum, i) => sum + (i.quantity * i.unit_price), 0);
                },

                total() {
                    return Math.max(0, this.subtotal() - (this.discount || 0));
                },

                remaining() {
                    return Math.max(0, this.total() - (this.paidAmount || 0));
                },

                formatMoney(value) {
                    return new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 2 }).format(Number(value) || 0) + ' ' + this.currencySymbol;
                },
            };
        }
    </script>
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/sales"
cat > "resources/views/sales/index.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Ventes">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Ventes</h2>
            <p class="text-sm text-slate-500">{{ $sales->total() }} vente{{ $sales->total() > 1 ? 's' : '' }}.</p>
        </div>
        <x-button :href="route('sales.create')" size="sm"><x-icon name="plus" /> Nouvelle vente</x-button>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
    @endif
    @if ($errors->any())
        <x-alert type="error" class="mb-4">{{ $errors->first() }}</x-alert>
    @endif

    @if ($sales->isEmpty())
        <x-empty-state icon="sales" title="Aucune vente pour le moment." description="Enregistrez votre première vente pour la voir apparaître ici.">
            <x-slot:action>
                <x-button :href="route('sales.create')">Nouvelle vente</x-button>
            </x-slot:action>
        </x-empty-state>
    @else
        <x-card :padded="false">
            <div class="divide-y divide-slate-100">
                @foreach ($sales as $sale)
                    <a href="{{ route('sales.show', $sale) }}" class="flex items-center justify-between gap-3 px-5 py-3 hover:bg-slate-50">
                        <div class="min-w-0">
                            <p class="truncate text-sm font-semibold text-slate-800">
                                {{ $sale->sale_number }}
                                @if ($sale->isCancelled())
                                    <x-badge tone="danger" class="ml-1">Annulée</x-badge>
                                @endif
                            </p>
                            <p class="text-xs text-slate-400">
                                {{ $sale->customer?->name ?? 'Client de passage' }} · {{ $sale->sold_at->format('d/m/Y H:i') }}
                            </p>
                        </div>
                        <div class="shrink-0 text-right">
                            <p class="text-sm font-bold text-slate-900"><x-money :amount="$sale->total_amount" /></p>
                            <x-badge :tone="$sale->payment_status->tone()">{{ $sale->payment_status->label() }}</x-badge>
                        </div>
                    </a>
                @endforeach
            </div>
        </x-card>

        <div class="mt-5">{{ $sales->links() }}</div>
    @endif
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/sales"
cat > "resources/views/sales/show.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="{{ $sale->sale_number }}">
    <div class="mb-5 flex flex-wrap items-start justify-between gap-3 print:hidden">
        <div>
            <h2 class="text-xl font-bold text-slate-900">{{ $sale->sale_number }}</h2>
            <p class="text-sm text-slate-500">{{ $sale->sold_at->format('d/m/Y \à H:i') }} · Enregistrée par {{ $sale->user?->name ?? '—' }}</p>
        </div>

        <div class="flex items-center gap-2">
            <x-button variant="secondary" size="sm" onclick="window.print()">Imprimer / PDF</x-button>
            @can('sales.cancel')
                @if (! $sale->isCancelled())
                    <form method="POST" action="{{ route('sales.cancel', $sale) }}" onsubmit="return confirm('Annuler cette vente ? Le stock sera restauré.');">
                        @csrf
                        <x-button type="submit" variant="danger" size="sm">Annuler la vente</x-button>
                    </form>
                @endif
            @endcan
        </div>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4 print:hidden">{{ session('status') }}</x-alert>
    @endif
    @if ($errors->any())
        <x-alert type="error" class="mb-4 print:hidden">{{ $errors->first() }}</x-alert>
    @endif

    @if ($sale->isCancelled())
        <x-alert type="warning" class="mb-4">Cette vente a été annulée. Le stock correspondant a été restauré.</x-alert>
    @endif

    <x-card>
        <div class="flex items-center justify-between border-b border-slate-100 pb-4">
            <div>
                <p class="font-bold text-slate-900">{{ auth()->user()->company->name }}</p>
                <p class="text-xs text-slate-400">{{ auth()->user()->company->phone }}</p>
            </div>
            <div class="text-right">
                <x-badge :tone="$sale->payment_status->tone()">{{ $sale->payment_status->label() }}</x-badge>
                <p class="mt-1 text-xs text-slate-400">{{ $sale->payment_method->label() }}</p>
            </div>
        </div>

        <div class="border-b border-slate-100 py-4 text-sm">
            <p class="font-medium text-slate-600">Client</p>
            <p class="text-slate-800">{{ $sale->customer?->name ?? 'Client de passage' }}</p>
            @if ($sale->customer?->phone)
                <p class="text-xs text-slate-400">{{ $sale->customer->phone }}</p>
            @endif
        </div>

        <div class="divide-y divide-slate-100 py-2">
            @foreach ($sale->items as $item)
                <div class="flex items-center justify-between py-2 text-sm">
                    <div>
                        <p class="font-medium text-slate-800">{{ $item->product->name ?? 'Produit supprimé' }}</p>
                        <p class="text-xs text-slate-400">{{ $item->quantity }} × <x-money :amount="$item->unit_price" /></p>
                    </div>
                    <p class="font-semibold text-slate-800"><x-money :amount="$item->subtotal" /></p>
                </div>
            @endforeach
        </div>

        <div class="space-y-1.5 border-t border-slate-100 pt-4 text-sm">
            <div class="flex justify-between text-slate-500">
                <span>Sous-total</span>
                <span><x-money :amount="$sale->subtotal" /></span>
            </div>
            @if ($sale->discount > 0)
                <div class="flex justify-between text-slate-500">
                    <span>Remise</span>
                    <span>- <x-money :amount="$sale->discount" /></span>
                </div>
            @endif
            <div class="flex justify-between text-base font-bold text-slate-900">
                <span>Total</span>
                <span><x-money :amount="$sale->total_amount" /></span>
            </div>
            <div class="flex justify-between text-slate-500">
                <span>Payé</span>
                <span><x-money :amount="$sale->paid_amount" /></span>
            </div>
            @if ($sale->remaining_amount > 0)
                <div class="flex justify-between font-semibold text-amber-600">
                    <span>Reste à payer</span>
                    <span><x-money :amount="$sale->remaining_amount" /></span>
                </div>
            @endif
        </div>

        @if ($sale->notes)
            <p class="mt-4 border-t border-slate-100 pt-3 text-sm text-slate-500">{{ $sale->notes }}</p>
        @endif
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

        // Les modules suivants (dépenses, factures, rapports, employés,
        // paramètres) sont ajoutés phase par phase — voir le cahier des
        // charges §56.
    });
});
PARALLELIUM_FILE_EOF

mkdir -p "app/Models"
cat > "app/Models/Customer.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
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

    public function sales(): HasMany
    {
        return $this->hasMany(Sale::class);
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

    public function totalPurchases(): float
    {
        return (float) $this->sales()->completed()->sum('total_amount');
    }

    public function totalPaid(): float
    {
        return (float) $this->sales()->completed()->sum('paid_amount');
    }

    public function totalRemaining(): float
    {
        return (float) $this->sales()->completed()->sum('remaining_amount');
    }

    public function lastOrderAt(): ?\Illuminate\Support\Carbon
    {
        return $this->sales()->completed()->latest('sold_at')->value('sold_at');
    }

    // Les factures (Phase 6) s'ajouteront ici de la même façon.
}
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
            @can('sales.create')
                <x-button :href="route('sales.create')" size="sm"><x-icon name="plus" /> Nouvelle vente</x-button>
            @endcan
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
        <x-stat-card label="Total des achats" :value="\App\Support\Money::format($customer->totalPurchases())" icon="money" />
        <x-stat-card label="Montant payé" :value="\App\Support\Money::format($customer->totalPaid())" icon="revenue" />
        <x-stat-card label="Montant restant" :value="\App\Support\Money::format($customer->totalRemaining())" tone="brand" icon="credit" />
        <x-stat-card label="Dernière commande" :value="$customer->lastOrderAt()?->format('d/m/Y') ?? '—'" icon="sales" />
    </div>

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
            @php($sales = $customer->sales()->latest('sold_at')->limit(8)->get())
            @if ($sales->isEmpty())
                <x-empty-state icon="sales" title="Aucune vente pour le moment." description="Les ventes de ce client apparaîtront ici." />
            @else
                <div class="divide-y divide-slate-100">
                    @foreach ($sales as $sale)
                        <a href="{{ route('sales.show', $sale) }}" class="flex items-center justify-between py-2.5 text-sm hover:bg-slate-50">
                            <div>
                                <p class="font-medium text-slate-800">{{ $sale->sale_number }}</p>
                                <p class="text-xs text-slate-400">{{ $sale->sold_at->format('d/m/Y') }}</p>
                            </div>
                            <div class="text-right">
                                <p class="font-semibold text-slate-800"><x-money :amount="$sale->total_amount" /></p>
                                <x-badge :tone="$sale->payment_status->tone()">{{ $sale->payment_status->label() }}</x-badge>
                            </div>
                        </a>
                    @endforeach
                </div>
            @endif
        </x-card>

        <x-card>
            <h3 class="mb-2 text-sm font-semibold text-slate-700">Factures</h3>
            <x-empty-state icon="invoices" title="Aucune facture pour le moment." description="Le module Facturation arrive en Phase 6." />
        </x-card>
    </div>
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/DashboardController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use App\Models\Customer;
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

        // Les dépenses arrivent en Phase 5 : le résultat estimé reste donc
        // uniquement basé sur le chiffre d'affaires pour l'instant.
        $expensesMonth = 0;

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

        return view('dashboard', compact('company', 'kpis', 'lowStockProducts', 'recentSales'));
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
}
PARALLELIUM_FILE_EOF

echo "Termine. Lance maintenant :"
echo "  php artisan migrate"
echo "  php artisan db:seed --class=Database\\Seeders\\DemoCompanySeeder"
echo "  php artisan view:clear"
