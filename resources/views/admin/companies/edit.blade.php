<x-layouts.admin title="Modifier {{ $company->name }}">
    <div class="mb-5">
        <a href="{{ route('admin.companies.show', $company) }}" class="text-xs font-medium text-brand-600 hover:underline">&larr; {{ $company->name }}</a>
        <h1 class="mt-1 text-xl font-bold text-slate-900">Modifier l'entreprise</h1>
    </div>

    <x-card>
        <form method="POST" action="{{ route('admin.companies.update', $company) }}" class="space-y-4">
            @csrf
            @method('PUT')

            <div>
                <x-label for="name">Nom</x-label>
                <x-input id="name" name="name" value="{{ old('name', $company->name) }}" required autofocus />
            </div>

            <div class="grid gap-4 sm:grid-cols-2">
                <div>
                    <x-label for="email">E-mail</x-label>
                    <x-input id="email" type="email" name="email" value="{{ old('email', $company->email) }}" />
                </div>
                <div>
                    <x-label for="phone">Téléphone</x-label>
                    <x-input id="phone" name="phone" value="{{ old('phone', $company->phone) }}" />
                </div>
                <div>
                    <x-label for="city">Ville</x-label>
                    <x-input id="city" name="city" value="{{ old('city', $company->city) }}" />
                </div>
                <div>
                    <x-label for="currency">Devise</x-label>
                    <select id="currency" name="currency" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400">
                        @foreach (config('parallelium.currencies') as $code => $c)
                            <option value="{{ $code }}" @selected(old('currency', $company->currency) === $code)>{{ $c['label'] }}</option>
                        @endforeach
                    </select>
                </div>
            </div>

            <div class="flex items-center gap-3 pt-2">
                <x-button type="submit">Enregistrer</x-button>
                <x-button :href="route('admin.companies.show', $company)" variant="ghost" type="button">Annuler</x-button>
            </div>
        </form>
    </x-card>
</x-layouts.admin>
