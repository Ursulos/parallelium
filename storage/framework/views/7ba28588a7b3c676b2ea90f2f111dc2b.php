<?php $attributes ??= new \Illuminate\View\ComponentAttributeBag;

$__newAttributes = [];
$__propNames = \Illuminate\View\ComponentAttributeBag::extractPropNames((['name', 'variant' => 'solid']));

foreach ($attributes->all() as $__key => $__value) {
    if (in_array($__key, $__propNames)) {
        $$__key = $$__key ?? $__value;
    } else {
        $__newAttributes[$__key] = $__value;
    }
}

$attributes = new \Illuminate\View\ComponentAttributeBag($__newAttributes);

unset($__propNames);
unset($__newAttributes);

foreach (array_filter((['name', 'variant' => 'solid']), 'is_string', ARRAY_FILTER_USE_KEY) as $__key => $__value) {
    $$__key = $$__key ?? $__value;
}

$__defined_vars = get_defined_vars();

foreach ($attributes->all() as $__key => $__value) {
    if (array_key_exists($__key, $__defined_vars)) unset($$__key);
}

unset($__defined_vars, $__key, $__value); ?>

<?php
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
?>

<i <?php echo e($attributes->merge(['class' => "fa-{$variant} fa-{$icon}"])); ?> aria-hidden="true"></i><?php /**PATH C:\xampp\htdocs\parallelium\resources\views/components/icon.blade.php ENDPATH**/ ?>