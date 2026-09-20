<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>{{ $title ?? 'Administration' }} — Parallelium</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.6.0/css/all.min.css" integrity="sha512-Kc323vGBEqzTmouAECnVceyQqyqdsSiqLQISBL29aUW4U/M7pSPA/gEUZQqv1cwx4OnYxTxve5UMg5GT6L4JJg==" crossorigin="anonymous" referrerpolicy="no-referrer">
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="min-h-screen bg-slate-50">
    <header class="border-b border-slate-100 bg-slate-950">
        <div class="mx-auto flex max-w-6xl items-center justify-between px-4 py-3 lg:px-8">
            <div class="flex items-center gap-6">
                <div class="flex items-center gap-2 text-sm font-extrabold text-white">
                    <span class="flex h-8 w-8 items-center justify-center rounded-full bg-brand-gradient text-sm"><x-icon name="logo" /></span>
                    Parallelium
                    <span class="ml-1 rounded-full bg-white/10 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-slate-300">Administration</span>
                </div>

                @auth('admin')
                    <nav class="hidden items-center gap-4 text-xs font-medium text-slate-300 sm:flex">
                        <a href="{{ route('admin.dashboard') }}" class="hover:text-white {{ request()->routeIs('admin.dashboard') ? 'text-white' : '' }}">Dashboard</a>
                        <a href="{{ route('admin.companies.index') }}" class="hover:text-white {{ request()->routeIs('admin.companies.*') ? 'text-white' : '' }}">Entreprises</a>
                        <a href="{{ route('admin.admins.index') }}" class="hover:text-white {{ request()->routeIs('admin.admins.*') ? 'text-white' : '' }}">Administrateurs</a>
                    </nav>
                @endauth
            </div>

            @auth('admin')
                <form method="POST" action="{{ route('admin.logout') }}">
                    @csrf
                    <button type="submit" class="text-xs font-medium text-slate-300 hover:text-white">Se déconnecter</button>
                </form>
            @endauth
        </div>
    </header>

    <main class="mx-auto max-w-6xl px-4 py-6 lg:px-8">
        @if (session('status'))
            <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
        @endif
        @if ($errors->any())
            <x-alert type="error" class="mb-4">{{ $errors->first() }}</x-alert>
        @endif

        {{ $slot }}
    </main>
</body>
</html>
