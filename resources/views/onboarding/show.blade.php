<x-layouts.onboarding title="Bienvenue — Parallelium">
    <p class="text-sm font-semibold text-brand-600">Étape 1 sur 1</p>
    <h1 class="mt-1 text-2xl font-bold text-slate-900">Bienvenue sur Parallelium</h1>
    <p class="mt-2 text-sm text-slate-500">Parlez-nous un peu de {{ $company->name }} pour personnaliser votre espace.</p>

    @if (session('status'))
        <x-alert type="success" class="mt-4">{{ session('status') }}</x-alert>
    @endif

    @php
        $isKnownType = array_key_exists($company->business_type, $businessTypes);
        $selected = old('business_type', $isKnownType ? $company->business_type : ($company->business_type ? 'autre' : null));
    @endphp

    <form method="POST" action="{{ route('onboarding.update') }}" class="mt-6 space-y-4" x-data="{ type: '{{ $selected }}' }">
        @csrf
        @method('PUT')

        <div>
            <x-label for="business_type">Type d'activité</x-label>
            <select id="business_type" name="business_type" x-model="type" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400">
                <option value="">Sélectionner...</option>
                @foreach ($businessTypes as $slug => $label)
                    <option value="{{ $slug }}" @selected($selected === $slug)>{{ $label }}</option>
                @endforeach
                <option value="autre" @selected($selected === 'autre')>Autre</option>
            </select>
            <p class="mt-1 text-xs text-slate-400">
                On vous proposera une liste de produits standards à ajouter selon votre choix.
            </p>
        </div>

        <div x-show="type === 'autre'" x-cloak>
            <x-label for="business_type_other">Précisez votre activité</x-label>
            <x-input id="business_type_other" name="business_type_other" value="{{ old('business_type_other', $isKnownType ? '' : $company->business_type) }}" placeholder="Ex. Atelier de couture, salon de coiffure..." />
        </div>

        <div>
            <x-label for="phone">Téléphone de l'entreprise</x-label>
            <x-input id="phone" name="phone" value="{{ old('phone', $company->phone) }}" placeholder="034 xx xxx xx" />
        </div>

        <div>
            <x-label for="currency">Devise</x-label>
            <select id="currency" name="currency" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400">
                @foreach (config('parallelium.currencies') as $code => $c)
                    <option value="{{ $code }}" @selected(old('currency', $company->currency) === $code)>{{ $c['label'] }} ({{ $c['symbol'] }})</option>
                @endforeach
            </select>
        </div>

        <x-button type="submit" class="w-full justify-center" size="lg">Enregistrer</x-button>
    </form>

    @if ($isKnownType)
        <x-card class="mt-4">
            <p class="text-sm font-semibold text-slate-700">Produits standards disponibles</p>
            <p class="mt-1 text-xs text-slate-500">
                Nous avons une liste de produits courants pour « {{ $businessTypes[$company->business_type] }} ».
                Sans prix ni référence — à vous de les compléter ensuite selon vos fournisseurs.
            </p>
            <form method="POST" action="{{ route('onboarding.seed-catalog') }}" class="mt-3">
                @csrf
                <x-button type="submit" variant="secondary" size="sm">Ajouter ces produits à mon catalogue</x-button>
            </form>
        </x-card>
    @endif

    <form method="POST" action="{{ route('onboarding.finish') }}" class="mt-3">
        @csrf
        <x-button type="submit" variant="secondary" class="w-full justify-center" size="lg">
            C'est prêt, direction le tableau de bord
            <x-icon name="chevron-right" class="text-xs" />
        </x-button>
    </form>

    <form method="POST" action="{{ route('onboarding.skip') }}" class="mt-2">
        @csrf
        <button type="submit" class="w-full text-center text-xs font-medium text-slate-400 hover:text-slate-600">
            Passer cette étape
        </button>
    </form>
</x-layouts.onboarding>
