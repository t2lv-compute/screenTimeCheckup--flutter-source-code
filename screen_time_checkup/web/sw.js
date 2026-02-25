'use strict';

// Import Flutter's generated service worker for PWA asset caching.
// importScripts is re-evaluated on SW update checks, so any change to
// flutter_service_worker.js (new build) will trigger a SW update automatically.
try {
  importScripts('./flutter_service_worker.js');
} catch (e) {
  console.log('[SW] Flutter service worker not available (dev mode):', e.message);
}

// Receive showNotification requests from the main app thread.
// Using registration.showNotification (instead of new Notification()) is what
// enables the action buttons below.
self.addEventListener('message', (event) => {
  if (event.data?.type === 'showNotification') {
    const { title, body } = event.data;
    event.waitUntil(
      self.registration.showNotification(title, {
        body,
        icon: './icons/Icon-192.png',
        requireInteraction: true,
        actions: [
          { action: 'snooze5', title: 'Snooze 5 min' },
          { action: 'snooze15', title: 'Snooze 15 min' },
        ],
      })
    );
  }
});

// Handle notification clicks and action button taps.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const action = event.action;
  const snoozeMinutes =
    action === 'snooze5' ? 5 : action === 'snooze15' ? 15 : null;

  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clients) => {
        if (snoozeMinutes !== null) {
          // Snooze: tell the app to delay the next check-in.
          // Do NOT focus the window — this should work silently in the background.
          clients.forEach((c) => c.postMessage({ type: 'snooze', minutes: snoozeMinutes }));
        } else {
          // Normal notification tap: focus the app and trigger the tap callback.
          const target = clients.find((c) => c.visibilityState === 'visible') || clients[0];
          if (target) {
            target.focus().catch(() => {});
            target.postMessage({ type: 'tap' });
          } else {
            self.clients.openWindow(self.registration.scope).then((c) => {
              c?.postMessage({ type: 'tap' });
            });
          }
        }
      })
  );
});
