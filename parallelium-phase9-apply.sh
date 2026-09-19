#!/usr/bin/env bash
#
# Parallelium - Phase 9 (Rapports)
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
# Compatible Git Bash / WSL sous Windows.
set -e
echo "Application des fichiers Phase 9..."

mkdir -p "app/Services"
cat > "app/Services/ReportService.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Services;

use App\Enums\ExpenseCategory;
use App\Models\Customer;
use App\Models\Expense;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Support\Tenant;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

/**
 * Rapports simples (§22) : ventes, dépenses, produits, clients.
 * Toutes les périodes sont résolues côté serveur — jamais de dates
 * envoyées telles quelles sans validation.
 */
class ReportService
{
    /**
     * @return array{0: Carbon, 1: Carbon, 2: string}
     */
    public function resolvePeriod(Request $request): array
    {
        $period = $request->string('period', 'month')->toString();

        return match ($period) {
            'today' => [today()->startOfDay(), today()->endOfDay(), "aujourd'hui"],
            'week' => [now()->startOfWeek(), now()->endOfWeek(), 'cette semaine'],
            'custom' => [
                $request->filled('from') ? Carbon::parse($request->date('from'))->startOfDay() : now()->startOfMonth(),
                $request->filled('to') ? Carbon::parse($request->date('to'))->endOfDay() : now()->endOfDay(),
                'période personnalisée',
            ],
            default => [now()->startOfMonth(), now()->endOfMonth(), 'ce mois'],
        };
    }

    public function salesReport(Carbon $from, Carbon $to): array
    {
        $sales = Sale::completed()->whereBetween('sold_at', [$from, $to]);

        return [
            'count' => (clone $sales)->count(),
            'revenue' => (clone $sales)->sum('total_amount'),
            'paid' => (clone $sales)->sum('paid_amount'),
            'remaining' => (clone $sales)->sum('remaining_amount'),
            'rows' => (clone $sales)->with('customer')->latest('sold_at')->get(),
        ];
    }

    public function expensesReport(Carbon $from, Carbon $to): array
    {
        $expenses = Expense::whereBetween('expense_date', [$from, $to]);

        $byCategory = (clone $expenses)
            ->selectRaw('category, SUM(amount) as total, COUNT(*) as count')
            ->groupBy('category')
            ->orderByDesc('total')
            ->get()
            ->map(fn ($row) => [
                'label' => $row->category->label(),
                'total' => (float) $row->total,
                'count' => (int) $row->count,
            ]);

        return [
            'total' => (clone $expenses)->sum('amount'),
            'count' => (clone $expenses)->count(),
            'byCategory' => $byCategory,
            'rows' => (clone $expenses)->latest('expense_date')->get(),
        ];
    }

    public function productsReport(Carbon $from, Carbon $to): array
    {
        $rows = SaleItem::query()
            ->join('sales', 'sales.id', '=', 'sale_items.sale_id')
            ->join('products', 'products.id', '=', 'sale_items.product_id')
            ->where('sales.company_id', Tenant::id())
            ->where('sales.sale_status', 'completed')
            ->whereBetween('sales.sold_at', [$from, $to])
            ->selectRaw('products.id, products.name, SUM(sale_items.quantity) as quantity, SUM(sale_items.subtotal) as revenue')
            ->groupBy('products.id', 'products.name')
            ->orderByDesc('revenue')
            ->get();

        return [
            'rows' => $rows,
            'totalQuantity' => (int) $rows->sum('quantity'),
            'totalRevenue' => (float) $rows->sum('revenue'),
        ];
    }

    public function customersReport(Carbon $from, Carbon $to): array
    {
        $rows = Customer::query()
            ->withSum(['sales as period_revenue' => function ($q) use ($from, $to) {
                $q->completed()->whereBetween('sold_at', [$from, $to]);
            }], 'total_amount')
            ->withSum(['sales as period_remaining' => function ($q) use ($from, $to) {
                $q->completed()->whereBetween('sold_at', [$from, $to]);
            }], 'remaining_amount')
            ->withCount(['sales as period_sales_count' => function ($q) use ($from, $to) {
                $q->completed()->whereBetween('sold_at', [$from, $to]);
            }])
            ->having('period_sales_count', '>', 0)
            ->orderByDesc('period_revenue')
            ->get();

        return [
            'rows' => $rows,
            'totalRevenue' => (float) $rows->sum('period_revenue'),
            'totalRemaining' => (float) $rows->sum('period_remaining'),
        ];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/ReportController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use App\Services\ReportService;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ReportController extends Controller
{
    public function index()
    {
        $this->authorize('reports.view');

        return view('reports.index');
    }

    public function sales(Request $request, ReportService $reportService)
    {
        $this->authorize('reports.view');

        [$from, $to, $periodLabel] = $reportService->resolvePeriod($request);
        $report = $reportService->salesReport($from, $to);

        if ($request->query('export') === 'csv') {
            return $this->csv('rapport-ventes', ['Date', 'Numéro', 'Client', 'Total', 'Payé', 'Reste', 'Statut'],
                $report['rows']->map(fn ($sale) => [
                    $sale->sold_at->format('d/m/Y H:i'),
                    $sale->sale_number,
                    $sale->customer?->name ?? 'Client de passage',
                    $sale->total_amount,
                    $sale->paid_amount,
                    $sale->remaining_amount,
                    $sale->payment_status->label(),
                ])
            );
        }

        if ($request->query('export') === 'pdf') {
            $pdf = Pdf::loadView('pdf.report-sales', compact('report', 'periodLabel', 'from', 'to'))->setPaper('a4');

            return $pdf->download('rapport-ventes.pdf');
        }

        return view('reports.sales', compact('report', 'periodLabel', 'from', 'to'));
    }

    public function expenses(Request $request, ReportService $reportService)
    {
        $this->authorize('reports.view');

        [$from, $to, $periodLabel] = $reportService->resolvePeriod($request);
        $report = $reportService->expensesReport($from, $to);

        if ($request->query('export') === 'csv') {
            return $this->csv('rapport-depenses', ['Date', 'Catégorie', 'Fournisseur', 'Montant', 'Paiement'],
                $report['rows']->map(fn ($expense) => [
                    $expense->expense_date->format('d/m/Y'),
                    $expense->category->label(),
                    $expense->supplier_name ?? '—',
                    $expense->amount,
                    $expense->payment_method->label(),
                ])
            );
        }

        return view('reports.expenses', compact('report', 'periodLabel', 'from', 'to'));
    }

    public function products(Request $request, ReportService $reportService)
    {
        $this->authorize('reports.view');

        [$from, $to, $periodLabel] = $reportService->resolvePeriod($request);
        $report = $reportService->productsReport($from, $to);

        if ($request->query('export') === 'csv') {
            return $this->csv('rapport-produits', ['Produit', 'Quantité vendue', 'Chiffre d\'affaires'],
                $report['rows']->map(fn ($row) => [$row->name, $row->quantity, $row->revenue])
            );
        }

        return view('reports.products', compact('report', 'periodLabel', 'from', 'to'));
    }

    public function customers(Request $request, ReportService $reportService)
    {
        $this->authorize('reports.view');

        [$from, $to, $periodLabel] = $reportService->resolvePeriod($request);
        $report = $reportService->customersReport($from, $to);

        if ($request->query('export') === 'csv') {
            return $this->csv('rapport-clients', ['Client', 'Ventes', 'Chiffre d\'affaires', 'Reste dû'],
                $report['rows']->map(fn ($c) => [$c->name, $c->period_sales_count, $c->period_revenue, $c->period_remaining ?? 0])
            );
        }

        return view('reports.customers', compact('report', 'periodLabel', 'from', 'to'));
    }

    /**
     * Génère un CSV en flux (pas de fichier temporaire sur le serveur).
     * Les montants restent des nombres bruts (pas de symbole monétaire)
     * pour rester exploitables dans un tableur.
     */
    protected function csv(string $filename, array $headers, iterable $rows): StreamedResponse
    {
        return response()->streamDownload(function () use ($headers, $rows) {
            $handle = fopen('php://output', 'w');
            fwrite($handle, "\xEF\xBB\xBF"); // BOM UTF-8 (Excel)
            fputcsv($handle, $headers, ';');
            foreach ($rows as $row) {
                fputcsv($handle, $row, ';');
            }
            fclose($handle);
        }, "{$filename}-".now()->format('Y-m-d').'.csv', ['Content-Type' => 'text/csv; charset=UTF-8']);
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "tests/Feature"
cat > "tests/Feature/ReportTest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Expense;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Services\ReportService;
use App\Services\SaleService;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ReportTest extends TestCase
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

    public function test_sales_report_totals_match_completed_sales_in_period(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        $product = Product::factory()->create(['company_id' => $company->id, 'stock_quantity' => 10, 'selling_price' => 5000]);
        app(SaleService::class)->create([
            'items' => [['product_id' => $product->id, 'quantity' => 2]],
            'paid_amount' => 6000,
            'payment_method' => 'cash',
        ], $owner);

        $report = app(ReportService::class)->salesReport(now()->startOfMonth(), now()->endOfMonth());

        $this->assertEquals(1, $report['count']);
        $this->assertEquals(10000, $report['revenue']);
        $this->assertEquals(6000, $report['paid']);
        $this->assertEquals(4000, $report['remaining']);
    }

    public function test_products_report_does_not_leak_across_companies(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();
        $ownerA = $this->ownerFor($companyA);
        $ownerB = $this->ownerFor($companyB);

        $productA = Product::factory()->create(['company_id' => $companyA->id, 'stock_quantity' => 10, 'selling_price' => 1000, 'name' => 'Produit A']);
        $productB = Product::factory()->create(['company_id' => $companyB->id, 'stock_quantity' => 10, 'selling_price' => 1000, 'name' => 'Produit B']);

        $this->actingAs($ownerB);
        app(SaleService::class)->create(['items' => [['product_id' => $productB->id, 'quantity' => 1]], 'paid_amount' => 1000, 'payment_method' => 'cash'], $ownerB);

        $this->actingAs($ownerA);
        app(SaleService::class)->create(['items' => [['product_id' => $productA->id, 'quantity' => 1]], 'paid_amount' => 1000, 'payment_method' => 'cash'], $ownerA);

        $report = app(ReportService::class)->productsReport(now()->startOfMonth(), now()->endOfMonth());

        $this->assertCount(1, $report['rows']);
        $this->assertEquals('Produit A', $report['rows']->first()->name);
    }

    public function test_expenses_report_groups_by_category(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        Expense::factory()->create(['company_id' => $company->id, 'category' => 'transport', 'amount' => 10000, 'expense_date' => now()]);
        Expense::factory()->create(['company_id' => $company->id, 'category' => 'transport', 'amount' => 5000, 'expense_date' => now()]);
        Expense::factory()->create(['company_id' => $company->id, 'category' => 'rent', 'amount' => 300000, 'expense_date' => now()]);

        $report = app(ReportService::class)->expensesReport(now()->startOfMonth(), now()->endOfMonth());

        $this->assertEquals(315000, $report['total']);
        $transport = $report['byCategory']->firstWhere('label', 'Transport');
        $this->assertEquals(15000, $transport['total']);
        $this->assertEquals(2, $transport['count']);
    }

    public function test_csv_export_is_downloadable_by_an_authorized_user(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);

        $response = $this->actingAs($owner)->get(route('reports.sales', ['export' => 'csv']));

        $response->assertOk();
        $response->assertHeader('content-type', 'text/csv; charset=UTF-8');
    }

    public function test_a_seller_cannot_access_reports(): void
    {
        $company = Company::factory()->create();
        $sellerRole = Role::whereNull('company_id')->where('slug', 'seller')->first();
        $seller = User::factory()->create(['company_id' => $company->id, 'role_id' => $sellerRole->id]);

        $this->actingAs($seller)->get(route('reports.index'))->assertForbidden();
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/components"
cat > "resources/views/components/report-period-filter.blade.php" << 'PARALLELIUM_FILE_EOF'
@props(['route'])

<form method="GET" x-data="{ period: '{{ request('period', 'month') }}' }" class="mb-5 flex flex-wrap items-center gap-2">
    <div class="flex rounded-xl border border-slate-200 p-1">
        @foreach (['today' => "Aujourd'hui", 'week' => 'Cette semaine', 'month' => 'Ce mois', 'custom' => 'Personnalisé'] as $value => $label)
            <label class="cursor-pointer rounded-lg px-3 py-1.5 text-sm font-medium transition"
                   :class="period === '{{ $value }}' ? 'bg-brand-gradient text-white' : 'text-slate-500 hover:bg-slate-50'">
                <input type="radio" name="period" value="{{ $value }}" x-model="period" class="hidden" @change="$el.closest('form').submit()">
                {{ $label }}
            </label>
        @endforeach
    </div>

    <template x-if="period === 'custom'">
        <div class="flex items-center gap-2">
            <input type="date" name="from" value="{{ request('from') }}" class="rounded-xl border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400">
            <span class="text-slate-400"><x-icon name="chevron-right" class="text-xs" /></span>
            <input type="date" name="to" value="{{ request('to') }}" class="rounded-xl border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400">
            <x-button type="submit" size="sm" variant="ghost">Appliquer</x-button>
        </div>
    </template>
</form>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/reports"
cat > "resources/views/reports/index.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Rapports">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Rapports</h2>
        <p class="text-sm text-slate-500">Analysez vos ventes, dépenses, produits et clients par période.</p>
    </div>

    <div class="grid gap-3 sm:grid-cols-2">
        <a href="{{ route('reports.sales') }}">
            <x-card class="h-full transition hover:border-brand-200 hover:shadow-md">
                <div class="flex items-center gap-3">
                    <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-brand-50 text-brand-600"><x-icon name="sales" /></span>
                    <div>
                        <p class="font-semibold text-slate-800">Rapport des ventes</p>
                        <p class="text-xs text-slate-400">Nombre de ventes, CA, payé, reste à payer</p>
                    </div>
                </div>
            </x-card>
        </a>

        <a href="{{ route('reports.expenses') }}">
            <x-card class="h-full transition hover:border-brand-200 hover:shadow-md">
                <div class="flex items-center gap-3">
                    <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-brand-50 text-brand-600"><x-icon name="expenses" /></span>
                    <div>
                        <p class="font-semibold text-slate-800">Rapport des dépenses</p>
                        <p class="text-xs text-slate-400">Total, répartition par catégorie</p>
                    </div>
                </div>
            </x-card>
        </a>

        <a href="{{ route('reports.products') }}">
            <x-card class="h-full transition hover:border-brand-200 hover:shadow-md">
                <div class="flex items-center gap-3">
                    <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-brand-50 text-brand-600"><x-icon name="products" /></span>
                    <div>
                        <p class="font-semibold text-slate-800">Rapport produits</p>
                        <p class="text-xs text-slate-400">Produits vendus, quantités, chiffre d'affaires</p>
                    </div>
                </div>
            </x-card>
        </a>

        <a href="{{ route('reports.customers') }}">
            <x-card class="h-full transition hover:border-brand-200 hover:shadow-md">
                <div class="flex items-center gap-3">
                    <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-brand-50 text-brand-600"><x-icon name="customers" /></span>
                    <div>
                        <p class="font-semibold text-slate-800">Rapport clients</p>
                        <p class="text-xs text-slate-400">Clients les plus actifs, créances</p>
                    </div>
                </div>
            </x-card>
        </a>
    </div>
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/reports"
cat > "resources/views/reports/sales.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Rapport des ventes">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Rapport des ventes</h2>
            <p class="text-sm text-slate-500">{{ ucfirst($periodLabel) }} — du {{ $from->format('d/m/Y') }} au {{ $to->format('d/m/Y') }}</p>
        </div>
        <div class="flex items-center gap-2">
            <x-button :href="route('reports.sales', array_merge(request()->query(), ['export' => 'csv']))" variant="secondary" size="sm">Export CSV</x-button>
            <x-button :href="route('reports.sales', array_merge(request()->query(), ['export' => 'pdf']))" variant="ghost" size="sm">Export PDF</x-button>
        </div>
    </div>

    <x-report-period-filter route="reports.sales" />

    <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <x-stat-card label="Nombre de ventes" :value="$report['count']" icon="sales" />
        <x-stat-card label="Chiffre d'affaires" :value="\App\Support\Money::format($report['revenue'])" icon="money" />
        <x-stat-card label="Montant payé" :value="\App\Support\Money::format($report['paid'])" icon="revenue" />
        <x-stat-card label="Reste à payer" :value="\App\Support\Money::format($report['remaining'])" icon="credit" />
    </div>

    <div class="mt-6">
        @if ($report['rows']->isEmpty())
            <x-empty-state icon="sales" title="Aucune vente sur cette période." />
        @else
            <x-card :padded="false">
                <div class="divide-y divide-slate-100">
                    @foreach ($report['rows'] as $sale)
                        <a href="{{ route('sales.show', $sale) }}" class="flex items-center justify-between gap-3 px-5 py-3 hover:bg-slate-50">
                            <div class="min-w-0">
                                <p class="truncate text-sm font-semibold text-slate-800">{{ $sale->sale_number }}</p>
                                <p class="text-xs text-slate-400">{{ $sale->customer?->name ?? 'Client de passage' }} · {{ $sale->sold_at->format('d/m/Y H:i') }}</p>
                            </div>
                            <div class="shrink-0 text-right">
                                <p class="text-sm font-bold text-slate-900"><x-money :amount="$sale->total_amount" /></p>
                                <x-badge :tone="$sale->payment_status->tone()">{{ $sale->payment_status->label() }}</x-badge>
                            </div>
                        </a>
                    @endforeach
                </div>
            </x-card>
        @endif
    </div>
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/reports"
cat > "resources/views/reports/expenses.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Rapport des dépenses">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Rapport des dépenses</h2>
            <p class="text-sm text-slate-500">{{ ucfirst($periodLabel) }} — du {{ $from->format('d/m/Y') }} au {{ $to->format('d/m/Y') }}</p>
        </div>
        <x-button :href="route('reports.expenses', array_merge(request()->query(), ['export' => 'csv']))" variant="secondary" size="sm">Export CSV</x-button>
    </div>

    <x-report-period-filter route="reports.expenses" />

    <div class="grid grid-cols-2 gap-3">
        <x-stat-card label="Total des dépenses" :value="\App\Support\Money::format($report['total'])" icon="expenses" />
        <x-stat-card label="Nombre de dépenses" :value="$report['count']" icon="money" />
    </div>

    @if ($report['byCategory']->isNotEmpty())
        <x-card class="mt-4">
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Répartition par catégorie</h3>
            <div class="space-y-2">
                @foreach ($report['byCategory'] as $cat)
                    <div class="flex items-center justify-between text-sm">
                        <span class="text-slate-600">{{ $cat['label'] }} <span class="text-slate-400">({{ $cat['count'] }})</span></span>
                        <span class="font-semibold text-slate-800"><x-money :amount="$cat['total']" /></span>
                    </div>
                @endforeach
            </div>
        </x-card>
    @endif

    <div class="mt-6">
        @if ($report['rows']->isEmpty())
            <x-empty-state icon="expenses" title="Aucune dépense sur cette période." />
        @else
            <x-card :padded="false">
                <div class="divide-y divide-slate-100">
                    @foreach ($report['rows'] as $expense)
                        <div class="flex items-center justify-between gap-3 px-5 py-3">
                            <div class="min-w-0">
                                <p class="truncate text-sm font-semibold text-slate-800">{{ $expense->category->label() }}</p>
                                <p class="text-xs text-slate-400">{{ $expense->supplier_name ?? 'Sans fournisseur' }} · {{ $expense->expense_date->format('d/m/Y') }}</p>
                            </div>
                            <p class="shrink-0 font-semibold text-slate-900"><x-money :amount="$expense->amount" /></p>
                        </div>
                    @endforeach
                </div>
            </x-card>
        @endif
    </div>
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/reports"
cat > "resources/views/reports/products.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Rapport produits">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Rapport produits</h2>
            <p class="text-sm text-slate-500">{{ ucfirst($periodLabel) }} — du {{ $from->format('d/m/Y') }} au {{ $to->format('d/m/Y') }}</p>
        </div>
        <x-button :href="route('reports.products', array_merge(request()->query(), ['export' => 'csv']))" variant="secondary" size="sm">Export CSV</x-button>
    </div>

    <x-report-period-filter route="reports.products" />

    <div class="grid grid-cols-2 gap-3">
        <x-stat-card label="Quantité totale vendue" :value="$report['totalQuantity']" icon="products" />
        <x-stat-card label="Chiffre d'affaires" :value="\App\Support\Money::format($report['totalRevenue'])" icon="money" />
    </div>

    <div class="mt-6">
        @if ($report['rows']->isEmpty())
            <x-empty-state icon="products" title="Aucun produit vendu sur cette période." />
        @else
            <x-card :padded="false">
                <div class="divide-y divide-slate-100">
                    @foreach ($report['rows'] as $row)
                        <div class="flex items-center justify-between gap-3 px-5 py-3">
                            <p class="min-w-0 truncate text-sm font-semibold text-slate-800">{{ $row->name }}</p>
                            <div class="shrink-0 text-right">
                                <p class="text-sm font-bold text-slate-900"><x-money :amount="$row->revenue" /></p>
                                <p class="text-xs text-slate-400">{{ $row->quantity }} vendu{{ $row->quantity > 1 ? 's' : '' }}</p>
                            </div>
                        </div>
                    @endforeach
                </div>
            </x-card>
        @endif
    </div>
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/reports"
cat > "resources/views/reports/customers.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Rapport clients">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Rapport clients</h2>
            <p class="text-sm text-slate-500">{{ ucfirst($periodLabel) }} — du {{ $from->format('d/m/Y') }} au {{ $to->format('d/m/Y') }}</p>
        </div>
        <x-button :href="route('reports.customers', array_merge(request()->query(), ['export' => 'csv']))" variant="secondary" size="sm">Export CSV</x-button>
    </div>

    <x-report-period-filter route="reports.customers" />

    <div class="grid grid-cols-2 gap-3">
        <x-stat-card label="Chiffre d'affaires" :value="\App\Support\Money::format($report['totalRevenue'])" icon="money" />
        <x-stat-card label="Reste dû (impayés)" :value="\App\Support\Money::format($report['totalRemaining'])" icon="credit" />
    </div>

    <div class="mt-6">
        @if ($report['rows']->isEmpty())
            <x-empty-state icon="customers" title="Aucun client actif sur cette période." />
        @else
            <x-card :padded="false">
                <div class="divide-y divide-slate-100">
                    @foreach ($report['rows'] as $customer)
                        <a href="{{ route('customers.show', $customer) }}" class="flex items-center justify-between gap-3 px-5 py-3 hover:bg-slate-50">
                            <div class="min-w-0">
                                <p class="truncate text-sm font-semibold text-slate-800">{{ $customer->name }}</p>
                                <p class="text-xs text-slate-400">{{ $customer->period_sales_count }} vente{{ $customer->period_sales_count > 1 ? 's' : '' }}</p>
                            </div>
                            <div class="shrink-0 text-right">
                                <p class="text-sm font-bold text-slate-900"><x-money :amount="$customer->period_revenue ?? 0" /></p>
                                @if (($customer->period_remaining ?? 0) > 0)
                                    <x-badge tone="warning"><x-money :amount="$customer->period_remaining" /> dû</x-badge>
                                @endif
                            </div>
                        </a>
                    @endforeach
                </div>
            </x-card>
        @endif
    </div>
</x-layouts.app>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/pdf"
cat > "resources/views/pdf/report-sales.blade.php" << 'PARALLELIUM_FILE_EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <title>Rapport des ventes</title>
    <style>
        body { font-family: DejaVu Sans, sans-serif; color: #1e293b; font-size: 12px; }
        h1 { font-size: 16px; color: #1f1650; margin-bottom: 2px; }
        .muted { color: #64748b; font-size: 10px; margin-bottom: 15px; }
        table.summary { width: 100%; margin-bottom: 20px; border-collapse: collapse; }
        table.summary td { width: 25%; padding: 8px; text-align: center; border: 1px solid #e2e8f0; }
        table.summary .label { display: block; color: #64748b; font-size: 9px; }
        table.summary .value { display: block; font-weight: bold; font-size: 13px; margin-top: 2px; }
        table.rows { width: 100%; border-collapse: collapse; }
        table.rows th { text-align: left; font-size: 10px; color: #64748b; border-bottom: 1px solid #e2e8f0; padding: 6px 4px; }
        table.rows td { padding: 6px 4px; border-bottom: 1px solid #f1f5f9; font-size: 11px; }
    </style>
</head>
<body>
    <h1>Rapport des ventes</h1>
    <p class="muted">{{ ucfirst($periodLabel) }} — du {{ $from->format('d/m/Y') }} au {{ $to->format('d/m/Y') }}</p>

    <table class="summary">
        <tr>
            <td><span class="label">Ventes</span><span class="value">{{ $report['count'] }}</span></td>
            <td><span class="label">Chiffre d'affaires</span><span class="value">{{ \App\Support\Money::format($report['revenue']) }}</span></td>
            <td><span class="label">Payé</span><span class="value">{{ \App\Support\Money::format($report['paid']) }}</span></td>
            <td><span class="label">Reste à payer</span><span class="value">{{ \App\Support\Money::format($report['remaining']) }}</span></td>
        </tr>
    </table>

    <table class="rows">
        <thead>
            <tr>
                <th>Date</th>
                <th>Numéro</th>
                <th>Client</th>
                <th>Statut</th>
                <th style="text-align: right;">Total</th>
            </tr>
        </thead>
        <tbody>
            @foreach ($report['rows'] as $sale)
                <tr>
                    <td>{{ $sale->sold_at->format('d/m/Y H:i') }}</td>
                    <td>{{ $sale->sale_number }}</td>
                    <td>{{ $sale->customer?->name ?? 'Client de passage' }}</td>
                    <td>{{ $sale->payment_status->label() }}</td>
                    <td style="text-align: right;">{{ \App\Support\Money::format($sale->total_amount) }}</td>
                </tr>
            @endforeach
        </tbody>
    </table>
</body>
</html>
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
use App\Http\Controllers\ReportController;
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

        Route::prefix('reports')->name('reports.')->group(function () {
            Route::get('/', [ReportController::class, 'index'])->name('index');
            Route::get('sales', [ReportController::class, 'sales'])->name('sales');
            Route::get('expenses', [ReportController::class, 'expenses'])->name('expenses');
            Route::get('products', [ReportController::class, 'products'])->name('products');
            Route::get('customers', [ReportController::class, 'customers'])->name('customers');
        });

        // Le module Paramètres est ajouté phase par phase — voir le
        // cahier des charges §56.
    });
});
PARALLELIUM_FILE_EOF

echo "Termine. Lance maintenant : php artisan view:clear"
