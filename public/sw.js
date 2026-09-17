// Service worker minimal pour Parallelium.
//
// Objectif V1 : permettre "Ajouter à l'écran d'accueil" et mettre en cache
// l'app shell (icônes, manifest) pour un démarrage plus rapide.
//
// IMPORTANT : Parallelium nécessite le serveur pour toute la logique
// métier (ventes, stock, paiements...). Ce service worker ne prétend PAS
// faire fonctionner l'application hors ligne — le mode offline complet
// est prévu pour une version future (voir cahier des charges §27).

const CACHE_NAME = 'parallelium-shell-v1';
const APP_SHELL = [
    '/manifest.json',
    '/icons/icon-192.png',
    '/icons/icon-512.png',
];

self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL))
    );
    self.skipWaiting();
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

// Stratégie "cache first" uniquement pour l'app shell statique.
// Toutes les autres requêtes (pages, données) passent toujours par le
// réseau : on ne simule jamais une réponse hors ligne pour une page qui
// a besoin du serveur.
self.addEventListener('fetch', (event) => {
    const url = new URL(event.request.url);

    if (APP_SHELL.includes(url.pathname)) {
        event.respondWith(
            caches.match(event.request).then((cached) => cached || fetch(event.request))
        );
    }
});
