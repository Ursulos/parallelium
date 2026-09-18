<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="csrf-token" content="<?php echo e(csrf_token()); ?>">
    <title><?php echo e($title ?? 'Parallelium'); ?></title>
    <link rel="icon" href="<?php echo e(asset('icons/icon-192.png')); ?>">
    <?php if (isset($component)) { $__componentOriginal103f614934efd83207b28be25fed64f6 = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginal103f614934efd83207b28be25fed64f6 = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.pwa-head','data' => []] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('pwa-head'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes([]); ?>
<?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginal103f614934efd83207b28be25fed64f6)): ?>
<?php $attributes = $__attributesOriginal103f614934efd83207b28be25fed64f6; ?>
<?php unset($__attributesOriginal103f614934efd83207b28be25fed64f6); ?>
<?php endif; ?>
<?php if (isset($__componentOriginal103f614934efd83207b28be25fed64f6)): ?>
<?php $component = $__componentOriginal103f614934efd83207b28be25fed64f6; ?>
<?php unset($__componentOriginal103f614934efd83207b28be25fed64f6); ?>
<?php endif; ?>
    <?php echo app('Illuminate\Foundation\Vite')(['resources/css/app.css', 'resources/js/app.js']); ?>
</head>
<body class="min-h-screen bg-slate-50">
    <div class="grid min-h-screen lg:grid-cols-2">
        
        <div class="relative hidden flex-col justify-between overflow-hidden bg-brand-gradient p-12 text-white lg:flex">
            <div class="absolute -left-24 -top-24 h-72 w-72 rounded-full bg-white/10 blur-2xl"></div>
            <div class="absolute -bottom-32 -right-10 h-80 w-80 rounded-full bg-white/10 blur-2xl"></div>

            <div class="relative flex items-center gap-2 text-xl font-extrabold tracking-tight">
                <span class="flex h-9 w-9 items-center justify-center rounded-full bg-white/15 text-lg"><?php if (isset($component)) { $__componentOriginalce262628e3a8d44dc38fd1f3965181bc = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginalce262628e3a8d44dc38fd1f3965181bc = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.icon','data' => ['name' => 'logo']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('icon'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['name' => 'logo']); ?>
<?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginalce262628e3a8d44dc38fd1f3965181bc)): ?>
<?php $attributes = $__attributesOriginalce262628e3a8d44dc38fd1f3965181bc; ?>
<?php unset($__attributesOriginalce262628e3a8d44dc38fd1f3965181bc); ?>
<?php endif; ?>
<?php if (isset($__componentOriginalce262628e3a8d44dc38fd1f3965181bc)): ?>
<?php $component = $__componentOriginalce262628e3a8d44dc38fd1f3965181bc; ?>
<?php unset($__componentOriginalce262628e3a8d44dc38fd1f3965181bc); ?>
<?php endif; ?></span>
                Parallelium
            </div>

            <div class="relative max-w-md">
                <h1 class="text-4xl font-extrabold leading-tight">
                    Gérez votre entreprise depuis un seul endroit.
                </h1>
                <p class="mt-4 text-brand-100">
                    Ventes, stock, clients, dépenses et factures : simple, rapide et accessible
                    depuis votre téléphone.
                </p>
            </div>

            <p class="relative text-xs text-brand-200">© <?php echo e(date('Y')); ?> Parallelium — Fait pour les petites entreprises.</p>
        </div>

        
        <div class="flex flex-col justify-center px-6 py-10 sm:px-12 lg:px-16">
            <div class="mx-auto w-full max-w-sm">
                <div class="mb-8 flex items-center gap-2 text-lg font-extrabold text-brand-800 lg:hidden">
                    <span class="flex h-8 w-8 items-center justify-center rounded-full bg-brand-gradient text-sm text-white"><?php if (isset($component)) { $__componentOriginalce262628e3a8d44dc38fd1f3965181bc = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginalce262628e3a8d44dc38fd1f3965181bc = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.icon','data' => ['name' => 'logo']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('icon'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['name' => 'logo']); ?>
<?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginalce262628e3a8d44dc38fd1f3965181bc)): ?>
<?php $attributes = $__attributesOriginalce262628e3a8d44dc38fd1f3965181bc; ?>
<?php unset($__attributesOriginalce262628e3a8d44dc38fd1f3965181bc); ?>
<?php endif; ?>
<?php if (isset($__componentOriginalce262628e3a8d44dc38fd1f3965181bc)): ?>
<?php $component = $__componentOriginalce262628e3a8d44dc38fd1f3965181bc; ?>
<?php unset($__componentOriginalce262628e3a8d44dc38fd1f3965181bc); ?>
<?php endif; ?></span>
                    Parallelium
                </div>

                <?php echo e($slot); ?>

            </div>
        </div>
    </div>
</body>
</html><?php /**PATH C:\xampp\htdocs\parallelium\resources\views/components/layouts/guest.blade.php ENDPATH**/ ?>