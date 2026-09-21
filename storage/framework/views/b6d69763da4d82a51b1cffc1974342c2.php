<?php if (isset($component)) { $__componentOriginal5863877a5171c196453bfa0bd807e410 = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginal5863877a5171c196453bfa0bd807e410 = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.layouts.app','data' => ['title' => 'Paramètres']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('layouts.app'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['title' => 'Paramètres']); ?>
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Paramètres</h2>
    </div>

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
    <?php if($errors->any()): ?>
        <?php if (isset($component)) { $__componentOriginal5194778a3a7b899dcee5619d0610f5cf = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginal5194778a3a7b899dcee5619d0610f5cf = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.alert','data' => ['type' => 'error','class' => 'mb-4']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('alert'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['type' => 'error','class' => 'mb-4']); ?><?php echo e($errors->first()); ?> <?php echo $__env->renderComponent(); ?>
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

    <?php if (isset($component)) { $__componentOriginal53747ceb358d30c0105769f8471417f6 = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginal53747ceb358d30c0105769f8471417f6 = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.card','data' => ['class' => 'mb-6']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('card'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['class' => 'mb-6']); ?>
        <h3 class="mb-3 text-sm font-semibold text-slate-700">Entreprise</h3>
        <dl class="grid gap-3 sm:grid-cols-2">
            <div>
                <dt class="text-xs text-slate-400">Nom</dt>
                <dd class="text-sm font-medium text-slate-800"><?php echo e($company->name); ?></dd>
            </div>
            <div>
                <dt class="text-xs text-slate-400">Devise</dt>
                <dd class="text-sm font-medium text-slate-800"><?php echo e($company->currency); ?> (<?php echo e($company->currencySymbol()); ?>)</dd>
            </div>
            <div>
                <dt class="text-xs text-slate-400">Téléphone</dt>
                <dd class="text-sm font-medium text-slate-800"><?php echo e($company->phone ?? '—'); ?></dd>
            </div>
            <div>
                <dt class="text-xs text-slate-400">Préfixe des factures</dt>
                <dd class="text-sm font-medium text-slate-800"><?php echo e($company->invoice_prefix); ?>-<?php echo e(date('Y')); ?>-000001</dd>
            </div>
        </dl>
     <?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginal53747ceb358d30c0105769f8471417f6)): ?>
<?php $attributes = $__attributesOriginal53747ceb358d30c0105769f8471417f6; ?>
<?php unset($__attributesOriginal53747ceb358d30c0105769f8471417f6); ?>
<?php endif; ?>
<?php if (isset($__componentOriginal53747ceb358d30c0105769f8471417f6)): ?>
<?php $component = $__componentOriginal53747ceb358d30c0105769f8471417f6; ?>
<?php unset($__componentOriginal53747ceb358d30c0105769f8471417f6); ?>
<?php endif; ?>

    <div class="mb-6">
        <h3 class="mb-3 text-sm font-semibold text-slate-700">Utilisation de votre plan</h3>
        <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <?php $__currentLoopData = $usage; $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $resource => $u): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
                <?php
                    $labels = ['products' => 'Produits', 'users' => 'Utilisateurs', 'customers' => 'Clients', 'sales_per_month' => 'Ventes ce mois'];
                    $percent = $u['limit'] ? min(100, round(($u['used'] / max($u['limit'], 1)) * 100)) : 0;
                ?>
                <?php if (isset($component)) { $__componentOriginal53747ceb358d30c0105769f8471417f6 = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginal53747ceb358d30c0105769f8471417f6 = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.card','data' => []] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('card'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes([]); ?>
                    <p class="text-xs text-slate-400"><?php echo e($labels[$resource]); ?></p>
                    <p class="mt-1 text-lg font-bold text-slate-900">
                        <?php echo e($u['used']); ?> <span class="text-sm font-normal text-slate-400">/ <?php echo e($u['limit'] ?? '∞'); ?></span>
                    </p>
                    <?php if($u['limit']): ?>
                        <div class="mt-2 h-1.5 w-full rounded-full bg-slate-100">
                            <div class="h-1.5 rounded-full <?php echo e($percent >= 90 ? 'bg-red-500' : 'bg-brand-500'); ?>" style="width: <?php echo e($percent); ?>%"></div>
                        </div>
                    <?php endif; ?>
                 <?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginal53747ceb358d30c0105769f8471417f6)): ?>
<?php $attributes = $__attributesOriginal53747ceb358d30c0105769f8471417f6; ?>
<?php unset($__attributesOriginal53747ceb358d30c0105769f8471417f6); ?>
<?php endif; ?>
<?php if (isset($__componentOriginal53747ceb358d30c0105769f8471417f6)): ?>
<?php $component = $__componentOriginal53747ceb358d30c0105769f8471417f6; ?>
<?php unset($__componentOriginal53747ceb358d30c0105769f8471417f6); ?>
<?php endif; ?>
            <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?>
        </div>
    </div>

    <div>
        <h3 class="mb-1 text-sm font-semibold text-slate-700">Abonnement</h3>
        <p class="mb-4 text-xs text-slate-400">Plan actuel : <span class="font-semibold text-brand-700"><?php echo e($plans[$company->subscription->plan]['label'] ?? '—'); ?></span></p>

        <div class="grid gap-4 sm:grid-cols-3">
            <?php $__currentLoopData = $plans; $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $slug => $plan): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
                <?php ($isCurrent = $company->subscription->plan === $slug); ?>
                <div class="relative flex flex-col rounded-2xl border-2 bg-white p-5 <?php echo e($isCurrent ? 'border-brand-500 shadow-lg shadow-brand-500/10' : 'border-slate-100'); ?>">
                    <?php if($isCurrent): ?>
                        <?php if (isset($component)) { $__componentOriginal2ddbc40e602c342e508ac696e52f8719 = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginal2ddbc40e602c342e508ac696e52f8719 = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.badge','data' => ['tone' => 'brand','class' => 'absolute -top-3 left-5']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('badge'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['tone' => 'brand','class' => 'absolute -top-3 left-5']); ?>Plan actuel <?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginal2ddbc40e602c342e508ac696e52f8719)): ?>
<?php $attributes = $__attributesOriginal2ddbc40e602c342e508ac696e52f8719; ?>
<?php unset($__attributesOriginal2ddbc40e602c342e508ac696e52f8719); ?>
<?php endif; ?>
<?php if (isset($__componentOriginal2ddbc40e602c342e508ac696e52f8719)): ?>
<?php $component = $__componentOriginal2ddbc40e602c342e508ac696e52f8719; ?>
<?php unset($__componentOriginal2ddbc40e602c342e508ac696e52f8719); ?>
<?php endif; ?>
                    <?php endif; ?>

                    <p class="text-lg font-extrabold text-slate-900"><?php echo e($plan['label']); ?></p>
                    <p class="mt-0.5 text-xs text-slate-400"><?php echo e($plan['tagline']); ?></p>

                    <p class="mt-4 text-2xl font-extrabold text-brand-700">
                        <?php if($plan['price'] == 0): ?>
                            Gratuit
                        <?php else: ?>
                            <?php echo e(\App\Support\Money::format($plan['price'], $company->currency)); ?>

                            <span class="text-sm font-normal text-slate-400">/mois</span>
                        <?php endif; ?>
                    </p>
                    <?php if($plan['price'] > 0): ?>
                        <p class="text-xs text-slate-400">
                            ou <?php echo e(\App\Support\Money::format($plan['price_yearly'], $company->currency)); ?>/an (2 mois offerts)
                        </p>
                    <?php endif; ?>

                    <ul class="mt-4 flex-1 space-y-1.5 text-sm text-slate-600">
                        <li><?php echo e($plan['limits']['products'] ?? 'Produits illimités'); ?> <?php if($plan['limits']['products']): ?> produits <?php endif; ?></li>
                        <li><?php echo e($plan['limits']['users'] ?? 'Utilisateurs illimités'); ?> <?php if($plan['limits']['users']): ?> utilisateur(s) <?php endif; ?></li>
                        <li><?php echo e($plan['limits']['customers'] ?? 'Clients illimités'); ?> <?php if($plan['limits']['customers']): ?> clients <?php endif; ?></li>
                        <li><?php echo e($plan['limits']['sales_per_month'] ?? 'Ventes illimitées'); ?> <?php if($plan['limits']['sales_per_month']): ?> ventes/mois <?php endif; ?></li>
                        <?php if(in_array('reports', $plan['features'])): ?>
                            <li>Rapports</li>
                        <?php endif; ?>
                        <?php if(in_array('advanced_reports', $plan['features'])): ?>
                            <li>Rapports avancés</li>
                        <?php endif; ?>
                        <?php if(in_array('employees', $plan['features'])): ?>
                            <li>Gestion des employés</li>
                        <?php endif; ?>
                    </ul>

                    <?php if (app(\Illuminate\Contracts\Auth\Access\Gate::class)->check('settings.manage')): ?>
                        <?php if (! ($isCurrent)): ?>
                            <form method="POST" action="<?php echo e(route('settings.subscription')); ?>" class="mt-4">
                                <?php echo csrf_field(); ?>
                                <input type="hidden" name="plan" value="<?php echo e($slug); ?>">
                                <?php if (isset($component)) { $__componentOriginald0f1fd2689e4bb7060122a5b91fe8561 = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginald0f1fd2689e4bb7060122a5b91fe8561 = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.button','data' => ['type' => 'submit','variant' => 'secondary','class' => 'w-full justify-center']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('button'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['type' => 'submit','variant' => 'secondary','class' => 'w-full justify-center']); ?>Passer à ce plan <?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginald0f1fd2689e4bb7060122a5b91fe8561)): ?>
<?php $attributes = $__attributesOriginald0f1fd2689e4bb7060122a5b91fe8561; ?>
<?php unset($__attributesOriginald0f1fd2689e4bb7060122a5b91fe8561); ?>
<?php endif; ?>
<?php if (isset($__componentOriginald0f1fd2689e4bb7060122a5b91fe8561)): ?>
<?php $component = $__componentOriginald0f1fd2689e4bb7060122a5b91fe8561; ?>
<?php unset($__componentOriginald0f1fd2689e4bb7060122a5b91fe8561); ?>
<?php endif; ?>
                            </form>
                        <?php endif; ?>
                    <?php endif; ?>
                </div>
            <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?>
        </div>

        <p class="mt-4 text-xs text-slate-400">
            Paiement par MVola, Orange Money, Airtel Money ou virement — un conseiller vous contacte après le changement de plan pour confirmer le règlement. L'intégration du paiement en ligne est prévue pour une prochaine version.
        </p>
    </div>
 <?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginal5863877a5171c196453bfa0bd807e410)): ?>
<?php $attributes = $__attributesOriginal5863877a5171c196453bfa0bd807e410; ?>
<?php unset($__attributesOriginal5863877a5171c196453bfa0bd807e410); ?>
<?php endif; ?>
<?php if (isset($__componentOriginal5863877a5171c196453bfa0bd807e410)): ?>
<?php $component = $__componentOriginal5863877a5171c196453bfa0bd807e410; ?>
<?php unset($__componentOriginal5863877a5171c196453bfa0bd807e410); ?>
<?php endif; ?>
<?php /**PATH C:\xampp\htdocs\parallelium\resources\views/settings/index.blade.php ENDPATH**/ ?>