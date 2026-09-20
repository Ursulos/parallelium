#!/usr/bin/env bash
#
# Parallelium - Correctif : invitation employe (MAIL_MAILER=log) + renvoi
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
set -e
echo "Application du correctif..."

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

            $this->sendInviteEmail($user);

            return $user;
        });
    }

    /**
     * Renvoie le lien de définition de mot de passe à un employé déjà
     * créé — utile si le premier envoi a échoué ou expiré (le lien de
     * réinitialisation Laravel expire après 60 minutes par défaut).
     */
    public function resendInvite(User $employee): void
    {
        $this->sendInviteEmail($employee);
    }

    protected function sendInviteEmail(User $user): void
    {
        $status = Password::sendResetLink(['email' => $user->email]);

        // Avec MAIL_MAILER=log (réglage par défaut en local), l'envoi
        // "réussit" toujours : Laravel écrit l'e-mail dans
        // storage/logs/laravel.log au lieu de l'envoyer réellement. Ce
        // n'est un vrai échec que si le broker renvoie autre chose que
        // RESET_LINK_SENT (ex. limite de taux atteinte).
        if ($status !== Password::RESET_LINK_SENT) {
            throw new RuntimeException("Le compte a été créé, mais l'e-mail d'invitation n'a pas pu être envoyé ({$status}). Réessayez depuis la liste des employés.");
        }
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

    public function resendInvite(User $employee, EmployeeService $employeeService)
    {
        $this->authorize('employees.manage');
        $this->ensureSameCompany($employee);

        try {
            $employeeService->resendInvite($employee);
        } catch (RuntimeException $e) {
            return back()->withErrors(['employee' => $e->getMessage()]);
        }

        return back()->with('status', "Invitation renvoyée à {$employee->email}.");
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
use App\Http\Controllers\ImpersonationController;
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
    Route::post('impersonation/stop', [ImpersonationController::class, 'stop'])->name('impersonation.stop');

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
        Route::post('employees/{employee}/resend-invite', [EmployeeController::class, 'resendInvite'])->name('employees.resend-invite');

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

mkdir -p "resources/views/employees"
cat > "resources/views/employees/index.blade.php" << 'PARALLELIUM_FILE_EOF'
<x-layouts.app title="Employés">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Employés</h2>
            <p class="text-sm text-slate-500">
                {{ $employees->total() }} membre{{ $employees->total() > 1 ? 's' : '' }}
                @if ($userLimit) sur {{ $userLimit }} autorisé{{ $userLimit > 1 ? 's' : '' }} (plan actuel) @endif
            </p>
        </div>
        @can('employees.manage')
            <x-button :href="route('employees.create')" size="sm"><x-icon name="plus" /> Inviter un employé</x-button>
        @endcan
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
    @endif
    @if ($errors->any())
        <x-alert type="error" class="mb-4">{{ $errors->first() }}</x-alert>
    @endif

    <x-card :padded="false">
        <div class="divide-y divide-slate-100">
            @foreach ($employees as $employee)
                <div class="flex items-center justify-between gap-3 px-5 py-3">
                    <div class="flex min-w-0 items-center gap-3">
                        <span class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand-50 text-sm font-semibold text-brand-700">
                            {{ strtoupper(substr($employee->name, 0, 1)) }}
                        </span>
                        <div class="min-w-0">
                            <p class="truncate text-sm font-semibold text-slate-800">
                                {{ $employee->name }}
                                @if ($employee->id === auth()->id())
                                    <span class="text-xs font-normal text-slate-400">(vous)</span>
                                @endif
                            </p>
                            <p class="truncate text-xs text-slate-400">{{ $employee->email }}</p>
                        </div>
                    </div>

                    <div class="flex shrink-0 items-center gap-3">
                        <x-badge tone="brand">{{ $employee->role?->name ?? '—' }}</x-badge>
                        @if (! $employee->is_active)
                            <x-badge tone="danger">Désactivé</x-badge>
                        @endif
                        @can('employees.manage')
                            @unless ($employee->isOwner())
                                <a href="{{ route('employees.edit', $employee) }}" class="text-sm font-medium text-brand-600 hover:underline">Modifier</a>
                                @if ($employee->is_active)
                                    <form method="POST" action="{{ route('employees.resend-invite', $employee) }}">
                                        @csrf
                                        <button type="submit" class="text-sm font-medium text-slate-500 hover:underline">Renvoyer l'invitation</button>
                                    </form>
                                @endif
                                @if ($employee->id !== auth()->id())
                                    <form method="POST" action="{{ route('employees.destroy', $employee) }}" onsubmit="return confirm('Désactiver cet employé ?');">
                                        @csrf
                                        @method('DELETE')
                                        <button type="submit" class="text-sm font-medium text-red-500 hover:underline">Désactiver</button>
                                    </form>
                                @endif
                            @endunless
                        @endcan
                    </div>
                </div>
            @endforeach
        </div>
    </x-card>

    <div class="mt-5">{{ $employees->links() }}</div>
</x-layouts.app>
PARALLELIUM_FILE_EOF

cat > ".env.example" << 'PARALLELIUM_FILE_EOF'
APP_NAME=Parallelium
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost:8000

APP_LOCALE=fr
APP_FALLBACK_LOCALE=fr
APP_FAKER_LOCALE=fr_FR

APP_MAINTENANCE_DRIVER=file

BCRYPT_ROUNDS=12

LOG_CHANNEL=stack
LOG_STACK=single
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

# --- Base de données ---
# Sous XAMPP : demarrer Apache + MySQL dans le panneau de controle,
# puis creer une base "parallelium" via phpMyAdmin (http://localhost/phpmyadmin)
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=parallelium
DB_USERNAME=root
DB_PASSWORD=

SESSION_DRIVER=database
SESSION_LIFETIME=120
SESSION_ENCRYPT=false
SESSION_PATH=/
SESSION_DOMAIN=null

BROADCAST_CONNECTION=log
FILESYSTEM_DISK=local
QUEUE_CONNECTION=database

CACHE_STORE=database

# --- E-mail ---
# Par defaut (MAIL_MAILER=log) : aucun e-mail n'est reellement envoye,
# le contenu est ecrit dans storage/logs/laravel.log a la place. Pratique
# en local, mais ca veut dire que les invitations d'employes et les
# reinitialisations de mot de passe ne partent PAS reellement tant que
# tu n'as pas configure un vrai fournisseur ci-dessous (voir README,
# section "Configurer l'envoi d'e-mails").
MAIL_MAILER=log
MAIL_SCHEME=null
MAIL_HOST=127.0.0.1
MAIL_PORT=2525
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_FROM_ADDRESS="contact@parallelium.app"
MAIL_FROM_NAME="${APP_NAME}"

# Exemple avec Brevo (ex-Sendinblue, offre gratuite ~300 e-mails/jour,
# fonctionne bien depuis Madagascar) : decommente et remplis, puis mets
# MAIL_MAILER=smtp ci-dessus.
# MAIL_MAILER=smtp
# MAIL_HOST=smtp-relay.brevo.com
# MAIL_PORT=587
# MAIL_USERNAME=ton-identifiant-brevo
# MAIL_PASSWORD=ta-cle-smtp-brevo
# MAIL_ENCRYPTION=tls

VITE_APP_NAME="${APP_NAME}"

# --- Parallelium : parametres metier par defaut ---
PARALLELIUM_DEFAULT_CURRENCY=MGA
PARALLELIUM_DEFAULT_CURRENCY_SYMBOL=Ar
PARALLELIUM_DEFAULT_TIMEZONE=Indian/Antananarivo
PARALLELIUM_INVOICE_PREFIX=PAR
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

    public function test_owner_can_resend_an_invitation(): void
    {
        $company = Company::factory()->create();
        $owner = $this->ownerFor($company);
        $sellerRole = Role::whereNull('company_id')->where('slug', 'seller')->first();
        $employee = User::factory()->create(['company_id' => $company->id, 'role_id' => $sellerRole->id]);

        $this->actingAs($owner)
            ->post(route('employees.resend-invite', $employee))
            ->assertRedirect();

        Notification::assertSentTo($employee, ResetPassword::class);
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
echo "Regarde storage/logs/laravel.log pour trouver le lien invitation en attendant de configurer un vrai SMTP (voir README)."
