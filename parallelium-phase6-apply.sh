#!/usr/bin/env bash
#
# Parallelium - Phase 6 (Facturation)
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
# Compatible Git Bash / WSL sous Windows.
set -e
echo "Application des fichiers Phase 6..."

cat > "composer.json" << 'PARALLELIUM_FILE_EOF'
{
    "$schema": "https://getcomposer.org/schema.json",
    "name": "laravel/laravel",
    "type": "project",
    "description": "The skeleton application for the Laravel framework.",
    "keywords": ["laravel", "framework"],
    "license": "MIT",
    "require": {
        "php": "^8.3",
        "barryvdh/laravel-dompdf": "^3.1",
        "laravel/framework": "^12.0",
        "laravel/tinker": "^3.0"
    },
    "require-dev": {
        "fakerphp/faker": "^1.23",
        "laravel/pail": "^1.2.5",
        "laravel/pao": "^1.0.6",
        "laravel/pint": "^1.27",
        "mockery/mockery": "^1.6",
        "nunomaduro/collision": "^8.6",
        "phpunit/phpunit": "^12.5.12"
    },
    "autoload": {
        "psr-4": {
            "App\\": "app/",
            "Database\\Factories\\": "database/factories/",
            "Database\\Seeders\\": "database/seeders/"
        }
    },
    "autoload-dev": {
        "psr-4": {
            "Tests\\": "tests/"
        }
    },
    "scripts": {
        "setup": [
            "composer install",
            "@php -r \"file_exists('.env') || copy('.env.example', '.env');\"",
            "@php artisan key:generate",
            "@php artisan migrate --force",
            "npm install --ignore-scripts",
            "npm run build"
        ],
        "dev": [
            "Composer\\Config::disableProcessTimeout",
            "@php artisan dev"
        ],
        "test": [
            "@php artisan config:clear --ansi @no_additional_args",
            "@php artisan test"
        ],
        "post-autoload-dump": [
            "Illuminate\\Foundation\\ComposerScripts::postAutoloadDump",
            "@php artisan package:discover --ansi"
        ],
        "post-update-cmd": [
            "@php artisan vendor:publish --tag=laravel-assets --ansi --force"
        ],
        "post-root-package-install": [
            "@php -r \"file_exists('.env') || copy('.env.example', '.env');\""
        ],
        "post-create-project-cmd": [
            "@php artisan key:generate --ansi",
            "@php -r \"file_exists('database/database.sqlite') || touch('database/database.sqlite');\"",
            "@php artisan migrate --graceful --ansi"
        ],
        "pre-package-uninstall": [
            "Illuminate\\Foundation\\ComposerScripts::prePackageUninstall"
        ]
    },
    "extra": {
        "laravel": {
            "dont-discover": []
        }
    },
    "config": {
        "optimize-autoloader": true,
        "preferred-install": "dist",
        "sort-packages": true,
        "allow-plugins": {
            "pestphp/pest-plugin": true,
            "php-http/discovery": true
        }
    },
    "minimum-stability": "stable",
    "prefer-stable": true
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Enums"
cat > "app/Enums/InvoiceStatus.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Enums;

enum InvoiceStatus: string
{
    case Draft = 'draft';
    case Issued = 'issued';
    case PartiallyPaid = 'partially_paid';
    case Paid = 'paid';
    case Cancelled = 'cancelled';

    public function label(): string
    {
        return match ($this) {
            self::Draft => 'Brouillon',
            self::Issued => 'Émise',
            self::PartiallyPaid => 'Partiellement payée',
            self::Paid => 'Payée',
            self::Cancelled => 'Annulée',
        };
    }

    public function tone(): string
    {
        return match ($this) {
            self::Draft => 'neutral',
            self::Issued => 'warning',
            self::PartiallyPaid => 'warning',
            self::Paid => 'success',
            self::Cancelled => 'danger',
        };
    }

    /**
     * Le statut de la facture suit toujours celui de la vente liée
     * (source de vérité unique — §64) : jamais géré indépendamment.
     */
    public static function fromSale(PaymentStatus $paymentStatus, SaleStatus $saleStatus): self
    {
        if ($saleStatus === SaleStatus::Cancelled) {
            return self::Cancelled;
        }

        return match ($paymentStatus) {
            PaymentStatus::Paid => self::Paid,
            PaymentStatus::PartiallyPaid => self::PartiallyPaid,
            PaymentStatus::Unpaid => self::Issued,
        };
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "database/migrations"
cat > "database/migrations/2026_01_06_000001_create_invoices_table.php" << 'PARALLELIUM_FILE_EOF'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('invoices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            // Une facture est toujours générée DEPUIS une vente existante
            // (§18) : les montants (sous-total, remise, total, payé, reste)
            // ne sont jamais dupliqués ici, ils sont lus depuis la vente
            // liée — une information saisie une fois est réutilisée
            // partout (§64), jamais resaisie ni copiée.
            $table->foreignId('sale_id')->unique()->constrained()->cascadeOnDelete();
            $table->string('invoice_number');
            $table->string('status')->default('issued'); // draft | issued | partially_paid | paid | cancelled
            $table->timestamp('issued_at')->useCurrent();
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['company_id', 'invoice_number']);
        });

        // La colonne sales.invoice_id existe depuis la Phase 4 (nullable,
        // sans contrainte car la table invoices n'existait pas encore).
        // On ajoute la contrainte maintenant que c'est possible.
        Schema::table('sales', function (Blueprint $table) {
            $table->foreign('invoice_id')->references('id')->on('invoices')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('sales', function (Blueprint $table) {
            $table->dropForeign(['invoice_id']);
        });

        Schema::dropIfExists('invoices');
    }
};
PARALLELIUM_FILE_EOF

mkdir -p "app/Models"
cat > "app/Models/Invoice.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use App\Enums\InvoiceStatus;
use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class Invoice extends Model
{
    use BelongsToCompany, SoftDeletes;

    protected $fillable = ['company_id', 'sale_id', 'invoice_number', 'status', 'issued_at'];

    protected function casts(): array
    {
        return [
            'status' => InvoiceStatus::class,
            'issued_at' => 'datetime',
        ];
    }

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    /**
     * Le statut réel dépend toujours de l'état courant de la vente liée
     * (voir InvoiceStatus::fromSale) — ce champ stocké sert seulement à
     * afficher la liste rapidement sans recharger chaque vente.
     */
    public function refreshStatus(): void
    {
        $this->update([
            'status' => InvoiceStatus::fromSale($this->sale->payment_status, $this->sale->sale_status),
        ]);
    }
}
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
use Illuminate\Database\Eloquent\Relations\HasOne;
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

    public function invoice(): HasOne
    {
        return $this->hasOne(Invoice::class);
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

mkdir -p "app/Services"
cat > "app/Services/InvoiceService.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Services;

use App\Enums\InvoiceStatus;
use App\Models\Invoice;
use App\Models\Sale;
use App\Support\Tenant;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * Génère une facture DEPUIS une vente existante (§18). Une vente ne peut
 * avoir qu'une seule facture (contrainte unique sale_id) : appeler ceci
 * une deuxième fois renvoie simplement la facture déjà émise plutôt que
 * d'en créer une autre — jamais de doublon.
 */
class InvoiceService
{
    public function generateFor(Sale $sale): Invoice
    {
        if ($sale->invoice) {
            return $sale->invoice;
        }

        if ($sale->isCancelled()) {
            throw new RuntimeException('Impossible de facturer une vente annulée.');
        }

        return DB::transaction(function () use ($sale) {
            $company = Tenant::current();

            $invoice = Invoice::create([
                'company_id' => $company->id,
                'sale_id' => $sale->id,
                'invoice_number' => $company->nextDocumentNumber('invoice'),
                'status' => InvoiceStatus::fromSale($sale->payment_status, $sale->sale_status),
                'issued_at' => now(),
            ]);

            $sale->update(['invoice_id' => $invoice->id]);

            return $invoice;
        });
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/InvoiceController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use App\Models\Invoice;
use App\Models\Sale;
use App\Services\InvoiceService;
use Barryvdh\DomPDF\Facade\Pdf;

class InvoiceController extends Controller
{
    public function index()
    {
        $this->authorize('invoices.view');

        $invoices = Invoice::with(['sale.customer'])
            ->latest('issued_at')
            ->paginate(15);

        return view('invoices.index', compact('invoices'));
    }

    public function generate(Sale $sale, InvoiceService $invoiceService)
    {
        $this->authorize('invoices.create');

        $invoice = $invoiceService->generateFor($sale);

        return redirect()->route('invoices.show', $invoice)->with('status', 'Facture générée.');
    }

    public function show(Invoice $invoice)
    {
        $this->authorize('invoices.view');

        $invoice->load(['sale.items.product', 'sale.customer']);

        return view('invoices.show', compact('invoice'));
    }

    public function download(Invoice $invoice)
    {
        $this->authorize('invoices.view');

        $invoice->load(['sale.items.product', 'sale.customer']);
        $company = $invoice->company;

        $pdf = Pdf::loadView('pdf.invoice', compact('invoice', 'company'))->setPaper('a4');

        return $pdf->download("{$invoice->invoice_number}.pdf");
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "tests/Feature"
cat > "tests/Feature/InvoiceTest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Services\InvoiceService;
use App\Services\SaleService;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use RuntimeException;
use Tests\TestCase;

class InvoiceTest extends TestCase
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

    public function test_generating_an_invoice_from_a_sale_uses_the_company_prefix_and_year(): void
    {
        $company = Company::factory()->create(['invoice_prefix' => 'PAR']);
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 10, 'selling_price' => 1000]);
        $sale = app(SaleService::class)->create([
            'items' => [['product_id' => $product->id, 'quantity' => 2]],
            'paid_amount' => 2000,
            'payment_method' => 'cash',
        ], $owner);

        $invoice = app(InvoiceService::class)->generateFor($sale);

        $this->assertStringStartsWith('PAR-'.now()->year.'-', $invoice->invoice_number);
        $this->assertEquals('paid', $invoice->status->value);
        $this->assertEquals($invoice->id, $sale->fresh()->invoice_id);
    }

    public function test_generating_an_invoice_twice_returns_the_same_invoice(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 10, 'selling_price' => 1000]);
        $sale = app(SaleService::class)->create([
            'items' => [['product_id' => $product->id, 'quantity' => 1]],
            'paid_amount' => 0,
            'payment_method' => 'cash',
        ], $owner);

        $invoiceService = app(InvoiceService::class);
        $first = $invoiceService->generateFor($sale);
        $second = $invoiceService->generateFor($sale->fresh());

        $this->assertEquals($first->id, $second->id);
        $this->assertDatabaseCount('invoices', 1);
    }

    public function test_a_cancelled_sale_cannot_be_invoiced(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 10, 'selling_price' => 1000]);
        $saleService = app(SaleService::class);
        $sale = $saleService->create([
            'items' => [['product_id' => $product->id, 'quantity' => 1]],
            'paid_amount' => 1000,
            'payment_method' => 'cash',
        ], $owner);
        $saleService->cancel($sale, $owner);

        $this->expectException(RuntimeException::class);
        app(InvoiceService::class)->generateFor($sale->fresh());
    }

    public function test_invoice_numbers_are_unique_per_company_and_independent_between_companies(): void
    {
        $companyA = Company::factory()->create(['invoice_prefix' => 'PAR']);
        $companyB = Company::factory()->create(['invoice_prefix' => 'PAR']);
        $ownerA = $this->ownerFor($companyA);
        $ownerB = $this->ownerFor($companyB);

        $productA = Product::factory()->create(['company_id' => $companyA->id, 'stock_quantity' => 10, 'selling_price' => 1000]);
        $productB = Product::factory()->create(['company_id' => $companyB->id, 'stock_quantity' => 10, 'selling_price' => 1000]);

        $this->actingAs($ownerA);
        $saleA = app(SaleService::class)->create(['items' => [['product_id' => $productA->id, 'quantity' => 1]], 'paid_amount' => 1000, 'payment_method' => 'cash'], $ownerA);
        $invoiceA = app(InvoiceService::class)->generateFor($saleA);

        $this->actingAs($ownerB);
        $saleB = app(SaleService::class)->create(['items' => [['product_id' => $productB->id, 'quantity' => 1]], 'paid_amount' => 1000, 'payment_method' => 'cash'], $ownerB);
        $invoiceB = app(InvoiceService::class)->generateFor($saleB);

        // Chaque entreprise numérote depuis 1, indépendamment de l'autre.
        $this->assertStringEndsWith('000001', $invoiceA->invoice_number);
        $this->assertStringEndsWith('000001', $invoiceB->invoice_number);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/invoices"
cat > "resources/views/invoices/index.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Factures">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Factures</h2>
        <p class="text-sm text-slate-500">{{ $invoices->total() }} facture{{ $invoices->total() > 1 ? 's' : '' }} émise{{ $invoices->total() > 1 ? 's' : '' }}.</p>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
    @endif

    @if ($invoices->isEmpty())
        <x-empty-state icon="invoices" title="Aucune facture pour le moment." description="Générez une facture depuis le détail d'une vente." />
    @else
        <x-card :padded="false">
            <div class="divide-y divide-slate-100">
                @foreach ($invoices as $invoice)
                    <a href="{{ route('invoices.show', $invoice) }}" class="flex items-center justify-between gap-3 px-5 py-3 hover:bg-slate-50">
                        <div class="min-w-0">
                            <p class="truncate text-sm font-semibold text-slate-800">{{ $invoice->invoice_number }}</p>
                            <p class="text-xs text-slate-400">
                                {{ $invoice->sale->customer?->name ?? 'Client de passage' }} · {{ $invoice->issued_at->format('d/m/Y') }}
                            </p>
                        </div>
                        <div class="shrink-0 text-right">
                            <p class="text-sm font-bold text-slate-900"><x-money :amount="$invoice->sale->total_amount" /></p>
                            <x-badge :tone="$invoice->status->tone()">{{ $invoice->status->label() }}</x-badge>
                        </div>
                    </a>
                @endforeach
            </div>
        </x-card>

        <div class="mt-5">{{ $invoices->links() }}</div>
    @endif
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/invoices"
cat > "resources/views/invoices/show.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="{{ $invoice->invoice_number }}">
    <div class="mb-5 flex flex-wrap items-start justify-between gap-3 print:hidden">
        <div>
            <h2 class="text-xl font-bold text-slate-900">{{ $invoice->invoice_number }}</h2>
            <p class="text-sm text-slate-500">Émise le {{ $invoice->issued_at->format('d/m/Y') }}</p>
        </div>

        <div class="flex items-center gap-2">
            <x-button :href="route('invoices.download', $invoice)" variant="secondary" size="sm">Télécharger le PDF</x-button>
            <x-button variant="ghost" size="sm" onclick="window.print()">Imprimer</x-button>
            <x-button :href="route('sales.show', $invoice->sale)" variant="ghost" size="sm">Voir la vente</x-button>
        </div>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4 print:hidden">{{ session('status') }}</x-alert>
    @endif

    <x-card>
        <div class="flex items-start justify-between border-b border-slate-100 pb-4">
            <div>
                <p class="text-lg font-bold text-slate-900">{{ auth()->user()->company->name }}</p>
                @if (auth()->user()->company->address)
                    <p class="text-xs text-slate-400">{{ auth()->user()->company->address }}</p>
                @endif
                @if (auth()->user()->company->phone)
                    <p class="text-xs text-slate-400">{{ auth()->user()->company->phone }}</p>
                @endif
            </div>
            <div class="text-right">
                <p class="font-bold text-brand-700">FACTURE</p>
                <p class="text-sm text-slate-500">{{ $invoice->invoice_number }}</p>
                <x-badge :tone="$invoice->status->tone()" class="mt-1">{{ $invoice->status->label() }}</x-badge>
            </div>
        </div>

        <div class="border-b border-slate-100 py-4 text-sm">
            <p class="font-medium text-slate-600">Facturé à</p>
            <p class="text-slate-800">{{ $invoice->sale->customer?->name ?? 'Client de passage' }}</p>
            @if ($invoice->sale->customer?->phone)
                <p class="text-xs text-slate-400">{{ $invoice->sale->customer->phone }}</p>
            @endif
            @if ($invoice->sale->customer?->address)
                <p class="text-xs text-slate-400">{{ $invoice->sale->customer->address }}</p>
            @endif
        </div>

        <div class="divide-y divide-slate-100 py-2">
            @foreach ($invoice->sale->items as $item)
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
                <span><x-money :amount="$invoice->sale->subtotal" /></span>
            </div>
            @if ($invoice->sale->discount > 0)
                <div class="flex justify-between text-slate-500">
                    <span>Remise</span>
                    <span>- <x-money :amount="$invoice->sale->discount" /></span>
                </div>
            @endif
            <div class="flex justify-between text-base font-bold text-slate-900">
                <span>Total</span>
                <span><x-money :amount="$invoice->sale->total_amount" /></span>
            </div>
            <div class="flex justify-between text-slate-500">
                <span>Payé</span>
                <span><x-money :amount="$invoice->sale->paid_amount" /></span>
            </div>
            @if ($invoice->sale->remaining_amount > 0)
                <div class="flex justify-between font-semibold text-amber-600">
                    <span>Reste à payer</span>
                    <span><x-money :amount="$invoice->sale->remaining_amount" /></span>
                </div>
            @endif
        </div>
    </x-card>
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/pdf"
cat > "resources/views/pdf/invoice.blade.php" << 'PARALLELIUM_FILE_EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <title>{{ $invoice->invoice_number }}</title>
    <style>
        body { font-family: DejaVu Sans, sans-serif; color: #1e293b; font-size: 12px; }
        .header { width: 100%; margin-bottom: 20px; }
        .header td { vertical-align: top; }
        .company-name { font-size: 16px; font-weight: bold; color: #1f1650; }
        .muted { color: #64748b; font-size: 10px; }
        .invoice-title { font-size: 18px; font-weight: bold; color: #6a35c2; text-align: right; }
        .invoice-number { text-align: right; color: #64748b; }
        .status { display: inline-block; padding: 3px 10px; border-radius: 10px; font-size: 10px; font-weight: bold; float: right; margin-top: 4px; }
        .status-paid { background: #d1fae5; color: #065f46; }
        .status-partially_paid, .status-issued { background: #fef3c7; color: #92400e; }
        .status-cancelled { background: #fee2e2; color: #991b1b; }
        .section { border-top: 1px solid #e2e8f0; padding: 12px 0; }
        table.items { width: 100%; border-collapse: collapse; margin-top: 10px; }
        table.items th { text-align: left; font-size: 10px; color: #64748b; border-bottom: 1px solid #e2e8f0; padding: 6px 0; }
        table.items td { padding: 8px 0; border-bottom: 1px solid #f1f5f9; }
        table.totals { width: 260px; margin-left: auto; margin-top: 15px; }
        table.totals td { padding: 4px 0; }
        table.totals .label { color: #64748b; }
        table.totals .value { text-align: right; }
        .total-row td { font-weight: bold; font-size: 14px; border-top: 1px solid #e2e8f0; padding-top: 8px; }
        .remaining { color: #b45309; font-weight: bold; }
        .footer { margin-top: 40px; text-align: center; color: #94a3b8; font-size: 9px; }
    </style>
</head>
<body>
    <table class="header">
        <tr>
            <td style="width: 60%;">
                <div class="company-name">{{ $company->name }}</div>
                @if ($company->address)<div class="muted">{{ $company->address }}</div>@endif
                @if ($company->phone)<div class="muted">{{ $company->phone }}</div>@endif
                @if ($company->email)<div class="muted">{{ $company->email }}</div>@endif
            </td>
            <td style="width: 40%;">
                <div class="invoice-title">FACTURE</div>
                <div class="invoice-number">{{ $invoice->invoice_number }}</div>
                <div class="invoice-number">{{ $invoice->issued_at->format('d/m/Y') }}</div>
                <span class="status status-{{ $invoice->status->value }}">{{ $invoice->status->label() }}</span>
            </td>
        </tr>
    </table>

    <div class="section">
        <strong>Facturé à</strong><br>
        {{ $invoice->sale->customer?->name ?? 'Client de passage' }}<br>
        @if ($invoice->sale->customer?->phone)<span class="muted">{{ $invoice->sale->customer->phone }}</span><br>@endif
        @if ($invoice->sale->customer?->address)<span class="muted">{{ $invoice->sale->customer->address }}</span>@endif
    </div>

    <table class="items">
        <thead>
            <tr>
                <th>Produit</th>
                <th>Qté</th>
                <th>Prix unitaire</th>
                <th style="text-align: right;">Sous-total</th>
            </tr>
        </thead>
        <tbody>
            @foreach ($invoice->sale->items as $item)
                <tr>
                    <td>{{ $item->product->name ?? 'Produit supprimé' }}</td>
                    <td>{{ $item->quantity }}</td>
                    <td>{{ \App\Support\Money::format($item->unit_price, $company->currency) }}</td>
                    <td style="text-align: right;">{{ \App\Support\Money::format($item->subtotal, $company->currency) }}</td>
                </tr>
            @endforeach
        </tbody>
    </table>

    <table class="totals">
        <tr>
            <td class="label">Sous-total</td>
            <td class="value">{{ \App\Support\Money::format($invoice->sale->subtotal, $company->currency) }}</td>
        </tr>
        @if ($invoice->sale->discount > 0)
            <tr>
                <td class="label">Remise</td>
                <td class="value">- {{ \App\Support\Money::format($invoice->sale->discount, $company->currency) }}</td>
            </tr>
        @endif
        <tr class="total-row">
            <td>Total</td>
            <td class="value">{{ \App\Support\Money::format($invoice->sale->total_amount, $company->currency) }}</td>
        </tr>
        <tr>
            <td class="label">Payé</td>
            <td class="value">{{ \App\Support\Money::format($invoice->sale->paid_amount, $company->currency) }}</td>
        </tr>
        @if ($invoice->sale->remaining_amount > 0)
            <tr>
                <td class="label remaining">Reste à payer</td>
                <td class="value remaining">{{ \App\Support\Money::format($invoice->sale->remaining_amount, $company->currency) }}</td>
            </tr>
        @endif
    </table>

    <div class="footer">
        Ce document est un indicateur de gestion interne, généré par Parallelium. Il ne constitue pas un document comptable officiel.
    </div>
</body>
</html>
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
            @can('invoices.view')
                @if ($sale->invoice)
                    <x-button :href="route('invoices.show', $sale->invoice)" variant="secondary" size="sm">Voir la facture</x-button>
                @elseif (! $sale->isCancelled())
                    @can('invoices.create')
                        <form method="POST" action="{{ route('invoices.generate', $sale) }}">
                            @csrf
                            <x-button type="submit" variant="secondary" size="sm">Générer la facture</x-button>
                        </form>
                    @endcan
                @endif
            @endcan
            <x-button variant="ghost" size="sm" onclick="window.print()">Imprimer le reçu</x-button>
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
            @php($invoices = \App\Models\Invoice::whereHas('sale', fn ($q) => $q->where('customer_id', $customer->id))->with('sale')->latest('issued_at')->limit(8)->get())
            @if ($invoices->isEmpty())
                <x-empty-state icon="invoices" title="Aucune facture pour le moment." description="Générez une facture depuis une vente de ce client." />
            @else
                <div class="divide-y divide-slate-100">
                    @foreach ($invoices as $invoice)
                        <a href="{{ route('invoices.show', $invoice) }}" class="flex items-center justify-between py-2.5 text-sm hover:bg-slate-50">
                            <div>
                                <p class="font-medium text-slate-800">{{ $invoice->invoice_number }}</p>
                                <p class="text-xs text-slate-400">{{ $invoice->issued_at->format('d/m/Y') }}</p>
                            </div>
                            <x-badge :tone="$invoice->status->tone()">{{ $invoice->status->label() }}</x-badge>
                        </a>
                    @endforeach
                </div>
            @endif
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

        // Les modules suivants (rapports, employés, paramètres) sont
        // ajoutés phase par phase — voir le cahier des charges §56.
    });
});
PARALLELIUM_FILE_EOF

echo "Termine. Lance maintenant :"
echo "  composer require barryvdh/laravel-dompdf"
echo "  php artisan migrate"
echo "  php artisan view:clear"
