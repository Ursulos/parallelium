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
