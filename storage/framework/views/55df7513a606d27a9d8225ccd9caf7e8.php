<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="csrf-token" content="<?php echo e(csrf_token()); ?>">
    <title><?php echo e($title ?? 'Parallelium'); ?></title>
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
<body class="min-h-screen bg-slate-50" x-cloak>
    <div class="flex min-h-screen">
        <?php if (isset($component)) { $__componentOriginaldb4249790d48373143e5b6a3fcfb71cf = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginaldb4249790d48373143e5b6a3fcfb71cf = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.app-sidebar','data' => []] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('app-sidebar'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes([]); ?>
<?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginaldb4249790d48373143e5b6a3fcfb71cf)): ?>
<?php $attributes = $__attributesOriginaldb4249790d48373143e5b6a3fcfb71cf; ?>
<?php unset($__attributesOriginaldb4249790d48373143e5b6a3fcfb71cf); ?>
<?php endif; ?>
<?php if (isset($__componentOriginaldb4249790d48373143e5b6a3fcfb71cf)): ?>
<?php $component = $__componentOriginaldb4249790d48373143e5b6a3fcfb71cf; ?>
<?php unset($__componentOriginaldb4249790d48373143e5b6a3fcfb71cf); ?>
<?php endif; ?>

        <div class="flex min-w-0 flex-1 flex-col">
            <?php if (isset($component)) { $__componentOriginal5d959a11ff826b3fd89e60f60adf4cb2 = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginal5d959a11ff826b3fd89e60f60adf4cb2 = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.app-header','data' => ['title' => $title ?? null]] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('app-header'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['title' => \Illuminate\View\Compilers\BladeCompiler::sanitizeComponentAttribute($title ?? null)]); ?>
<?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginal5d959a11ff826b3fd89e60f60adf4cb2)): ?>
<?php $attributes = $__attributesOriginal5d959a11ff826b3fd89e60f60adf4cb2; ?>
<?php unset($__attributesOriginal5d959a11ff826b3fd89e60f60adf4cb2); ?>
<?php endif; ?>
<?php if (isset($__componentOriginal5d959a11ff826b3fd89e60f60adf4cb2)): ?>
<?php $component = $__componentOriginal5d959a11ff826b3fd89e60f60adf4cb2; ?>
<?php unset($__componentOriginal5d959a11ff826b3fd89e60f60adf4cb2); ?>
<?php endif; ?>

            <main class="flex-1 px-4 pb-28 pt-4 lg:px-8 lg:pb-8 lg:pt-6">
                <?php if(session('status')): ?>
                    <?php if (isset($component)) { $__componentOriginal5194778a3a7b899dcee5619d0610f5cf = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginal5194778a3a7b899dcee5619d0610f5cf = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.alert','data' => ['type' => 'success','class' => 'mb-4']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('alert'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['type' => 'success','class' => 'mb-4']); ?><?php echo e(session('status')); ?> <?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginal5194778a3a7b899dcee5619d0610f5cf)): ?>
<?php $attributes = $__attributesOriginal5194778a3a7b899dcee5619d0610f5cf; ?>
<?php unset($__attributesOriginal5194778a3a7b899dcee5619d0610f5cf); ?>
<?php endif; ?>
<?php if (isset($__componentOriginal5194778a3a7b899dcee5619d0610f5cf)): ?>
<?php $component = $__componentOriginal5194778a3a7b899dcee5619d0610f5cf; ?>
<?php unset($__componentOriginal5194778a3a7b899dcee5619d0610f5cf); ?>
<?php endif; ?>
                <?php endif; ?>

                <?php echo e($slot); ?>

            </main>
        </div>
    </div>

    <?php if (isset($component)) { $__componentOriginal5ff059bb4b2dd1f491ebb181fcf315ec = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginal5ff059bb4b2dd1f491ebb181fcf315ec = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.app-bottom-nav','data' => []] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('app-bottom-nav'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes([]); ?>
<?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginal5ff059bb4b2dd1f491ebb181fcf315ec)): ?>
<?php $attributes = $__attributesOriginal5ff059bb4b2dd1f491ebb181fcf315ec; ?>
<?php unset($__attributesOriginal5ff059bb4b2dd1f491ebb181fcf315ec); ?>
<?php endif; ?>
<?php if (isset($__componentOriginal5ff059bb4b2dd1f491ebb181fcf315ec)): ?>
<?php $component = $__componentOriginal5ff059bb4b2dd1f491ebb181fcf315ec; ?>
<?php unset($__componentOriginal5ff059bb4b2dd1f491ebb181fcf315ec); ?>
<?php endif; ?>
    <?php if (isset($component)) { $__componentOriginal9c0815fd7b7a89619f3ea930812a21fd = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginal9c0815fd7b7a89619f3ea930812a21fd = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.quick-actions-sheet','data' => []] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('quick-actions-sheet'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes([]); ?>
<?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginal9c0815fd7b7a89619f3ea930812a21fd)): ?>
<?php $attributes = $__attributesOriginal9c0815fd7b7a89619f3ea930812a21fd; ?>
<?php unset($__attributesOriginal9c0815fd7b7a89619f3ea930812a21fd); ?>
<?php endif; ?>
<?php if (isset($__componentOriginal9c0815fd7b7a89619f3ea930812a21fd)): ?>
<?php $component = $__componentOriginal9c0815fd7b7a89619f3ea930812a21fd; ?>
<?php unset($__componentOriginal9c0815fd7b7a89619f3ea930812a21fd); ?>
<?php endif; ?>
    <?php if (isset($component)) { $__componentOriginal5b6745fadc65cdc3052b92baf193c2e8 = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginal5b6745fadc65cdc3052b92baf193c2e8 = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.pwa-install-banner','data' => []] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('pwa-install-banner'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes([]); ?>
<?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginal5b6745fadc65cdc3052b92baf193c2e8)): ?>
<?php $attributes = $__attributesOriginal5b6745fadc65cdc3052b92baf193c2e8; ?>
<?php unset($__attributesOriginal5b6745fadc65cdc3052b92baf193c2e8); ?>
<?php endif; ?>
<?php if (isset($__componentOriginal5b6745fadc65cdc3052b92baf193c2e8)): ?>
<?php $component = $__componentOriginal5b6745fadc65cdc3052b92baf193c2e8; ?>
<?php unset($__componentOriginal5b6745fadc65cdc3052b92baf193c2e8); ?>
<?php endif; ?>
    <?php if (isset($component)) { $__componentOriginal61a8d48b8f86749719c72cd597ee85ea = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginal61a8d48b8f86749719c72cd597ee85ea = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.pwa-update-banner','data' => []] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('pwa-update-banner'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes([]); ?>
<?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginal61a8d48b8f86749719c72cd597ee85ea)): ?>
<?php $attributes = $__attributesOriginal61a8d48b8f86749719c72cd597ee85ea; ?>
<?php unset($__attributesOriginal61a8d48b8f86749719c72cd597ee85ea); ?>
<?php endif; ?>
<?php if (isset($__componentOriginal61a8d48b8f86749719c72cd597ee85ea)): ?>
<?php $component = $__componentOriginal61a8d48b8f86749719c72cd597ee85ea; ?>
<?php unset($__componentOriginal61a8d48b8f86749719c72cd597ee85ea); ?>
<?php endif; ?>
</body>
</html>
<?php /**PATH C:\xampp\htdocs\parallelium\resources\views/components/layouts/app.blade.php ENDPATH**/ ?>