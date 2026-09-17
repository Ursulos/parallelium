<x-layouts.guest title="Mot de passe oublié — Parallelium">
    <h2 class="text-2xl font-bold text-slate-900">Mot de passe oublié</h2>
    <p class="mt-1 text-sm text-slate-500">Indiquez votre e-mail, nous vous enverrons un lien de réinitialisation.</p>

    @if (session('status'))
        <x-alert type="success" class="mt-5">{{ session('status') }}</x-alert>
    @endif
    @if ($errors->any())
        <x-alert type="error" class="mt-5">{{ $errors->first() }}</x-alert>
    @endif

    <form method="POST" action="{{ route('password.email') }}" class="mt-6 space-y-4">
        @csrf
        <div>
            <x-label for="email">Adresse e-mail</x-label>
            <x-input id="email" type="email" name="email" value="{{ old('email') }}" required autofocus />
        </div>
        <x-button type="submit" class="w-full justify-center" size="lg">Envoyer le lien</x-button>
    </form>

    <p class="mt-6 text-center text-sm text-slate-500">
        <a href="{{ route('login') }}" class="font-semibold text-brand-600 hover:underline">Retour à la connexion</a>
    </p>
</x-layouts.guest>
