<x-layouts.onboarding title="Bienvenue — Parallelium">
    <p class="text-sm font-semibold text-brand-600">Étape 1 sur 1</p>
    <h1 class="mt-1 text-2xl font-bold text-slate-900">Bienvenue sur Parallelium 👋</h1>
    <p class="mt-2 text-sm text-slate-500">Parlez-nous un peu de {{ $company->name }} pour personnaliser votre espace.</p>

    <form method="POST" action="{{ route('onboarding.update') }}" class="mt-6 space-y-4">
        @csrf
        @method('PUT')

        <div>
            <x-label for="business_type">Type d'activité</x-label>
            <x-input id="business_type" name="business_type" value="{{ old('business_type', $company->business_type) }}" placeholder="Ex. Épicerie, boutique, atelier..." />
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

    <form method="POST" action="{{ route('onboarding.finish') }}" class="mt-3">
        @csrf
        <x-button type="submit" variant="secondary" class="w-full justify-center" size="lg">
            C'est prêt, direction le tableau de bord →
        </x-button>
    </form>

    <form method="POST" action="{{ route('onboarding.skip') }}" class="mt-2">
        @csrf
        <button type="submit" class="w-full text-center text-xs font-medium text-slate-400 hover:text-slate-600">
            Passer cette étape
        </button>
    </form>
</x-layouts.onboarding>
