import 'platform_service_interface.dart';
import 'platform_service_web.dart'
    if (dart.library.io) 'platform_service_mobile.dart';

class PlatformService implements PlatformServiceInterface {
  final PlatformServiceInterface _impl = createPlatformService();

  @override
  bool get canMinimize => _impl.canMinimize;

  @override
  Future<void> minimizeApp() => _impl.minimizeApp();

  @override
  bool get canInstallPwa => _impl.canInstallPwa;

  @override
  bool get isIosSafari => _impl.isIosSafari;

  @override
  Future<void> promptPwaInstall() => _impl.promptPwaInstall();
}
