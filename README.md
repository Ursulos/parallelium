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
