<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>{{ $title ?? 'Parallelium' }}</title>
    <x-pwa-head />
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="min-h-screen bg-slate-50" x-cloak>
    <div class="flex min-h-screen">
        <x-app-sidebar />

        <div class="flex min-w-0 flex-1 flex-col">
            <x-app-header :title="$title ?? null" />

            <main class="flex-1 px-4 pb-28 pt-4 lg:px-8 lg:pb-8 lg:pt-6">
                @if (session('status'))
                    <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
                @endif

                {{ $slot }}
            </main>
        </div>
    </div>

    <x-app-bottom-nav />
    <x-quick-actions-sheet />
</body>
</html>
