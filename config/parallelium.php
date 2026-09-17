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
    | App\Services\SubscriptionService::limitFor($company, 'products').
    | "null" = illimité.
    |
    */
    'plans' => [
        'free' => [
            'label' => 'Free',
            'price' => 0,
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
            'price' => 20000,
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
            'price' => 50000,
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
