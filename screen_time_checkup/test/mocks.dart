import 'package:mocktail/mocktail.dart';
import 'package:screen_time_checkup/models/app_settings.dart';
import 'package:screen_time_checkup/models/log_entry.dart';
import 'package:screen_time_checkup/services/storage_service_interface.dart';
import 'package:screen_time_checkup/services/notification_service_interface.dart';

class MockStorageService extends Mock implements StorageServiceInterface {}

class MockNotificationService extends Mock implements NotificationServiceInterface {}

class FakeAppSettings extends Fake implements AppSettings {}

class FakeLogEntry extends Fake implements LogEntry {}

void registerFallbackValues() {
  registerFallbackValue(FakeAppSettings());
  registerFallbackValue(FakeLogEntry());
  registerFallbackValue(<LogEntry>[]);
  registerFallbackValue(DateTime(2024));
  registerFallbackValue(<String>[]);
  registerFallbackValue(Duration.zero);
}
