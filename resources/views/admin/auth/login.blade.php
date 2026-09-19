<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>Administration — Parallelium</title>
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="flex min-h-screen items-center justify-center bg-slate-950 px-4">
    <div class="w-full max-w-sm rounded-3xl bg-white p-8 shadow-2xl">
        <div class="mb-6 flex items-center gap-2 text-base font-extrabold text-brand-800">
            <span class="flex h-8 w-8 items-center justify-center rounded-full bg-brand-gradient text-sm text-white"><x-icon name="logo" /></span>
            Parallelium
            <span class="ml-1 rounded-full bg-slate-100 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-slate-500">Administration</span>
        </div>

        @if ($errors->any())
            <x-alert type="error" class="mb-4">{{ $errors->first() }}</x-alert>
        @endif

        <form method="POST" action="{{ route('admin.login') }}" class="space-y-4">
            @csrf

            <div>
                <x-label for="email">Adresse e-mail</x-label>
                <x-input id="email" type="email" name="email" value="{{ old('email') }}" required autofocus />
            </div>

            <div>
                <x-label for="password">Mot de passe</x-label>
                <x-input id="password" type="password" name="password" required />
            </div>

            <x-button type="submit" class="w-full justify-center" size="lg">Se connecter</x-button>
        </form>

        <p class="mt-6 text-center text-xs text-slate-400">
            Réservé aux administrateurs de la plateforme Parallelium.
        </p>
    </div>
</body>
</html>
