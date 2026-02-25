abstract class PlatformServiceInterface {
  bool get canMinimize;
  Future<void> minimizeApp();
  /// True when an install action is available (native prompt or iOS manual flow).
  bool get canInstallPwa;
  /// True when running in iOS Safari (requires manual "Add to Home Screen" steps).
  bool get isIosSafari;
  /// Triggers the deferred PWA install prompt (no-op on iOS — show instructions instead).
  Future<void> promptPwaInstall();
}
