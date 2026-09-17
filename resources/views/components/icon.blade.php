@props(['name', 'variant' => 'solid'])

@php
    // Mapping sémantique -> icône Font Awesome, pour ne jamais éparpiller
    // des noms de classes fa-* dans toutes les vues. Un seul endroit à
    // modifier si on change de set d'icônes plus tard.
    $map = [
        'logo' => 'chess-rook',
        'home' => 'house',
        'sales' => 'cash-register',
        'products' => 'box',
        'stock' => 'boxes-stacked',
        'customers' => 'users',
        'expenses' => 'receipt',
        'invoices' => 'file-invoice',
        'reports' => 'chart-line',
        'employees' => 'user-tie',
        'settings' => 'gear',
        'plus' => 'plus',
        'bell' => 'bell',
        'chevron-right' => 'chevron-right',
        'search' => 'magnifying-glass',
        'money' => 'sack-dollar',
        'revenue' => 'chart-line',
        'result' => 'wand-magic-sparkles',
        'package' => 'box-open',
        'credit' => 'credit-card',
        'success' => 'circle-check',
        'warning' => 'triangle-exclamation',
        'error' => 'circle-exclamation',
        'info' => 'circle-info',
    ];

    $icon = $map[$name] ?? $name;
@endphp

<i {{ $attributes->merge(['class' => "fa-{$variant} fa-{$icon}"]) }} aria-hidden="true"></i>