#!/usr/bin/env bash
#
# Parallelium - Phase 10 (Abonnements)
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
# Compatible Git Bash / WSL sous Windows.
set -e
echo "Application des fichiers Phase 10..."

mkdir -p "config"
cat > "config/parallelium.php" << 'PARALLELIUM_FILE_EOF'
<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Devise par défaut
    |--------------------------------------------------------------------------
    |
    | Devise et symbole utilisés lors de la création d'une nouvelle entreprise.
    | Chaque entreprise peut ensuite choisir sa propre devise dans ses
    | paramètres. Ne jamais coder "Ar" en dur dans les vues : utiliser
    | le helper de formatage de monnaie (voir App\Support\Money).
    |
    */
    'default_currency' => env('PARALLELIUM_DEFAULT_CURRENCY', 'MGA'),

    'currencies' => [
        'MGA' => ['label' => 'Ariary malgache', 'symbol' => 'Ar', 'decimals' => 0],
        'USD' => ['label' => 'Dollar américain', 'symbol' => '$', 'decimals' => 2],
        'EUR' => ['label' => 'Euro', 'symbol' => '€', 'decimals' => 2],
    ],

    'default_timezone' => env('PARALLELIUM_DEFAULT_TIMEZONE', 'Indian/Antananarivo'),

    /*
    |--------------------------------------------------------------------------
    | Numérotation des documents
    |--------------------------------------------------------------------------
    |
    | Préfixes par défaut, personnalisables par entreprise dans les
    | paramètres (settings.invoice_prefix, etc.). La numérotation réelle
    | est gérée par App\Services\DocumentNumberService.
    |
    */
    'document_prefixes' => [
        'invoice' => env('PARALLELIUM_INVOICE_PREFIX', 'PAR'),
        'sale' => 'SALE',
        'expense' => 'EXP',
    ],

    /*
    |--------------------------------------------------------------------------
    | Plans d'abonnement
    |--------------------------------------------------------------------------
    |
    | Source de vérité pour les limites de chaque plan. Ne jamais coder ces
    | valeurs en dur dans les contrôleurs : passer par
    | App\Services\SubscriptionService::assertCanCreate($company, 'products').
    | "null" = illimité.
    |
    | Tarification (Ariary, TTC) pensée pour le marché malgache :
    | le SMIG 2026 est de 300 000 Ar/mois et la médiane du secteur formel
    | se situe autour de 300 000-1 000 000 Ar/mois (source : GEM/Fivmpama/
    | CTM, accord du 9 février 2026 ; INSTAT). Objectif explicite du
    | produit : maximiser le nombre de clients, donc un palier gratuit
    | réellement utilisable, et un premier palier payant abordable
    | (~5 % du SMIG/mois, soit moins de 700 Ar/jour) avant un palier
    | "Business" pour les commerces multi-employés. Prix annuel = 10 mois
    | payés sur 12 (2 mois offerts), pour encourager la rétention malgré
    | l'absence de prélèvement automatique en V1 (paiement mobile money
    | manuel pour l'instant — voir §32 du cahier des charges).
    |
    */
    'plans' => [
        'free' => [
            'label' => 'Free',
            'tagline' => 'Pour démarrer sans risque, à vie.',
            'price' => 0,
            'price_yearly' => 0,
            'limits' => [
                'products' => 50,
                'users' => 1,
                'customers' => 100,
                'sales_per_month' => 100,
            ],
            'features' => ['dashboard', 'sales', 'products', 'customers'],
        ],
        'starter' => [
            'label' => 'Starter',
            'tagline' => 'Pour une boutique qui vend tous les jours.',
            'price' => 15000,
            'price_yearly' => 150000,
            'limits' => [
                'products' => 500,
                'users' => 3,
                'customers' => null,
                'sales_per_month' => null,
            ],
            'features' => ['dashboard', 'sales', 'products', 'customers', 'expenses', 'invoices', 'reports'],
        ],
        'business' => [
            'label' => 'Business',
            'tagline' => 'Pour un commerce avec plusieurs employés.',
            'price' => 45000,
            'price_yearly' => 450000,
            'limits' => [
                'products' => null,
                'users' => null,
                'customers' => null,
                'sales_per_month' => null,
            ],
            'features' => ['dashboard', 'sales', 'products', 'customers', 'expenses', 'invoices', 'reports', 'advanced_reports', 'employees'],
        ],
    ],

    'trial_days' => 14,
];
PARALLELIUM_FILE_EOF

mkdir -p "app/Services"
cat > "app/Services/SubscriptionService.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Services;

use App\Models\Company;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Sale;
use App\Models\Subscription;
use App\Models\User;
use RuntimeException;

/**
 * Point de passage UNIQUE pour vérifier les limites d'un plan
 * d'abonnement (§32 du cahier des charges). Aucune limite ne doit être
 * codée en dur ailleurs dans les contrôleurs ou services — tout passe
 * par assertCanCreate() ou usage().
 */
class SubscriptionService
{
    protected const COUNTERS = [
        'products' => Product::class,
        'users' => User::class,
        'customers' => Customer::class,
    ];

    public function assertCanCreate(Company $company, string $resource): void
    {
        $limit = $company->subscription?->limit($resource);

        if ($limit === null) {
            return; // pas d'abonnement (ne devrait pas arriver) ou illimité
        }

        $current = $this->currentCount($company, $resource);

        if ($current >= $limit) {
            $label = $this->resourceLabel($resource);
            throw new RuntimeException(
                "Le plan {$company->subscription->planConfig()['label']} autorise au maximum {$limit} {$label}. Passez à un plan supérieur pour continuer."
            );
        }
    }

    public function currentCount(Company $company, string $resource): int
    {
        if ($resource === 'sales_per_month') {
            return Sale::completed()
                ->whereBetween('sold_at', [now()->startOfMonth(), now()->endOfMonth()])
                ->count();
        }

        $modelClass = self::COUNTERS[$resource] ?? null;

        if (! $modelClass) {
            return 0;
        }

        return $modelClass::where('company_id', $company->id)->count();
    }

    /**
     * Utilisation actuelle vs limites du plan, pour affichage dans les
     * paramètres (§41) : ['products' => ['used' => 12, 'limit' => 50], ...].
     */
    public function usage(Company $company): array
    {
        $subscription = $company->subscription;

        $resources = ['products', 'users', 'customers', 'sales_per_month'];

        return collect($resources)->mapWithKeys(function ($resource) use ($company, $subscription) {
            return [$resource => [
                'used' => $this->currentCount($company, $resource),
                'limit' => $subscription?->limit($resource),
            ]];
        })->all();
    }

    public function changePlan(Company $company, string $planSlug): Subscription
    {
        if (! array_key_exists($planSlug, config('parallelium.plans'))) {
            throw new RuntimeException('Plan inconnu.');
        }

        $subscription = $company->subscription ?? new Subscription(['company_id' => $company->id]);
        $subscription->fill([
            'plan' => $planSlug,
            'status' => 'active',
            'current_period_ends_at' => now()->addMonth(),
        ])->save();

        return $subscription->fresh();
    }

    protected function resourceLabel(string $resource): string
    {
        return match ($resource) {
            'products' => 'produits',
            'users' => 'utilisateurs',
            'customers' => 'clients',
            'sales_per_month' => 'ventes par mois',
            default => $resource,
        };
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Services"
cat > "app/Services/ProductService.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Services;

use App\Enums\StockMovementType;
use App\Models\Company;
use App\Models\Product;
use App\Support\Tenant;
use Illuminate\Support\Facades\DB;

class ProductService
{
    public function __construct(
        protected StockService $stockService,
        protected SubscriptionService $subscriptionService,
    ) {
    }

    public function create(array $data): Product
    {
        // Tenant::current() est vide hors contexte HTTP authentifié (ex.
        // seeders, commandes artisan) : dans ce cas on se base sur le
        // company_id fourni explicitement plutôt que de planter, et on
        // saute la vérification de plan (contexte administratif, jamais
        // exposé à un utilisateur final).
        $company = Tenant::current() ?? (isset($data['company_id']) ? Company::find($data['company_id']) : null);

        if ($company && Tenant::check()) {
            $this->subscriptionService->assertCanCreate($company, 'products');
        }

        return DB::transaction(function () use ($data) {
            $initialStock = (int) ($data['stock_quantity'] ?? 0);
            unset($data['stock_quantity']);

            /** @var Product $product */
            $product = Product::create([...$data, 'stock_quantity' => 0]);

            if ($initialStock > 0) {
                $this->stockService->record(
                    $product,
                    StockMovementType::Adjustment,
                    $initialStock,
                    'Stock initial'
                );
            }

            return $product->fresh();
        });
    }

    /**
     * Le stock ne se modifie JAMAIS via update() : uniquement via
     * StockService::adjust(), pour rester traçable.
     */
    public function update(Product $product, array $data): Product
    {
        unset($data['stock_quantity']);

        $product->update($data);

        return $product->fresh();
    }

    public function delete(Product $product): void
    {
        $product->update(['is_active' => false]);
        $product->delete();
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
    public function __construct(protected SubscriptionService $subscriptionService)
    {
    }

    public function invite(array $data): User
    {
        $company = Tenant::current();

        // Vérification de limite centralisée (§32) — voir SubscriptionService.
        $this->subscriptionService->assertCanCreate($company, 'users');

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
    public function __construct(
        protected StockService $stockService,
        protected SubscriptionService $subscriptionService,
    ) {
    }

    public function create(array $data, User $user): Sale
    {
        $company = Tenant::current();

        // Vérification de limite centralisée (§32) — voir SubscriptionService.
        $this->subscriptionService->assertCanCreate($company, 'sales_per_month');

        return DB::transaction(function () use ($data, $user, $company) {
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

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/CustomerController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreCustomerRequest;
use App\Http\Requests\UpdateCustomerRequest;
use App\Models\Customer;
use App\Services\SubscriptionService;
use App\Support\Tenant;
use Illuminate\Http\Request;
use RuntimeException;

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

    public function store(StoreCustomerRequest $request, SubscriptionService $subscriptionService)
    {
        try {
            $subscriptionService->assertCanCreate(Tenant::current(), 'customers');
        } catch (RuntimeException $e) {
            return back()->withErrors(['name' => $e->getMessage()])->withInput();
        }

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

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/SettingsController.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use App\Http\Requests\ChangeSubscriptionPlanRequest;
use App\Services\SubscriptionService;
use App\Support\Tenant;

class SettingsController extends Controller
{
    public function index(SubscriptionService $subscriptionService)
    {
        $company = Tenant::current();
        $usage = $subscriptionService->usage($company);
        $plans = config('parallelium.plans');

        return view('settings.index', compact('company', 'usage', 'plans'));
    }

    public function changePlan(ChangeSubscriptionPlanRequest $request, SubscriptionService $subscriptionService)
    {
        $subscriptionService->changePlan(Tenant::current(), $request->validated('plan'));

        return redirect()->route('settings.index')->with('status', 'Abonnement mis à jour.');
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "app/Http/Requests"
cat > "app/Http/Requests/ChangeSubscriptionPlanRequest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ChangeSubscriptionPlanRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('settings.manage');
    }

    public function rules(): array
    {
        return [
            'plan' => ['required', Rule::in(array_keys(config('parallelium.plans')))],
        ];
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "tests/Feature"
cat > "tests/Feature/SubscriptionTest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Role;
use App\Models\Subscription;
use App\Models\User;
use App\Services\ProductService;
use App\Services\SubscriptionService;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use RuntimeException;
use Tests\TestCase;

class SubscriptionTest extends TestCase
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

    public function test_free_plan_blocks_product_creation_past_its_limit(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'free', 'status' => 'active']);
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        Product::factory()->count(50)->create(['company_id' => $company->id]);

        $this->expectException(RuntimeException::class);

        app(ProductService::class)->create([
            'company_id' => $company->id,
            'name' => 'Produit en trop',
            'unit' => 'unite',
            'purchase_price' => 100,
            'selling_price' => 200,
        ]);
    }

    public function test_starter_plan_allows_more_products_than_free(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'starter', 'status' => 'active']);
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        Product::factory()->count(50)->create(['company_id' => $company->id]);

        $product = app(ProductService::class)->create([
            'company_id' => $company->id,
            'name' => 'Produit 51',
            'unit' => 'unite',
            'purchase_price' => 100,
            'selling_price' => 200,
        ]);

        $this->assertNotNull($product->id);
    }

    public function test_business_plan_has_unlimited_products(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'business', 'status' => 'active']);

        $this->assertNull(app(SubscriptionService::class)->usage($company)['products']['limit']);
    }

    public function test_free_plan_blocks_customer_creation_past_its_limit(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'free', 'status' => 'active']);
        $owner = $this->ownerFor($company);

        Customer::factory()->count(100)->create(['company_id' => $company->id]);

        $response = $this->actingAs($owner)->post(route('customers.store'), ['name' => 'Client en trop']);

        $response->assertSessionHasErrors('name');
        $this->assertDatabaseCount('customers', 100);
    }

    public function test_owner_can_change_plan(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'free', 'status' => 'active']);
        $owner = $this->ownerFor($company);

        $this->actingAs($owner)
            ->post(route('settings.subscription'), ['plan' => 'starter'])
            ->assertRedirect(route('settings.index'));

        $this->assertEquals('starter', $company->subscription->fresh()->plan);
    }

    public function test_a_seller_cannot_change_the_plan(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'free', 'status' => 'active']);
        $sellerRole = Role::whereNull('company_id')->where('slug', 'seller')->first();
        $seller = User::factory()->create(['company_id' => $company->id, 'role_id' => $sellerRole->id]);

        $this->actingAs($seller)
            ->post(route('settings.subscription'), ['plan' => 'starter'])
            ->assertForbidden();
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/settings"
cat > "resources/views/settings/index.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Paramètres">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Paramètres</h2>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
    @endif
    @if ($errors->any())
        <x-alert type="error" class="mb-4">{{ $errors->first() }}</x-alert>
    @endif

    <x-card class="mb-6">
        <h3 class="mb-3 text-sm font-semibold text-slate-700">Entreprise</h3>
        <dl class="grid gap-3 sm:grid-cols-2">
            <div>
                <dt class="text-xs text-slate-400">Nom</dt>
                <dd class="text-sm font-medium text-slate-800">{{ $company->name }}</dd>
            </div>
            <div>
                <dt class="text-xs text-slate-400">Devise</dt>
                <dd class="text-sm font-medium text-slate-800">{{ $company->currency }} ({{ $company->currencySymbol() }})</dd>
            </div>
            <div>
                <dt class="text-xs text-slate-400">Téléphone</dt>
                <dd class="text-sm font-medium text-slate-800">{{ $company->phone ?? '—' }}</dd>
            </div>
            <div>
                <dt class="text-xs text-slate-400">Préfixe des factures</dt>
                <dd class="text-sm font-medium text-slate-800">{{ $company->invoice_prefix }}-{{ date('Y') }}-000001</dd>
            </div>
        </dl>
    </x-card>

    <div class="mb-6">
        <h3 class="mb-3 text-sm font-semibold text-slate-700">Utilisation de votre plan</h3>
        <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            @foreach ($usage as $resource => $u)
                @php
                    $labels = ['products' => 'Produits', 'users' => 'Utilisateurs', 'customers' => 'Clients', 'sales_per_month' => 'Ventes ce mois'];
                    $percent = $u['limit'] ? min(100, round(($u['used'] / max($u['limit'], 1)) * 100)) : 0;
                @endphp
                <x-card>
                    <p class="text-xs text-slate-400">{{ $labels[$resource] }}</p>
                    <p class="mt-1 text-lg font-bold text-slate-900">
                        {{ $u['used'] }} <span class="text-sm font-normal text-slate-400">/ {{ $u['limit'] ?? '∞' }}</span>
                    </p>
                    @if ($u['limit'])
                        <div class="mt-2 h-1.5 w-full rounded-full bg-slate-100">
                            <div class="h-1.5 rounded-full {{ $percent >= 90 ? 'bg-red-500' : 'bg-brand-500' }}" style="width: {{ $percent }}%"></div>
                        </div>
                    @endif
                </x-card>
            @endforeach
        </div>
    </div>

    <div>
        <h3 class="mb-1 text-sm font-semibold text-slate-700">Abonnement</h3>
        <p class="mb-4 text-xs text-slate-400">Plan actuel : <span class="font-semibold text-brand-700">{{ $plans[$company->subscription->plan]['label'] ?? '—' }}</span></p>

        <div class="grid gap-4 sm:grid-cols-3">
            @foreach ($plans as $slug => $plan)
                @php($isCurrent = $company->subscription->plan === $slug)
                <div class="relative flex flex-col rounded-2xl border-2 bg-white p-5 {{ $isCurrent ? 'border-brand-500 shadow-lg shadow-brand-500/10' : 'border-slate-100' }}">
                    @if ($isCurrent)
                        <x-badge tone="brand" class="absolute -top-3 left-5">Plan actuel</x-badge>
                    @endif

                    <p class="text-lg font-extrabold text-slate-900">{{ $plan['label'] }}</p>
                    <p class="mt-0.5 text-xs text-slate-400">{{ $plan['tagline'] }}</p>

                    <p class="mt-4 text-2xl font-extrabold text-brand-700">
                        @if ($plan['price'] == 0)
                            Gratuit
                        @else
                            {{ \App\Support\Money::format($plan['price'], $company->currency) }}
                            <span class="text-sm font-normal text-slate-400">/mois</span>
                        @endif
                    </p>
                    @if ($plan['price'] > 0)
                        <p class="text-xs text-slate-400">
                            ou {{ \App\Support\Money::format($plan['price_yearly'], $company->currency) }}/an (2 mois offerts)
                        </p>
                    @endif

                    <ul class="mt-4 flex-1 space-y-1.5 text-sm text-slate-600">
                        <li>{{ $plan['limits']['products'] ?? 'Produits illimités' }} @if($plan['limits']['products']) produits @endif</li>
                        <li>{{ $plan['limits']['users'] ?? 'Utilisateurs illimités' }} @if($plan['limits']['users']) utilisateur(s) @endif</li>
                        <li>{{ $plan['limits']['customers'] ?? 'Clients illimités' }} @if($plan['limits']['customers']) clients @endif</li>
                        <li>{{ $plan['limits']['sales_per_month'] ?? 'Ventes illimitées' }} @if($plan['limits']['sales_per_month']) ventes/mois @endif</li>
                        @if (in_array('reports', $plan['features']))
                            <li>Rapports</li>
                        @endif
                        @if (in_array('advanced_reports', $plan['features']))
                            <li>Rapports avancés</li>
                        @endif
                        @if (in_array('employees', $plan['features']))
                            <li>Gestion des employés</li>
                        @endif
                    </ul>

                    @can('settings.manage')
                        @unless ($isCurrent)
                            <form method="POST" action="{{ route('settings.subscription') }}" class="mt-4">
                                @csrf
                                <input type="hidden" name="plan" value="{{ $slug }}">
                                <x-button type="submit" variant="secondary" class="w-full justify-center">Passer à ce plan</x-button>
                            </form>
                        @endunless
                    @endcan
                </div>
            @endforeach
        </div>

        <p class="mt-4 text-xs text-slate-400">
            Paiement par MVola, Orange Money, Airtel Money ou virement — un conseiller vous contacte après le changement de plan pour confirmer le règlement. L'intégration du paiement en ligne est prévue pour une prochaine version.
        </p>
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
use App\Http\Controllers\EmployeeController;
use App\Http\Controllers\ExpenseController;
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

        Route::get('settings', [SettingsController::class, 'index'])->name('settings.index');
        Route::post('settings/subscription', [SettingsController::class, 'changePlan'])->name('settings.subscription');
    });
});
PARALLELIUM_FILE_EOF

echo "Termine. Lance maintenant : php artisan view:clear"
