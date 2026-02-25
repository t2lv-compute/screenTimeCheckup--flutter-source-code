import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'platform_service_interface.dart';

/// Minimal extension type to call .prompt() on BeforeInstallPromptEvent.
extension type _InstallPromptEvent(JSObject _) implements JSObject {
  external JSPromise prompt();
}

class PlatformServiceImpl implements PlatformServiceInterface {
  static _InstallPromptEvent? _deferredPrompt;
  static bool _listenerAdded = false;

  PlatformServiceImpl() {
    _setupListeners();
  }

  static void _setupListeners() {
    if (_listenerAdded) return;
    _listenerAdded = true;

    web.window.addEventListener(
      'beforeinstallprompt',
      ((web.Event event) {
        event.preventDefault();
        _deferredPrompt = _InstallPromptEvent(event as JSObject);
      }).toJS,
    );

    web.window.addEventListener(
      'appinstalled',
      ((web.Event event) {
        _deferredPrompt = null;
      }).toJS,
    );
  }

  @override
  bool get canMinimize => false;

  @override
  Future<void> minimizeApp() async {}

  bool get _isIos {
    final ua = web.window.navigator.userAgent;
    return ua.contains('iPhone') || ua.contains('iPad') || ua.contains('iPod');
  }

  bool get _isStandalone =>
      web.window.matchMedia('(display-mode: standalone)').matches;

  @override
  bool get isIosSafari => _isIos && !_isStandalone;

  @override
  bool get canInstallPwa {
    if (_isStandalone) return false; // already installed
    return _deferredPrompt != null || _isIos;
  }

  @override
  Future<void> promptPwaInstall() async {
    if (_deferredPrompt == null) return;
    final prompt = _deferredPrompt!;
    _deferredPrompt = null; // prompt() can only be called once
    prompt.prompt();
  }
}

PlatformServiceInterface createPlatformService() => PlatformServiceImpl();
