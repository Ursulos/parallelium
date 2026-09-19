#!/usr/bin/env bash
#
# Parallelium - Phase 12 (Tests, securite, optimisation, polish) - V1 complete
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
# Compatible Git Bash / WSL sous Windows.
set -e
echo "Application des fichiers Phase 12..."

mkdir -p "app/Http/Middleware"
cat > "app/Http/Middleware/SecurityHeaders.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * En-têtes de sécurité de base (cahier des charges §33). Ne remplace pas
 * une revue de sécurité complète, mais couvre les protections standard
 * qu'aucune application web ne devrait expédier sans.
 */
class SecurityHeaders
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        $response->headers->set('X-Frame-Options', 'SAMEORIGIN');
        $response->headers->set('X-Content-Type-Options', 'nosniff');
        $response->headers->set('Referrer-Policy', 'strict-origin-when-cross-origin');
        $response->headers->set('Permissions-Policy', 'geolocation=(), camera=(), microphone=()');

        return $response;
    }
}
PARALLELIUM_FILE_EOF

mkdir -p "bootstrap"
cat > "bootstrap/app.php" << 'PARALLELIUM_FILE_EOF'
<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'tenant.active' => \App\Http\Middleware\EnsureCompanyIsActive::class,
            'onboarding' => \App\Http\Middleware\RedirectIfOnboardingIncomplete::class,
        ]);

        $middleware->appendToGroup('web', [
            \App\Http\Middleware\EnsureCompanyIsActive::class,
            \App\Http\Middleware\SecurityHeaders::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );
    })->create();
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
    Route::post('register', [RegisteredCompanyController::class, 'store'])->middleware('throttle:6,1');

    Route::get('login', [AuthenticatedSessionController::class, 'create'])->name('login');
    Route::post('login', [AuthenticatedSessionController::class, 'store']);

    Route::get('forgot-password', [PasswordResetLinkController::class, 'create'])->name('password.request');
    Route::post('forgot-password', [PasswordResetLinkController::class, 'store'])->name('password.email')->middleware('throttle:6,1');

    Route::get('reset-password/{token}', [NewPasswordController::class, 'create'])->name('password.reset');
    Route::post('reset-password', [NewPasswordController::class, 'store'])->name('password.store')->middleware('throttle:6,1');
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

mkdir -p "resources/views/components"
cat > "resources/views/components/error-layout.blade.php" << 'PARALLELIUM_FILE_EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $title ?? 'Erreur' }} — Parallelium</title>
    @if (file_exists(public_path('build/manifest.json')) || file_exists(public_path('hot')))
        @vite(['resources/css/app.css'])
    @else
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f8fafc; }
        </style>
    @endif
</head>
<body class="flex min-h-screen items-center justify-center bg-slate-50 px-4">
    <div class="w-full max-w-sm rounded-3xl bg-white p-8 text-center shadow-xl">
        <div class="mx-auto mb-5 flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-[#1f1650] via-[#6a35c2] to-[#c22fb0] text-xl font-extrabold text-white">
            {{ $code ?? '!' }}
        </div>
        <h1 class="text-lg font-bold text-slate-900">{{ $heading ?? 'Une erreur est survenue' }}</h1>
        <p class="mt-2 text-sm text-slate-500">{{ $message ?? "Quelque chose s'est mal passé." }}</p>
        <a href="{{ url('/dashboard') }}" class="mt-6 inline-flex items-center justify-center rounded-xl bg-gradient-to-br from-[#1f1650] via-[#6a35c2] to-[#c22fb0] px-4 py-2.5 text-sm font-semibold text-white">
            Retour à l'accueil
        </a>
    </div>
</body>
</html>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/errors"
cat > "resources/views/errors/404.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-error-layout title="Page introuvable" code="404" heading="Page introuvable" message="Cette page n'existe pas ou a été déplacée." />
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/errors"
cat > "resources/views/errors/403.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-error-layout title="Accès refusé" code="403" heading="Accès refusé" message="Vous n'avez pas la permission d'accéder à cette page." />
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/errors"
cat > "resources/views/errors/419.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-error-layout title="Session expirée" code="419" heading="Session expirée" message="Votre session a expiré, probablement par inactivité. Reconnectez-vous pour continuer." />
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/errors"
cat > "resources/views/errors/500.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-error-layout title="Erreur serveur" code="500" heading="Une erreur est survenue" message="Impossible de traiter cette demande pour le moment. Réessayez dans un instant." />
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/errors"
cat > "resources/views/errors/503.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-error-layout title="Maintenance" code="503" heading="Maintenance en cours" message="Parallelium revient dans quelques instants." />
PARALLELIUM_FILE_EOF

mkdir -p "tests/Feature"
cat > "tests/Feature/SecurityTest.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use Database\Seeders\PermissionSeeder;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Derniers filets de sécurité (Phase 12, §33 et §48) : en-têtes HTTP,
 * accès cross-tenant via le model binding de route, mass assignment.
 */
class SecurityTest extends TestCase
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

    public function test_security_headers_are_present_on_every_response(): void
    {
        $response = $this->get(route('login'));

        $response->assertHeader('X-Frame-Options', 'SAMEORIGIN');
        $response->assertHeader('X-Content-Type-Options', 'nosniff');
        $response->assertHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    }

    public function test_a_company_cannot_edit_another_companys_product_via_url(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();
        $ownerA = $this->ownerFor($companyA);
        $productB = Product::factory()->create(['company_id' => $companyB->id]);

        // Le scope tenant automatique (BelongsToCompany) doit rendre ce
        // produit introuvable pour une entreprise différente, y compris
        // via le model binding implicite de route.
        $this->actingAs($ownerA)->get(route('products.edit', $productB))->assertNotFound();
    }

    public function test_registration_is_rate_limited(): void
    {
        for ($i = 0; $i < 7; $i++) {
            $response = $this->post(route('register'), [
                'company_name' => "Boutique {$i}",
                'name' => 'Test',
                'email' => "test{$i}@example.com",
                'password' => 'password123',
                'password_confirmation' => 'password123',
            ]);
        }

        $response->assertStatus(429);
    }

    public function test_mass_assignment_cannot_override_company_id_on_product_creation(): void
    {
        $companyA = Company::factory()->create();
        $companyB = Company::factory()->create();
        $ownerA = $this->ownerFor($companyA);

        $this->actingAs($ownerA)->post(route('products.store'), [
            // Tentative d'injection d'un company_id arbitraire : le champ
            // n'est simplement pas dans les règles de validation, donc
            // jamais transmis au service, quoi qu'envoie le client.
            'company_id' => $companyB->id,
            'name' => 'Produit test',
            'unit' => 'unite',
            'purchase_price' => 100,
            'selling_price' => 200,
        ]);

        $product = Product::first();
        $this->assertEquals($companyA->id, $product->company_id);
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
      Paramètres/tarification (Free / Starter 15 000 Ar / Business 45 000 Ar).
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
echo "V1 de Parallelium complete (Phases 1 a 12) !"
