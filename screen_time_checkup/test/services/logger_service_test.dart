import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_checkup/services/logger_service.dart';

void main() {
  late LoggerService logger;

  setUp(() {
    logger = LoggerService();
    logger.reset(); // Clear any logs from previous tests
  });

  group('Log Levels', () {
    test('debug() creates log with debug level', () {
      logger.debug('Debug message', 'TestSource');

      expect(logger.logs.length, 1);
      expect(logger.logs[0].level, LogLevel.debug);
      expect(logger.logs[0].message, 'Debug message');
      expect(logger.logs[0].source, 'TestSource');
    });

    test('info() creates log with info level', () {
      logger.info('Info message', 'TestSource');

      expect(logger.logs.length, 1);
      expect(logger.logs[0].level, LogLevel.info);
      expect(logger.logs[0].message, 'Info message');
    });

    test('warning() creates log with warning level', () {
      logger.warning('Warning message');

      expect(logger.logs.length, 1);
      expect(logger.logs[0].level, LogLevel.warning);
      expect(logger.logs[0].message, 'Warning message');
    });

    test('error() creates log with error level and captures error details', () {
      final error = Exception('Test exception');
      final stackTrace = StackTrace.current;

      logger.error('Error message', error, stackTrace, 'ErrorSource');

      expect(logger.logs.length, 1);
      expect(logger.logs[0].level, LogLevel.error);
      expect(logger.logs[0].message, 'Error message');
      expect(logger.logs[0].error, error);
      expect(logger.logs[0].stackTrace, stackTrace);
      expect(logger.logs[0].source, 'ErrorSource');
    });

    test('source is optional', () {
      logger.info('Message without source');

      expect(logger.logs.length, 1);
      expect(logger.logs[0].source, isNull);
    });
  });

  group('Max Log Limit', () {
    test('logs are limited to 100 entries', () {
      // Reset to ensure clean state
      logger.reset();

      // Add 110 logs
      for (var i = 0; i < 110; i++) {
        logger.info('Message $i');
      }

      expect(logger.logs.length, 100);
      // First 10 logs should have been removed
      expect(logger.logs[0].message, 'Message 10');
      expect(logger.logs[99].message, 'Message 109');
    });

    test('oldest logs are removed when limit is exceeded', () {
      // Reset to ensure clean state
      logger.reset();

      // Fill to capacity
      for (var i = 0; i < 100; i++) {
        logger.info('Old message $i');
      }

      expect(logger.logs.length, 100);
      expect(logger.logs[0].message, 'Old message 0');

      // Add one more
      logger.info('New message');

      expect(logger.logs.length, 100);
      expect(logger.logs[0].message, 'Old message 1'); // First was removed
      expect(logger.logs[99].message, 'New message');
    });
  });

  group('clear() and reset()', () {
    test('clear() removes all logs', () {
      logger.info('Message 1');
      logger.info('Message 2');
      logger.info('Message 3');

      expect(logger.logs.length, 3);

      logger.clear();

      expect(logger.logs.length, 0);
    });

    test('reset() removes all logs (for testing)', () {
      logger.info('Message 1');
      logger.info('Message 2');

      logger.reset();

      expect(logger.logs.length, 0);
    });
  });

  group('export()', () {
    test('export() returns formatted log string', () {
      logger.info('First message', 'Source1');
      logger.warning('Second message', 'Source2');

      final exported = logger.export();

      expect(exported, contains('INFO'));
      expect(exported, contains('First message'));
      expect(exported, contains('Source1'));
      expect(exported, contains('WARNING'));
      expect(exported, contains('Second message'));
      expect(exported, contains('Source2'));
    });

    test('export() returns empty string when no logs', () {
      final exported = logger.export();

      expect(exported, '');
    });

    test('export() includes error details', () {
      final error = Exception('Test error');
      logger.error('Error occurred', error, null, 'ErrorSource');

      final exported = logger.export();

      expect(exported, contains('ERROR'));
      expect(exported, contains('Error occurred'));
      expect(exported, contains('Test error'));
    });
  });

  group('LogRecord', () {
    test('toString() formats record correctly', () {
      logger.info('Test message', 'TestSource');
      final record = logger.logs[0];

      final str = record.toString();

      expect(str, contains('[INFO]'));
      expect(str, contains('(TestSource)'));
      expect(str, contains('Test message'));
      expect(str, contains(record.timestamp.toIso8601String()));
    });

    test('toString() includes error when present', () {
      logger.error('Error', Exception('Test'), null, 'Source');
      final record = logger.logs[0];

      final str = record.toString();

      expect(str, contains('Error: Exception: Test'));
    });
  });

  group('Singleton', () {
    test('LoggerService is a singleton', () {
      final logger1 = LoggerService();
      final logger2 = LoggerService();

      expect(identical(logger1, logger2), true);
    });

    test('logs are shared across instances', () {
      final logger1 = LoggerService();
      logger1.reset();
      logger1.info('Message from logger1');

      final logger2 = LoggerService();

      expect(logger2.logs.length, 1);
      expect(logger2.logs[0].message, 'Message from logger1');
    });
  });
}
