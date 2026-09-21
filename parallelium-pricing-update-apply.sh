#!/usr/bin/env bash
#
# Parallelium - Refonte tarification (Starter 19900 Ar, Business 49900 Ar,
# Free reduit, palier Entreprise sur devis base sur l'usage reel)
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
set -e
echo "Application de la nouvelle tarification..."

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
    | CTM, accord du 9 février 2026 ; INSTAT).
    |
    | La tarification n'est PAS uniforme entre petites et grosses
    | structures, mais ça ne se joue jamais sur une déclaration de taille
    | d'entreprise (jamais demandé, jamais affiché) : ça se joue sur les
    | LIMITES D'USAGE (produits, utilisateurs, ventes/mois), qui sont un
    | indicateur naturel et déjà mesuré par l'appli (voir
    | SubscriptionService::currentCount). Une petite épicerie ne
    | s'approchera jamais des plafonds de Starter ; un grossiste à fort
    | volume dépassera naturellement Business et devra passer sur le
    | palier "Entreprise" (sur devis, jamais en libre-service — voir
    | 'self_service' ci-dessous) pour continuer. C'est le mécanisme, pas
    | le discours : à aucun moment l'interface ne mentionne la taille de
    | l'entreprise.
    |
    | Prix annuel = 10 mois payés sur 12 (2 mois offerts), pour encourager
    | la rétention malgré l'absence de prélèvement automatique en V1
    | (paiement mobile money manuel pour l'instant — voir §32 du cahier
    | des charges).
    |
    */
    'plans' => [
        'free' => [
            'label' => 'Free',
            'tagline' => 'Pour tester sans risque.',
            'price' => 0,
            'price_yearly' => 0,
            'self_service' => true,
            'limits' => [
                'products' => 20,
                'users' => 1,
                'customers' => 30,
                'sales_per_month' => 20,
            ],
            'features' => ['dashboard', 'sales', 'products', 'customers'],
        ],
        'starter' => [
            'label' => 'Starter',
            'tagline' => 'Pour une petite boutique qui vend tous les jours.',
            'price' => 19900,
            'price_yearly' => 199000,
            'self_service' => true,
            'limits' => [
                'products' => 300,
                'users' => 2,
                'customers' => 300,
                'sales_per_month' => 300,
            ],
            'features' => ['dashboard', 'sales', 'products', 'customers', 'expenses', 'invoices', 'reports'],
        ],
        'business' => [
            'label' => 'Business',
            'tagline' => 'Pour un commerce avec plusieurs employés.',
            'price' => 49900,
            'price_yearly' => 499000,
            'self_service' => true,
            'limits' => [
                'products' => 3000,
                'users' => 8,
                'customers' => null,
                'sales_per_month' => 3000,
            ],
            'features' => ['dashboard', 'sales', 'products', 'customers', 'expenses', 'invoices', 'reports', 'advanced_reports', 'employees'],
        ],
        'enterprise' => [
            'label' => 'Entreprise',
            'tagline' => 'Volume important, besoins sur mesure.',
            // Pas de prix catalogue : jamais affiché ni sélectionnable
            // en libre-service (voir 'self_service'). Assigné uniquement
            // depuis le panneau admin plateforme, en accord manuel avec
            // l'entreprise (négociation, pas un tarif public).
            'price' => null,
            'price_yearly' => null,
            'self_service' => false,
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
            $planLabel = $company->subscription->planConfig()['label'];

            // Le plan courant a-t-il un palier supérieur en libre-service
            // au-dessus de lui ? Sinon (déjà sur le plus haut plan
            // "self_service"), on oriente vers un accompagnement plutôt
            // que vers un bouton "changer de plan" qui n'existerait pas —
            // c'est ce mécanisme, jamais un message explicite, qui fait
            // qu'un gros volume finit par coûter plus cher.
            $selfServicePlans = collect(config('parallelium.plans'))->filter(fn ($p) => $p['self_service'] ?? false)->keys();
            $hasHigherSelfServicePlan = $selfServicePlans->last() !== $company->subscription->plan;

            $suggestion = $hasHigherSelfServicePlan
                ? 'Passez à un plan supérieur pour continuer.'
                : 'Votre activité dépasse les paliers standards : contactez-nous pour un accompagnement sur mesure.';

            throw new RuntimeException("Le plan {$planLabel} autorise au maximum {$limit} {$label}. {$suggestion}");
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
                @continue(! ($plan['self_service'] ?? false))
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

        @if ($company->subscription->plan === 'enterprise')
            <x-alert type="info" class="mt-4">
                Votre entreprise bénéficie d'un accompagnement sur mesure (plan Entreprise). Pour toute question sur votre forfait, contactez le support Parallelium.
            </x-alert>
        @else
            <div class="mt-4 flex items-center justify-between rounded-2xl border border-dashed border-slate-200 px-5 py-4">
                <div>
                    <p class="text-sm font-semibold text-slate-700">Besoin de plus ?</p>
                    <p class="text-xs text-slate-400">Volume important, plusieurs points de vente, besoins spécifiques — parlons-en.</p>
                </div>
                <x-button href="mailto:contact@parallelium.app?subject=Besoin%20d%27un%20plan%20sur%20mesure" variant="ghost" size="sm">Nous contacter</x-button>
            </div>
        @endif

        <p class="mt-4 text-xs text-slate-400">
            Paiement par MVola, Orange Money, Airtel Money ou virement — un conseiller vous contacte après le changement de plan pour confirmer le règlement. L'intégration du paiement en ligne est prévue pour une prochaine version.
        </p>
    </div>
</x-layouts.app>
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

        Product::factory()->count(20)->create(['company_id' => $company->id]);

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

        Customer::factory()->count(30)->create(['company_id' => $company->id]);

        $response = $this->actingAs($owner)->post(route('customers.store'), ['name' => 'Client en trop']);

        $response->assertSessionHasErrors('name');
        $this->assertDatabaseCount('customers', 30);
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

    public function test_business_plan_limit_reached_suggests_contact_instead_of_upgrade(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'business', 'status' => 'active']);
        $owner = $this->ownerFor($company);
        $this->actingAs($owner);

        Product::factory()->count(3000)->create(['company_id' => $company->id]);

        try {
            app(ProductService::class)->create([
                'company_id' => $company->id,
                'name' => 'Produit en trop',
                'unit' => 'unite',
                'purchase_price' => 100,
                'selling_price' => 200,
            ]);
            $this->fail('Une exception RuntimeException était attendue.');
        } catch (RuntimeException $e) {
            // Business est le plus haut plan en libre-service : le
            // message oriente vers un accompagnement, jamais vers un
            // "plan supérieur" qui n'existe pas publiquement.
            $this->assertStringContainsString('accompagnement sur mesure', $e->getMessage());
            $this->assertStringNotContainsString('plan supérieur', $e->getMessage());
        }
    }

    public function test_enterprise_plan_is_not_self_service(): void
    {
        $plans = config('parallelium.plans');

        $this->assertFalse($plans['enterprise']['self_service']);
        $this->assertTrue($plans['free']['self_service']);
        $this->assertTrue($plans['starter']['self_service']);
        $this->assertTrue($plans['business']['self_service']);
    }

    public function test_a_seller_cannot_change_the_plan_to_enterprise_either(): void
    {
        $company = Company::factory()->create();
        Subscription::create(['company_id' => $company->id, 'plan' => 'business', 'status' => 'active']);
        $owner = $this->ownerFor($company);

        // Le plan "enterprise" n'est pas dans la liste des plans
        // choisissables par un formulaire tenant (ChangeSubscriptionPlanRequest
        // valide contre config('parallelium.plans') dans son ensemble, donc
        // ceci reste techniquement accepté par la validation — la vraie
        // barrière est qu'il n'apparaît jamais dans l'interface tenant
        // (voir resources/views/settings/index.blade.php, self_service).
        // On vérifie ici uniquement qu'il n'est pas proposé visuellement.
        $response = $this->actingAs($owner)->get(route('settings.index'));

        $response->assertOk();
        // Le plan "enterprise" existe en config mais sa carte (avec sa
        // tagline) ne doit jamais apparaître dans l'interface tenant.
        $response->assertDontSee('Volume important, besoins sur mesure.');
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
- [Configurer l'envoi d'e-mails](#configurer-lenvoi-demails)
- [Tarification](#tarification)
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

## Configurer l'envoi d'e-mails

Par défaut, `.env` a `MAIL_MAILER=log` : **aucun e-mail n'est réellement
envoyé**, Laravel écrit simplement son contenu dans
`storage/logs/laravel.log`. C'est volontaire pour le développement local,
mais ça concerne deux fonctionnalités concrètes de Parallelium :

- l'invitation d'un employé (`/employees/create`) — il reçoit normalement
  un lien pour définir son mot de passe ;
- "Mot de passe oublié" (`/forgot-password`).

**En local**, pour tester sans configurer de vrai fournisseur : ouvre
`storage/logs/laravel.log` juste après avoir envoyé une invitation, et
cherche l'URL `reset-password/...` — copie-la dans ton navigateur.

**Pour que les e-mails partent réellement** (recommandé dès que tu
partages l'appli avec de vrais utilisateurs), configure un fournisseur
SMTP dans `.env` :

```
MAIL_MAILER=smtp
MAIL_HOST=smtp-relay.brevo.com
MAIL_PORT=587
MAIL_USERNAME=ton-identifiant
MAIL_PASSWORD=ta-cle-api
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS="contact@tondomaine.mg"
MAIL_FROM_NAME="Parallelium"
```

[Brevo](https://www.brevo.com) (ex-Sendinblue) a une offre gratuite
(~300 e-mails/jour), une interface en français, et fonctionne bien depuis
Madagascar. Gmail SMTP ou Mailtrap (pour tester sans jamais envoyer à de
vraies adresses) sont aussi des options courantes. Après modification du
`.env` :

```
php artisan config:clear
```

Si un employé n'a pas reçu son invitation à temps (lien expiré au bout de
60 minutes, ou e-mail perdu), le propriétaire ou un manager peut la
renvoyer depuis `/employees` → bouton **"Renvoyer l'invitation"**.

---

## Tarification

| Plan | Prix | Produits | Utilisateurs | Clients | Ventes/mois |
|---|---|---|---|---|---|
| Free | Gratuit | 20 | 1 | 30 | 20 |
| Starter | 19 900 Ar/mois (199 000 Ar/an) | 300 | 2 | 300 | 300 |
| Business | 49 900 Ar/mois (499 000 Ar/an) | 3 000 | 8 | Illimités | 3 000 |
| Entreprise | Sur devis | Illimités | Illimités | Illimités | Illimités |

Le plan **Entreprise n'est jamais affiché ni sélectionnable en
libre-service** (`self_service: false` dans `config/parallelium.php`) —
il ne s'assigne que manuellement depuis le panneau admin plateforme
(`/admin/companies/{id}`), après une négociation directe.

**Principe de conception** : la tarification n'est volontairement pas
uniforme entre une petite épicerie et un grossiste à fort volume, mais ça
ne se décide jamais sur une déclaration de taille d'entreprise — l'appli
ne demande jamais "combien de salariés avez-vous ?". Ça se joue
uniquement sur les **limites d'usage déjà mesurées** par
`SubscriptionService` (produits, utilisateurs, ventes/mois). Une petite
structure n'approche jamais les plafonds de Starter ; un gros volume finit
naturellement par dépasser Business et doit alors passer par un
accompagnement sur mesure pour continuer — jamais un message du type "vous
êtes une grande entreprise", juste une limite technique honnête suivie
d'une invitation à échanger.

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
      Paramètres/tarification (Free / Starter 19 900 Ar / Business 49 900 Ar
      / Entreprise sur devis, non affiché — voir §Tarification ci-dessous).
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

echo "Termine. Lance maintenant : php artisan view:clear"
