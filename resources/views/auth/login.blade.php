<x-layouts.guest title="Connexion — Parallelium">
    <h2 class="text-2xl font-bold text-slate-900">Bon retour</h2>
    <p class="mt-1 text-sm text-slate-500">Connectez-vous pour gérer votre entreprise.</p>

    @if (session('status'))
        <x-alert type="success" class="mt-5">{{ session('status') }}</x-alert>
    @endif

    @if ($errors->any())
        <x-alert type="error" class="mt-5">{{ $errors->first() }}</x-alert>
    @endif

    <form method="POST" action="{{ route('login') }}" class="mt-6 space-y-4">
        @csrf

        <div>
            <x-label for="email">Adresse e-mail</x-label>
            <x-input id="email" type="email" name="email" value="{{ old('email') }}" required autofocus />
        </div>

        <div>
            <div class="flex items-center justify-between">
                <x-label for="password">Mot de passe</x-label>
                <a href="{{ route('password.request') }}" class="text-xs font-semibold text-brand-600 hover:underline">Mot de passe oublié ?</a>
            </div>
            <x-input id="password" type="password" name="password" required />
        </div>

        <label class="flex items-center gap-2 text-sm text-slate-500">
            <input type="checkbox" name="remember" class="rounded border-slate-300 text-brand-600 focus:ring-brand-400">
            Se souvenir de moi
        </label>

        <x-button type="submit" class="w-full justify-center" size="lg">Se connecter</x-button>
    </form>

    <p class="mt-6 text-center text-sm text-slate-500">
        Pas encore de compte ?
        <a href="{{ route('register') }}" class="font-semibold text-brand-600 hover:underline">Créer un compte</a>
    </p>
</x-layouts.guest>