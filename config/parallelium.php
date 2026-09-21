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
