<div
    x-data="{ open: false }"
    x-on:open-quick-actions.window="open = true"
    x-show="open"
    x-cloak
    class="fixed inset-0 z-40 lg:hidden"
    style="display: none;">
    <div class="absolute inset-0 bg-slate-900/40" x-on:click="open = false"></div>

    <div
        x-show="open"
        x-transition:enter="transition ease-out duration-200"
        x-transition:enter-start="translate-y-full"
        x-transition:enter-end="translate-y-0"
        class="absolute inset-x-0 bottom-0 rounded-t-3xl bg-white p-5 pb-[calc(env(safe-area-inset-bottom)+1.5rem)] shadow-2xl">
        <div class="mx-auto mb-4 h-1.5 w-10 rounded-full bg-slate-200"></div>
        <p class="mb-4 text-sm font-semibold text-slate-500">Action rapide</p>

        <div class="grid grid-cols-2 gap-3">
            <?php if (isset($component)) { $__componentOriginalf0cde878993a45c89c3af55822292c11 = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginalf0cde878993a45c89c3af55822292c11 = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.quick-action-item','data' => ['routeName' => 'sales.create','icon' => 'sales','label' => 'Nouvelle vente','permission' => 'sales.create']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('quick-action-item'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['route-name' => 'sales.create','icon' => 'sales','label' => 'Nouvelle vente','permission' => 'sales.create']); ?>
<?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginalf0cde878993a45c89c3af55822292c11)): ?>
<?php $attributes = $__attributesOriginalf0cde878993a45c89c3af55822292c11; ?>
<?php unset($__attributesOriginalf0cde878993a45c89c3af55822292c11); ?>
<?php endif; ?>
<?php if (isset($__componentOriginalf0cde878993a45c89c3af55822292c11)): ?>
<?php $component = $__componentOriginalf0cde878993a45c89c3af55822292c11; ?>
<?php unset($__componentOriginalf0cde878993a45c89c3af55822292c11); ?>
<?php endif; ?>
            <?php if (isset($component)) { $__componentOriginalf0cde878993a45c89c3af55822292c11 = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginalf0cde878993a45c89c3af55822292c11 = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.quick-action-item','data' => ['routeName' => 'expenses.create','icon' => 'expenses','label' => 'Nouvelle dépense','permission' => 'expenses.create']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('quick-action-item'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['route-name' => 'expenses.create','icon' => 'expenses','label' => 'Nouvelle dépense','permission' => 'expenses.create']); ?>
<?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginalf0cde878993a45c89c3af55822292c11)): ?>
<?php $attributes = $__attributesOriginalf0cde878993a45c89c3af55822292c11; ?>
<?php unset($__attributesOriginalf0cde878993a45c89c3af55822292c11); ?>
<?php endif; ?>
<?php if (isset($__componentOriginalf0cde878993a45c89c3af55822292c11)): ?>
<?php $component = $__componentOriginalf0cde878993a45c89c3af55822292c11; ?>
<?php unset($__componentOriginalf0cde878993a45c89c3af55822292c11); ?>
<?php endif; ?>
            <?php if (isset($component)) { $__componentOriginalf0cde878993a45c89c3af55822292c11 = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginalf0cde878993a45c89c3af55822292c11 = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.quick-action-item','data' => ['routeName' => 'customers.create','icon' => 'customers','label' => 'Nouveau client','permission' => 'customers.create']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('quick-action-item'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['route-name' => 'customers.create','icon' => 'customers','label' => 'Nouveau client','permission' => 'customers.create']); ?>
<?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginalf0cde878993a45c89c3af55822292c11)): ?>
<?php $attributes = $__attributesOriginalf0cde878993a45c89c3af55822292c11; ?>
<?php unset($__attributesOriginalf0cde878993a45c89c3af55822292c11); ?>
<?php endif; ?>
<?php if (isset($__componentOriginalf0cde878993a45c89c3af55822292c11)): ?>
<?php $component = $__componentOriginalf0cde878993a45c89c3af55822292c11; ?>
<?php unset($__componentOriginalf0cde878993a45c89c3af55822292c11); ?>
<?php endif; ?>
            <?php if (isset($component)) { $__componentOriginalf0cde878993a45c89c3af55822292c11 = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginalf0cde878993a45c89c3af55822292c11 = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.quick-action-item','data' => ['routeName' => 'products.create','icon' => 'products','label' => 'Ajouter produit','permission' => 'products.create']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('quick-action-item'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['route-name' => 'products.create','icon' => 'products','label' => 'Ajouter produit','permission' => 'products.create']); ?>
<?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginalf0cde878993a45c89c3af55822292c11)): ?>
<?php $attributes = $__attributesOriginalf0cde878993a45c89c3af55822292c11; ?>
<?php unset($__attributesOriginalf0cde878993a45c89c3af55822292c11); ?>
<?php endif; ?>
<?php if (isset($__componentOriginalf0cde878993a45c89c3af55822292c11)): ?>
<?php $component = $__componentOriginalf0cde878993a45c89c3af55822292c11; ?>
<?php unset($__componentOriginalf0cde878993a45c89c3af55822292c11); ?>
<?php endif; ?>
        </div>
    </div>
</div>
<?php /**PATH C:\xampp\htdocs\parallelium\resources\views/components/quick-actions-sheet.blade.php ENDPATH**/ ?>