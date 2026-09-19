<div
    x-data="{ show: false, registration: null }"
    x-on:parallelium-update-available.window="show = true; registration = $event.detail.registration"
    x-show="show"
    x-cloak
    x-transition
    class="fixed inset-x-0 bottom-20 z-40 mx-auto w-full max-w-sm px-4 lg:bottom-6">
    <div class="flex items-center gap-3 rounded-2xl bg-slate-900 px-4 py-3 text-white shadow-xl">
        <?php if (isset($component)) { $__componentOriginalce262628e3a8d44dc38fd1f3965181bc = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginalce262628e3a8d44dc38fd1f3965181bc = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.icon','data' => ['name' => 'info','class' => 'text-brand-300']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('icon'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['name' => 'info','class' => 'text-brand-300']); ?>
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
        <p class="flex-1 text-sm">Nouvelle version disponible.</p>
        <button
            type="button"
            x-on:click="registration?.waiting?.postMessage('SKIP_WAITING'); show = false"
            class="shrink-0 rounded-lg bg-white/15 px-3 py-1.5 text-xs font-semibold hover:bg-white/25">
            Mettre à jour
        </button>
    </div>
</div>
<?php /**PATH C:\xampp\htdocs\parallelium\resources\views/components/pwa-update-banner.blade.php ENDPATH**/ ?>