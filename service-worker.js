const CACHE = 'socialquest-v110';
const ASSETS = ['./','./index.html','./feed.html','./post.html','./quests.html','./explore.html','./rankings.html','./messages.html','./profile.html','./admin.html','./styles.css','./page-routing.css','./app.js','./manifest.webmanifest','./icon.svg'];
self.addEventListener('install', event => event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(ASSETS))));
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
self.addEventListener('fetch', event => event.respondWith(fetch(event.request).catch(() => caches.match(event.request))));
