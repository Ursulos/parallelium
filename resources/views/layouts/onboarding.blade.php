<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>{{ $title ?? 'Bienvenue — Parallelium' }}</title>
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="min-h-screen bg-brand-gradient">
    <div class="flex min-h-screen items-center justify-center px-4 py-10">
        <div class="w-full max-w-lg rounded-3xl bg-white p-6 shadow-2xl sm:p-8">
            <div class="mb-6 flex items-center gap-2 text-base font-extrabold text-brand-800">
                <span class="flex h-8 w-8 items-center justify-center rounded-full bg-brand-gradient text-sm text-white">◆</span>
                Parallelium
            </div>

            {{ $slot }}
        </div>
    </div>
</body>
</html>
