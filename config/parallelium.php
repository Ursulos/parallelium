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
