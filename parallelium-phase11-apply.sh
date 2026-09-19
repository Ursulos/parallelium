#!/usr/bin/env bash
#
# Parallelium - Phase 11 (PWA avancee)
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
# Compatible Git Bash / WSL sous Windows.
set -e
echo "Application des fichiers Phase 11..."

mkdir -p "public"
cat > "public/manifest.json" << 'PARALLELIUM_FILE_EOF'
{
    "id": "/",
    "name": "Parallelium",
    "short_name": "Parallelium",
    "description": "Gérez vos ventes, votre stock, vos clients et vos dépenses depuis un seul endroit.",
    "start_url": "/dashboard",
    "scope": "/",
    "display": "standalone",
    "display_override": ["standalone", "minimal-ui"],
    "background_color": "#f8fafc",
    "theme_color": "#481f89",
    "orientation": "portrait-primary",
    "lang": "fr",
    "categories": ["business", "productivity", "finance"],
    "icons": [
        {
            "src": "/icons/icon-192.png",
            "sizes": "192x192",
            "type": "image/png",
            "purpose": "any"
        },
        {
            "src": "/icons/icon-512.png",
            "sizes": "512x512",
            "type": "image/png",
            "purpose": "any"
        },
        {
            "src": "/icons/icon-192.png",
            "sizes": "192x192",
            "type": "image/png",
            "purpose": "maskable"
        }
    ],
    "shortcuts": [
        {
            "name": "Nouvelle vente",
            "short_name": "Vente",
            "url": "/sales/create",
            "icons": [{ "src": "/icons/icon-192.png", "sizes": "192x192" }]
        },
        {
            "name": "Nouvelle dépense",
            "short_name": "Dépense",
            "url": "/expenses/create",
            "icons": [{ "src": "/icons/icon-192.png", "sizes": "192x192" }]
        },
        {
            "name": "Nouveau client",
            "short_name": "Client",
            "url": "/customers/create",
            "icons": [{ "src": "/icons/icon-192.png", "sizes": "192x192" }]
        }
    ]
}
PARALLELIUM_FILE_EOF

mkdir -p "public"
cat > "public/sw.js" << 'PARALLELIUM_FILE_EOF'
// Service worker pour Parallelium.
//
// Objectif : permettre "Ajouter à l'écran d'accueil", mettre en cache
// l'app shell (icônes, manifest, page hors ligne) pour un démarrage plus
// rapide, et afficher un message honnête en cas de coupure réseau.
//
// IMPORTANT : Parallelium nécessite le serveur pour toute la logique
// métier (ventes, stock, paiements...). Ce service worker ne prétend PAS
// faire fonctionner l'application hors ligne — le mode offline complet
// est prévu pour une version future (voir cahier des charges §27).

const CACHE_VERSION = 'v2';
const CACHE_NAME = `parallelium-shell-${CACHE_VERSION}`;
const APP_SHELL = [
    '/manifest.json',
    '/offline.html',
    '/icons/icon-192.png',
    '/icons/icon-512.png',
];

self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL))
    );
    // N'active pas immédiatement l'ancienne page ouverte : on laisse
    // l'utilisateur choisir via la bannière "nouvelle version" (voir
    // pwa-head.blade.php) plutôt que de remplacer le SW sous ses pieds.
});

self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((keys) =>
            Promise.all(
                keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
            )
        )
    );
    self.clients.claim();
});

self.addEventListener('message', (event) => {
    if (event.data === 'SKIP_WAITING') {
        self.skipWaiting();
    }
});

self.addEventListener('fetch', (event) => {
    const url = new URL(event.request.url);

    // App shell statique : cache d'abord, réseau en secours.
    if (APP_SHELL.includes(url.pathname)) {
        event.respondWith(
            caches.match(event.request).then((cached) => cached || fetch(event.request))
        );
        return;
    }

    // Pages (navigation) : toujours le réseau en premier — jamais de
    // contenu périmé pour des données métier. Seul le cas d'échec total
    // (pas de réseau) affiche la page hors-ligne, honnêtement, plutôt
    // qu'une erreur de navigateur brute.
    if (event.request.mode === 'navigate') {
        event.respondWith(
            fetch(event.request).catch(() => caches.match('/offline.html'))
        );
    }
});
PARALLELIUM_FILE_EOF

mkdir -p "public"
cat > "public/offline.html" << 'PARALLELIUM_FILE_EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Hors ligne — Parallelium</title>
    <style>
        :root { color-scheme: light; }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            background: linear-gradient(135deg, #1f1650 0%, #6a35c2 55%, #c22fb0 100%);
        }
        .card {
            width: 100%;
            max-width: 380px;
            background: #ffffff;
            border-radius: 24px;
            padding: 32px 24px;
            text-align: center;
            box-shadow: 0 20px 50px rgba(31, 22, 80, 0.35);
        }
        .logo {
            width: 48px;
            height: 48px;
            border-radius: 999px;
            margin: 0 auto 20px;
            display: flex;
            align-items: center;
            justify-content: center;
            background: linear-gradient(135deg, #1f1650 0%, #6a35c2 55%, #c22fb0 100%);
            color: #fff;
            font-weight: 800;
            font-size: 18px;
        }
        h1 { font-size: 18px; color: #0f172a; margin: 0 0 8px; }
        p { font-size: 14px; color: #64748b; line-height: 1.5; margin: 0 0 20px; }
        button {
            border: none;
            width: 100%;
            padding: 14px;
            border-radius: 12px;
            background: linear-gradient(135deg, #1f1650 0%, #6a35c2 55%, #c22fb0 100%);
            color: #fff;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
        }
        .hint { margin-top: 16px; font-size: 12px; color: #94a3b8; }
    </style>
</head>
<body>
    <div class="card">
        <div class="logo">P</div>
        <h1>Pas de connexion internet</h1>
        <p>
            Parallelium a besoin d'une connexion pour fonctionner : vos ventes, votre stock
            et vos données passent toujours par le serveur, pour rester fiables et à jour.
            Reconnectez-vous puis réessayez.
        </p>
        <button onclick="window.location.reload()">Réessayer</button>
        <p class="hint">Le mode hors ligne complet est prévu pour une prochaine version.</p>
    </div>
</body>
</html>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/components"
cat > "resources/views/components/pwa-head.blade.php" << 'PARALLELIUM_FILE_EOF'
<link rel="manifest" href="{{ asset('manifest.json') }}">
<link rel="apple-touch-icon" href="{{ asset('icons/apple-touch-icon.png') }}">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.6.0/css/all.min.css" integrity="sha512-Kc323vGBEqzTmouAECnVceyQqyqdsSiqLQISBL29aUW4U/M7pSPA/gEUZQqv1cwx4OnYxTxve5UMg5GT6L4JJg==" crossorigin="anonymous" referrerpolicy="no-referrer">
<meta name="theme-color" content="#481f89">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Parallelium">
<script>
    // Enregistrement du service worker + détection de mise à jour.
    // Quand une nouvelle version est prête, on prévient l'utilisateur
    // au lieu de remplacer le SW sous ses pieds (évite un rechargement
    // surprise en pleine saisie d'une vente).
    if ('serviceWorker' in navigator) {
        window.addEventListener('load', () => {
            navigator.serviceWorker.register('/sw.js').then((registration) => {
                registration.addEventListener('updatefound', () => {
                    const worker = registration.installing;
                    if (!worker) return;

                    worker.addEventListener('statechange', () => {
                        if (worker.state === 'installed' && navigator.serviceWorker.controller) {
                            window.dispatchEvent(new CustomEvent('parallelium-update-available', { detail: { registration } }));
                        }
                    });
                });
            }).catch(() => {});

            let refreshing = false;
            navigator.serviceWorker.addEventListener('controllerchange', () => {
                if (refreshing) return;
                refreshing = true;
                window.location.reload();
            });
        });
    }
</script>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/components"
cat > "resources/views/components/pwa-update-banner.blade.php" << 'PARALLELIUM_FILE_EOF'
<div
    x-data="{ show: false, registration: null }"
    x-on:parallelium-update-available.window="show = true; registration = $event.detail.registration"
    x-show="show"
    x-cloak
    x-transition
    class="fixed inset-x-0 bottom-20 z-40 mx-auto w-full max-w-sm px-4 lg:bottom-6">
    <div class="flex items-center gap-3 rounded-2xl bg-slate-900 px-4 py-3 text-white shadow-xl">
        <x-icon name="info" class="text-brand-300" />
        <p class="flex-1 text-sm">Nouvelle version disponible.</p>
        <button
            type="button"
            x-on:click="registration?.waiting?.postMessage('SKIP_WAITING'); show = false"
            class="shrink-0 rounded-lg bg-white/15 px-3 py-1.5 text-xs font-semibold hover:bg-white/25">
            Mettre à jour
        </button>
    </div>
</div>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/components"
cat > "resources/views/components/pwa-install-banner.blade.php" << 'PARALLELIUM_FILE_EOF'
<div
    x-data="pwaInstallBanner()"
    x-init="init()"
    x-show="visible"
    x-cloak
    x-transition
    class="fixed inset-x-0 bottom-20 z-40 mx-auto w-full max-w-sm px-4 lg:bottom-6">
    <div class="flex items-center gap-3 rounded-2xl border border-slate-100 bg-white px-4 py-3 shadow-xl">
        <span class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand-gradient text-sm text-white">
            <x-icon name="logo" />
        </span>
        <div class="min-w-0 flex-1">
            <p class="text-sm font-semibold text-slate-800">Installer Parallelium</p>
            <p class="text-xs text-slate-500" x-text="isIos ? 'Partager puis « Sur l’écran d’accueil »' : 'Accès rapide, comme une vraie application'"></p>
        </div>
        <button type="button" x-show="!isIos" x-on:click="install()" class="shrink-0 rounded-lg bg-brand-gradient px-3 py-1.5 text-xs font-semibold text-white">
            Installer
        </button>
        <button type="button" x-on:click="dismiss()" class="shrink-0 text-slate-300 hover:text-slate-500">
            <x-icon name="error" class="text-sm" />
        </button>
    </div>
</div>

<script>
    function pwaInstallBanner() {
        return {
            visible: false,
            isIos: false,
            deferredPrompt: null,

            init() {
                if (localStorage.getItem('parallelium-install-dismissed') === '1') return;

                // L'application est déjà installée (mode standalone) : rien à faire.
                if (window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone) return;

                this.isIos = /iphone|ipad|ipod/i.test(window.navigator.userAgent) && !window.MSStream;

                if (this.isIos) {
                    // Safari iOS ne déclenche jamais beforeinstallprompt : on
                    // affiche l'astuce manuelle directement.
                    this.visible = true;
                    return;
                }

                window.addEventListener('beforeinstallprompt', (event) => {
                    event.preventDefault();
                    this.deferredPrompt = event;
                    this.visible = true;
                });
            },

            async install() {
                if (!this.deferredPrompt) { this.visible = false; return; }
                this.deferredPrompt.prompt();
                await this.deferredPrompt.userChoice;
                this.deferredPrompt = null;
                this.visible = false;
            },

            dismiss() {
                this.visible = false;
                localStorage.setItem('parallelium-install-dismissed', '1');
            },
        };
    }
</script>
PARALLELIUM_FILE_EOF

mkdir -p "resources/views/components/layouts"
cat > "resources/views/components/layouts/app.blade.php" << 'PARALLELIUM_FILE_EOF'
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
    <x-pwa-install-banner />
    <x-pwa-update-banner />
</body>
</html>
PARALLELIUM_FILE_EOF

echo "Termine. Lance maintenant : php artisan view:clear"
echo "Astuce : vide le cache du service worker dans les DevTools (Application > Service Workers > Unregister) pour bien voir le changement."
