// ============================================================
// Service Worker — App Mundial 2026
// Maneja Web Push Notifications
// ============================================================

const CACHE_NAME = 'mundial-2026-v1';

// Instalar SW
self.addEventListener('install', event => {
  self.skipWaiting();
});

// Activar SW
self.addEventListener('activate', event => {
  event.waitUntil(clients.claim());
});

// Recibir notificación push
self.addEventListener('push', event => {
  let data = {
    title: '⚽ App Mundial 2026',
    body: '¡Partido próximo!',
    icon: '/icon-192.png',
    badge: '/badge-72.png',
    tag: 'mundial-match',
    data: { url: '/' }
  };

  if (event.data) {
    try {
      const payload = event.data.json();
      data = { ...data, ...payload };
    } catch (e) {
      data.body = event.data.text();
    }
  }

  const options = {
    body: data.body,
    icon: data.icon || '/icon-192.png',
    badge: data.badge || '/badge-72.png',
    tag: data.tag || 'mundial-match',
    renotify: true,
    requireInteraction: false,
    vibrate: [200, 100, 200],
    data: data.data || { url: '/' },
    actions: [
      { action: 'open', title: '🏟️ Ver partido' },
      { action: 'close', title: 'Cerrar' }
    ]
  };

  event.waitUntil(
    self.registration.showNotification(data.title, options)
  );
});

// Click en notificación
self.addEventListener('notificationclick', event => {
  event.notification.close();

  if (event.action === 'close') return;

  const url = event.notification.data?.url || '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(windowClients => {
      // Si ya hay una pestaña abierta, enfocarla
      for (const client of windowClients) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      // Sino abrir nueva pestaña
      if (clients.openWindow) {
        return clients.openWindow(url);
      }
    })
  );
});
