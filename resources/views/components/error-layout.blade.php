<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $title ?? 'Erreur' }} — Parallelium</title>
    @if (file_exists(public_path('build/manifest.json')) || file_exists(public_path('hot')))
        @vite(['resources/css/app.css'])
    @else
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f8fafc; }
        </style>
    @endif
</head>
<body class="flex min-h-screen items-center justify-center bg-slate-50 px-4">
    <div class="w-full max-w-sm rounded-3xl bg-white p-8 text-center shadow-xl">
        <div class="mx-auto mb-5 flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-[#1f1650] via-[#6a35c2] to-[#c22fb0] text-xl font-extrabold text-white">
            {{ $code ?? '!' }}
        </div>
        <h1 class="text-lg font-bold text-slate-900">{{ $heading ?? 'Une erreur est survenue' }}</h1>
        <p class="mt-2 text-sm text-slate-500">{{ $message ?? "Quelque chose s'est mal passé." }}</p>
        <a href="{{ url('/dashboard') }}" class="mt-6 inline-flex items-center justify-center rounded-xl bg-gradient-to-br from-[#1f1650] via-[#6a35c2] to-[#c22fb0] px-4 py-2.5 text-sm font-semibold text-white">
            Retour à l'accueil
        </a>
    </div>
</body>
</html>
