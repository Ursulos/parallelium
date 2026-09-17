<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>{{ $title ?? 'Parallelium' }}</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🅿️</text></svg>">
    <x-pwa-head />
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="min-h-screen bg-slate-50">
    <div class="grid min-h-screen lg:grid-cols-2">
        {{-- Panneau de marque (masqué sur mobile pour aller droit au but) --}}
        <div class="relative hidden flex-col justify-between overflow-hidden bg-brand-gradient p-12 text-white lg:flex">
            <div class="absolute -left-24 -top-24 h-72 w-72 rounded-full bg-white/10 blur-2xl"></div>
            <div class="absolute -bottom-32 -right-10 h-80 w-80 rounded-full bg-white/10 blur-2xl"></div>

            <div class="relative flex items-center gap-2 text-xl font-extrabold tracking-tight">
                <span class="flex h-9 w-9 items-center justify-center rounded-full bg-white/15 text-lg">◆</span>
                Parallelium
            </div>

            <div class="relative max-w-md">
                <h1 class="text-4xl font-extrabold leading-tight">
                    Gérez votre entreprise depuis un seul endroit.
                </h1>
                <p class="mt-4 text-brand-100">
                    Ventes, stock, clients, dépenses et factures : simple, rapide et accessible
                    depuis votre téléphone.
                </p>
            </div>

            <p class="relative text-xs text-brand-200">© {{ date('Y') }} Parallelium — Fait pour les petites entreprises.</p>
        </div>

        {{-- Contenu --}}
        <div class="flex flex-col justify-center px-6 py-10 sm:px-12 lg:px-16">
            <div class="mx-auto w-full max-w-sm">
                <div class="mb-8 flex items-center gap-2 text-lg font-extrabold text-brand-800 lg:hidden">
                    <span class="flex h-8 w-8 items-center justify-center rounded-full bg-brand-gradient text-sm text-white">◆</span>
                    Parallelium
                </div>

                {{ $slot }}
            </div>
        </div>
    </div>
</body>
</html>
