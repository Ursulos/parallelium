<?php
    // Liste de candidats classés par priorité, filtrée par permission ET
    // par existence de la route. On ne prend que les 4 premiers
    // autorisés : jamais d'emplacement vide grisé, la barre s'adapte
    // simplement au rôle de l'utilisateur (flex + justify-around, pas de
    // grille figée à 5 colonnes).
    $bottomNavCandidates = collect([
        ['route' => 'dashboard', 'icon' => 'home', 'label' => 'Accueil', 'permission' => 'dashboard.view'],
        ['route' => 'sales.index', 'icon' => 'sales', 'label' => 'Ventes', 'permission' => 'sales.view'],
        ['route' => 'stock.index', 'icon' => 'stock', 'label' => 'Stock', 'permission' => 'stock.view'],
        ['route' => 'customers.index', 'icon' => 'customers', 'label' => 'Clients', 'permission' => 'customers.view'],
        ['route' => 'expenses.index', 'icon' => 'expenses', 'label' => 'Dépenses', 'permission' => 'expenses.view'],
        ['route' => 'reports.index', 'icon' => 'reports', 'label' => 'Rapports', 'permission' => 'reports.view'],
    ])->filter(fn ($c) => auth()->user()?->can($c['permission']) && \Illuminate\Support\Facades\Route::has($c['route']))
      ->take(4)
      ->values();

    $bottomNavMid = (int) ceil($bottomNavCandidates->count() / 2);
    $bottomNavLeft = $bottomNavCandidates->slice(0, $bottomNavMid);
    $bottomNavRight = $bottomNavCandidates->slice($bottomNavMid);
?>

<nav class="fixed inset-x-0 bottom-0 z-30 border-t border-slate-100 bg-white/95 backdrop-blur pb-[env(safe-area-inset-bottom)] lg:hidden">
    <div class="relative mx-auto flex max-w-lg items-center justify-around px-2 py-2">
        <?php $__currentLoopData = $bottomNavLeft; $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $item): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
            <?php if (isset($component)) { $__componentOriginalc288df21a34f9e0759b8230da0007847 = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginalc288df21a34f9e0759b8230da0007847 = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.bottom-nav-item','data' => ['routeName' => $item['route'],'icon' => $item['icon'],'label' => $item['label']]] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('bottom-nav-item'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['route-name' => \Illuminate\View\Compilers\BladeCompiler::sanitizeComponentAttribute($item['route']),'icon' => \Illuminate\View\Compilers\BladeCompiler::sanitizeComponentAttribute($item['icon']),'label' => \Illuminate\View\Compilers\BladeCompiler::sanitizeComponentAttribute($item['label'])]); ?>
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
        <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?>

        <?php if (app(\Illuminate\Contracts\Auth\Access\Gate::class)->any(['sales.create', 'expenses.create', 'customers.create', 'products.create'])): ?>
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
        <?php endif; ?>

        <?php $__currentLoopData = $bottomNavRight; $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $item): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
            <?php if (isset($component)) { $__componentOriginalc288df21a34f9e0759b8230da0007847 = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginalc288df21a34f9e0759b8230da0007847 = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.bottom-nav-item','data' => ['routeName' => $item['route'],'icon' => $item['icon'],'label' => $item['label']]] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('bottom-nav-item'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['route-name' => \Illuminate\View\Compilers\BladeCompiler::sanitizeComponentAttribute($item['route']),'icon' => \Illuminate\View\Compilers\BladeCompiler::sanitizeComponentAttribute($item['icon']),'label' => \Illuminate\View\Compilers\BladeCompiler::sanitizeComponentAttribute($item['label'])]); ?>
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
        <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?>
    </div>
</nav>
<?php /**PATH C:\xampp\htdocs\parallelium\resources\views/components/app-bottom-nav.blade.php ENDPATH**/ ?>