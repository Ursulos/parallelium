<?php if(session('impersonating_admin_id')): ?>
    <div class="fixed inset-x-0 top-0 z-50 flex items-center justify-center gap-3 bg-amber-500 px-4 py-2 text-center text-xs font-semibold text-amber-950">
        <span>
            Support Parallelium : vous naviguez en tant que <strong><?php echo e(auth()->user()->name); ?></strong>
            (<?php echo e(session('impersonating_admin_name')); ?> est connecté en administrateur)
        </span>
        <form method="POST" action="<?php echo e(route('impersonation.stop')); ?>">
            <?php echo csrf_field(); ?>
            <button type="submit" class="rounded-full bg-amber-950/10 px-3 py-1 hover:bg-amber-950/20">
                Revenir à l'administration
            </button>
        </form>
    </div>
<?php endif; ?>
<?php /**PATH C:\xampp\htdocs\parallelium\resources\views/components/impersonation-banner.blade.php ENDPATH**/ ?>