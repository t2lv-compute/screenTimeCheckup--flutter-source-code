import 'package:flutter/services.dart';
import 'platform_service_interface.dart';

class PlatformServiceImpl implements PlatformServiceInterface {
  static const _channel = MethodChannel('app.channel/platform');

  @override
  bool get canMinimize => true;

  @override
  Future<void> minimizeApp() async {
    await _channel.invokeMethod('minimize');
  }

  @override
  bool get canInstallPwa => false;

  @override
  bool get isIosSafari => false;

  @override
  Future<void> promptPwaInstall() async {}
}

PlatformServiceInterface createPlatformService() => PlatformServiceImpl();
