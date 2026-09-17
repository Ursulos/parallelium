<?php $attributes ??= new \Illuminate\View\ComponentAttributeBag;

$__newAttributes = [];
$__propNames = \Illuminate\View\ComponentAttributeBag::extractPropNames((['routeName' => null, 'icon' => 'circle', 'label']));

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

foreach (array_filter((['routeName' => null, 'icon' => 'circle', 'label']), 'is_string', ARRAY_FILTER_USE_KEY) as $__key => $__value) {
    $$__key = $$__key ?? $__value;
}

$__defined_vars = get_defined_vars();

foreach ($attributes->all() as $__key => $__value) {
    if (array_key_exists($__key, $__defined_vars)) unset($$__key);
}

unset($__defined_vars, $__key, $__value); ?>

<?php
    $active = $routeName && request()->routeIs($routeName.'*');
    $href = $routeName && \Illuminate\Support\Facades\Route::has($routeName) ? route($routeName) : '#';
    $enabled = $routeName && \Illuminate\Support\Facades\Route::has($routeName);
?>

<a href="<?php echo e($href); ?>"
   <?php if (! ($enabled)): ?> aria-disabled="true" tabindex="-1" <?php endif; ?>
   <?php echo e($attributes->merge([
        'class' => 'group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition '
            . ($active
                ? 'bg-brand-50 text-brand-700'
                : ($enabled ? 'text-slate-600 hover:bg-slate-100' : 'text-slate-300 cursor-not-allowed')),
   ])); ?>>
    <?php if (isset($component)) { $__componentOriginalce262628e3a8d44dc38fd1f3965181bc = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginalce262628e3a8d44dc38fd1f3965181bc = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.icon','data' => ['name' => $icon,'class' => 'w-4 text-center text-base']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('icon'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['name' => \Illuminate\View\Compilers\BladeCompiler::sanitizeComponentAttribute($icon),'class' => 'w-4 text-center text-base']); ?>
<?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginalce262628e3a8d44dc38fd1f3965181bc)): ?>
<?php $attributes = $__attributesOriginalce262628e3a8d44dc38fd1f3965181bc; ?>
<?php unset($__attributesOriginalce262628e3a8d44dc38fd1f3965181bc); ?>
<?php endif; ?>
<?php if (isset($__componentOriginalce262628e3a8d44dc38fd1f3965181bc)): ?>
<?php $component = $__componentOriginalce262628e3a8d44dc38fd1f3965181bc; ?>
<?php unset($__componentOriginalce262628e3a8d44dc38fd1f3965181bc); ?>
<?php endif; ?>
    <span><?php echo e($label); ?></span>
    <?php if (! ($enabled)): ?>
        <span class="ml-auto text-[10px] font-semibold uppercase text-slate-300">bientôt</span>
    <?php endif; ?>
</a><?php /**PATH C:\xampp\htdocs\parallelium\resources\views/components/nav-link.blade.php ENDPATH**/ ?>