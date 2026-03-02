// Redirect Flutter's automatic service worker registration to sw.js.
// sw.js wraps flutter_service_worker.js (via importScripts) and adds
// notification action button support (snooze without opening the app).
if ('serviceWorker' in navigator) {
  const _orig = navigator.serviceWorker.register.bind(navigator.serviceWorker);
  navigator.serviceWorker.register = (url, options) => {
    if (typeof url === 'string' && url.includes('flutter_service_worker')) {
      return _orig('sw.js', options);
    }
    return _orig(url, options);
  };
}
