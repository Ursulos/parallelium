<x-layouts.app title="Paramètres">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Paramètres</h2>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
    @endif
    @if ($errors->any())
        <x-alert type="error" class="mb-4">{{ $errors->first() }}</x-alert>
    @endif

    <x-card class="mb-6">
        <h3 class="mb-3 text-sm font-semibold text-slate-700">Entreprise</h3>
        <dl class="grid gap-3 sm:grid-cols-2">
            <div>
                <dt class="text-xs text-slate-400">Nom</dt>
                <dd class="text-sm font-medium text-slate-800">{{ $company->name }}</dd>
            </div>
            <div>
                <dt class="text-xs text-slate-400">Devise</dt>
                <dd class="text-sm font-medium text-slate-800">{{ $company->currency }} ({{ $company->currencySymbol() }})</dd>
            </div>
            <div>
                <dt class="text-xs text-slate-400">Téléphone</dt>
                <dd class="text-sm font-medium text-slate-800">{{ $company->phone ?? '—' }}</dd>
            </div>
            <div>
                <dt class="text-xs text-slate-400">Préfixe des factures</dt>
                <dd class="text-sm font-medium text-slate-800">{{ $company->invoice_prefix }}-{{ date('Y') }}-000001</dd>
            </div>
        </dl>
    </x-card>

    <div class="mb-6">
        <h3 class="mb-3 text-sm font-semibold text-slate-700">Utilisation de votre plan</h3>
        <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            @foreach ($usage as $resource => $u)
                @php
                    $labels = ['products' => 'Produits', 'users' => 'Utilisateurs', 'customers' => 'Clients', 'sales_per_month' => 'Ventes ce mois'];
                    $percent = $u['limit'] ? min(100, round(($u['used'] / max($u['limit'], 1)) * 100)) : 0;
                @endphp
                <x-card>
                    <p class="text-xs text-slate-400">{{ $labels[$resource] }}</p>
                    <p class="mt-1 text-lg font-bold text-slate-900">
                        {{ $u['used'] }} <span class="text-sm font-normal text-slate-400">/ {{ $u['limit'] ?? '∞' }}</span>
                    </p>
                    @if ($u['limit'])
                        <div class="mt-2 h-1.5 w-full rounded-full bg-slate-100">
                            <div class="h-1.5 rounded-full {{ $percent >= 90 ? 'bg-red-500' : 'bg-brand-500' }}" style="width: {{ $percent }}%"></div>
                        </div>
                    @endif
                </x-card>
            @endforeach
        </div>
    </div>

    <div>
        <h3 class="mb-1 text-sm font-semibold text-slate-700">Abonnement</h3>
        <p class="mb-4 text-xs text-slate-400">Plan actuel : <span class="font-semibold text-brand-700">{{ $plans[$company->subscription->plan]['label'] ?? '—' }}</span></p>

        <div class="grid gap-4 sm:grid-cols-3">
            @foreach ($plans as $slug => $plan)
                @continue(! ($plan['self_service'] ?? false))
                @php($isCurrent = $company->subscription->plan === $slug)
                <div class="relative flex flex-col rounded-2xl border-2 bg-white p-5 {{ $isCurrent ? 'border-brand-500 shadow-lg shadow-brand-500/10' : 'border-slate-100' }}">
                    @if ($isCurrent)
                        <x-badge tone="brand" class="absolute -top-3 left-5">Plan actuel</x-badge>
                    @endif

                    <p class="text-lg font-extrabold text-slate-900">{{ $plan['label'] }}</p>
                    <p class="mt-0.5 text-xs text-slate-400">{{ $plan['tagline'] }}</p>

                    <p class="mt-4 text-2xl font-extrabold text-brand-700">
                        @if ($plan['price'] == 0)
                            Gratuit
                        @else
                            {{ \App\Support\Money::format($plan['price'], $company->currency) }}
                            <span class="text-sm font-normal text-slate-400">/mois</span>
                        @endif
                    </p>
                    @if ($plan['price'] > 0)
                        <p class="text-xs text-slate-400">
                            ou {{ \App\Support\Money::format($plan['price_yearly'], $company->currency) }}/an (2 mois offerts)
                        </p>
                    @endif

                    <ul class="mt-4 flex-1 space-y-1.5 text-sm text-slate-600">
                        <li>{{ $plan['limits']['products'] ?? 'Produits illimités' }} @if($plan['limits']['products']) produits @endif</li>
                        <li>{{ $plan['limits']['users'] ?? 'Utilisateurs illimités' }} @if($plan['limits']['users']) utilisateur(s) @endif</li>
                        <li>{{ $plan['limits']['customers'] ?? 'Clients illimités' }} @if($plan['limits']['customers']) clients @endif</li>
                        <li>{{ $plan['limits']['sales_per_month'] ?? 'Ventes illimitées' }} @if($plan['limits']['sales_per_month']) ventes/mois @endif</li>
                        @if (in_array('reports', $plan['features']))
                            <li>Rapports</li>
                        @endif
                        @if (in_array('advanced_reports', $plan['features']))
                            <li>Rapports avancés</li>
                        @endif
                        @if (in_array('employees', $plan['features']))
                            <li>Gestion des employés</li>
                        @endif
                    </ul>

                    @can('settings.manage')
                        @unless ($isCurrent)
                            <form method="POST" action="{{ route('settings.subscription') }}" class="mt-4">
                                @csrf
                                <input type="hidden" name="plan" value="{{ $slug }}">
                                <x-button type="submit" variant="secondary" class="w-full justify-center">Passer à ce plan</x-button>
                            </form>
                        @endunless
                    @endcan
                </div>
            @endforeach
        </div>

        @if ($company->subscription->plan === 'enterprise')
            <x-alert type="info" class="mt-4">
                Votre entreprise bénéficie d'un accompagnement sur mesure (plan Entreprise). Pour toute question sur votre forfait, contactez le support Parallelium.
            </x-alert>
        @else
            <div class="mt-4 flex items-center justify-between rounded-2xl border border-dashed border-slate-200 px-5 py-4">
                <div>
                    <p class="text-sm font-semibold text-slate-700">Besoin de plus ?</p>
                    <p class="text-xs text-slate-400">Volume important, plusieurs points de vente, besoins spécifiques — parlons-en.</p>
                </div>
                <x-button href="mailto:contact@parallelium.app?subject=Besoin%20d%27un%20plan%20sur%20mesure" variant="ghost" size="sm">Nous contacter</x-button>
            </div>
        @endif

        <p class="mt-4 text-xs text-slate-400">
            Paiement par MVola, Orange Money, Airtel Money ou virement — un conseiller vous contacte après le changement de plan pour confirmer le règlement. L'intégration du paiement en ligne est prévue pour une prochaine version.
        </p>
    </div>
</x-layouts.app>
