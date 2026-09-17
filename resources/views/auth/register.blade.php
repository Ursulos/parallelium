<x-layouts.guest title="Créer mon compte — Parallelium">
    <h2 class="text-2xl font-bold text-slate-900">Créez votre compte</h2>
    <p class="mt-1 text-sm text-slate-500">Votre entreprise sera prête en moins d'une minute.</p>

    @if ($errors->any())
        <x-alert type="error" class="mt-5">
            <ul class="list-inside list-disc space-y-1">
                @foreach ($errors->all() as $error)
                    <li>{{ $error }}</li>
                @endforeach
            </ul>
        </x-alert>
    @endif

    <form method="POST" action="{{ route('register') }}" class="mt-6 space-y-4">
        @csrf

        <div>
            <x-label for="company_name">Nom de votre entreprise</x-label>
            <x-input id="company_name" name="company_name" value="{{ old('company_name') }}" placeholder="Ex. Épicerie Rasoa" required autofocus />
        </div>

        <div>
            <x-label for="name">Votre nom</x-label>
            <x-input id="name" name="name" value="{{ old('name') }}" placeholder="Ex. Rasoa Andriamamy" required />
        </div>

        <div>
            <x-label for="email">Adresse e-mail</x-label>
            <x-input id="email" type="email" name="email" value="{{ old('email') }}" placeholder="vous@exemple.com" required />
        </div>

        <div>
            <x-label for="phone">Téléphone (optionnel)</x-label>
            <x-input id="phone" name="phone" value="{{ old('phone') }}" placeholder="034 xx xxx xx" />
        </div>

        <div>
            <x-label for="password">Mot de passe</x-label>
            <x-input id="password" type="password" name="password" required />
        </div>

        <div>
            <x-label for="password_confirmation">Confirmer le mot de passe</x-label>
            <x-input id="password_confirmation" type="password" name="password_confirmation" required />
        </div>

        <x-button type="submit" class="w-full justify-center" size="lg">Créer mon entreprise</x-button>
    </form>

    <p class="mt-6 text-center text-sm text-slate-500">
        Déjà un compte ?
        <a href="{{ route('login') }}" class="font-semibold text-brand-600 hover:underline">Se connecter</a>
    </p>
</x-layouts.guest>
