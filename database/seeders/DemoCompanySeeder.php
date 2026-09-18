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
