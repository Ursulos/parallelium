<nav class="fixed inset-x-0 bottom-0 z-30 border-t border-slate-100 bg-white/95 backdrop-blur pb-[env(safe-area-inset-bottom)] lg:hidden">
    <div class="relative mx-auto grid max-w-lg grid-cols-5 items-center px-2 py-2">
        <?php if (isset($component)) { $__componentOriginalc288df21a34f9e0759b8230da0007847 = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginalc288df21a34f9e0759b8230da0007847 = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.bottom-nav-item','data' => ['routeName' => 'dashboard','icon' => 'home','label' => 'Accueil']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('bottom-nav-item'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['route-name' => 'dashboard','icon' => 'home','label' => 'Accueil']); ?>
<?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginalc288df21a34f9e0759b8230da0007847)): ?>
<?php $attributes = $__attributesOriginalc288df21a34f9e0759b8230da0007847; ?>
<?php unset($__attributesOriginalc288df21a34f9e0759b8230da0007847); ?>
<?php endif; ?>
<?php if (isset($__componentOriginalc288df21a34f9e0759b8230da0007847)): ?>
<?php $component = $__componentOriginalc288df21a34f9e0759b8230da0007847; ?>
<?php unset($__componentOriginalc288df21a34f9e0759b8230da0007847); ?>
<?php endif; ?>
        <?php if (isset($component)) { $__componentOriginalc288df21a34f9e0759b8230da0007847 = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginalc288df21a34f9e0759b8230da0007847 = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.bottom-nav-item','data' => ['routeName' => 'sales.index','icon' => 'sales','label' => 'Ventes']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('bottom-nav-item'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['route-name' => 'sales.index','icon' => 'sales','label' => 'Ventes']); ?>
<?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginalc288df21a34f9e0759b8230da0007847)): ?>
<?php $attributes = $__attributesOriginalc288df21a34f9e0759b8230da0007847; ?>
<?php unset($__attributesOriginalc288df21a34f9e0759b8230da0007847); ?>
<?php endif; ?>
<?php if (isset($__componentOriginalc288df21a34f9e0759b8230da0007847)): ?>
<?php $component = $__componentOriginalc288df21a34f9e0759b8230da0007847; ?>
<?php unset($__componentOriginalc288df21a34f9e0759b8230da0007847); ?>
<?php endif; ?>

        <div class="flex items-center justify-center">
            <button
                type="button"
                x-data
                @click="$dispatch('open-quick-actions')"
                class="-mt-8 flex h-14 w-14 items-center justify-center rounded-full bg-brand-gradient text-xl text-white shadow-lg shadow-brand-500/40 active:scale-95 transition">
                <?php if (isset($component)) { $__componentOriginalce262628e3a8d44dc38fd1f3965181bc = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginalce262628e3a8d44dc38fd1f3965181bc = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.icon','data' => ['name' => 'plus']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('icon'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['name' => 'plus']); ?>
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
            </button>
        </div>

        <?php if (isset($component)) { $__componentOriginalc288df21a34f9e0759b8230da0007847 = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginalc288df21a34f9e0759b8230da0007847 = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.bottom-nav-item','data' => ['routeName' => 'stock.index','icon' => 'stock','label' => 'Stock']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('bottom-nav-item'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['route-name' => 'stock.index','icon' => 'stock','label' => 'Stock']); ?>
<?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginalc288df21a34f9e0759b8230da0007847)): ?>
<?php $attributes = $__attributesOriginalc288df21a34f9e0759b8230da0007847; ?>
<?php unset($__attributesOriginalc288df21a34f9e0759b8230da0007847); ?>
<?php endif; ?>
<?php if (isset($__componentOriginalc288df21a34f9e0759b8230da0007847)): ?>
<?php $component = $__componentOriginalc288df21a34f9e0759b8230da0007847; ?>
<?php unset($__componentOriginalc288df21a34f9e0759b8230da0007847); ?>
<?php endif; ?>
        <?php if (isset($component)) { $__componentOriginalc288df21a34f9e0759b8230da0007847 = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginalc288df21a34f9e0759b8230da0007847 = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.bottom-nav-item','data' => ['routeName' => 'customers.index','icon' => 'customers','label' => 'Clients']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('bottom-nav-item'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['route-name' => 'customers.index','icon' => 'customers','label' => 'Clients']); ?>
<?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginalc288df21a34f9e0759b8230da0007847)): ?>
<?php $attributes = $__attributesOriginalc288df21a34f9e0759b8230da0007847; ?>
<?php unset($__attributesOriginalc288df21a34f9e0759b8230da0007847); ?>
<?php endif; ?>
<?php if (isset($__componentOriginalc288df21a34f9e0759b8230da0007847)): ?>
<?php $component = $__componentOriginalc288df21a34f9e0759b8230da0007847; ?>
<?php unset($__componentOriginalc288df21a34f9e0759b8230da0007847); ?>
<?php endif; ?>
    </div>
</nav><?php /**PATH C:\xampp\htdocs\parallelium\resources\views/components/app-bottom-nav.blade.php ENDPATH**/ ?>