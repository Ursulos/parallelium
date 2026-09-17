<x-layouts.guest title="Réinitialiser le mot de passe — Parallelium">
    <h2 class="text-2xl font-bold text-slate-900">Nouveau mot de passe</h2>

    @if ($errors->any())
        <x-alert type="error" class="mt-5">{{ $errors->first() }}</x-alert>
    @endif

    <form method="POST" action="{{ route('password.store') }}" class="mt-6 space-y-4">
        @csrf
        <input type="hidden" name="token" value="{{ $request->route('token') }}">

        <div>
            <x-label for="email">Adresse e-mail</x-label>
            <x-input id="email" type="email" name="email" value="{{ old('email', $request->email) }}" required autofocus />
        </div>

        <div>
            <x-label for="password">Nouveau mot de passe</x-label>
            <x-input id="password" type="password" name="password" required />
        </div>

        <div>
            <x-label for="password_confirmation">Confirmer le mot de passe</x-label>
            <x-input id="password_confirmation" type="password" name="password_confirmation" required />
        </div>

        <x-button type="submit" class="w-full justify-center" size="lg">Réinitialiser le mot de passe</x-button>
    </form>
</x-layouts.guest>
