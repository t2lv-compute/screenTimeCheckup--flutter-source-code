import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  final List<LogRecord> _logs = [];
  static const int _maxLogs = 100;

  List<LogRecord> get logs => List.unmodifiable(_logs);

  void debug(String message, [String? source]) {
    _log(LogLevel.debug, message, source);
  }

  void info(String message, [String? source]) {
    _log(LogLevel.info, message, source);
  }

  void warning(String message, [String? source]) {
    _log(LogLevel.warning, message, source);
  }

  void error(String message, [Object? error, StackTrace? stackTrace, String? source]) {
    _log(LogLevel.error, message, source, error, stackTrace);
  }

  void _log(LogLevel level, String message, [String? source, Object? error, StackTrace? stackTrace]) {
    final record = LogRecord(
      level: level,
      message: message,
      source: source,
      error: error,
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
    );

    _logs.add(record);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }

    if (kDebugMode) {
      final prefix = '[${level.name.toUpperCase()}]${source != null ? ' ($source)' : ''}';
      debugPrint('$prefix $message');
      if (error != null) {
        debugPrint('  Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('  $stackTrace');
      }
    }
  }

  void clear() {
    _logs.clear();
  }

  @visibleForTesting
  void reset() => _logs.clear();

  String export() {
    final buffer = StringBuffer();
    for (final log in _logs) {
      buffer.writeln(log.toString());
    }
    return buffer.toString();
  }
}

class LogRecord {
  final LogLevel level;
  final String message;
  final String? source;
  final Object? error;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  LogRecord({
    required this.level,
    required this.message,
    this.source,
    this.error,
    this.stackTrace,
    required this.timestamp,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[${timestamp.toIso8601String()}] ');
    buffer.write('[${level.name.toUpperCase()}] ');
    if (source != null) buffer.write('($source) ');
    buffer.write(message);
    if (error != null) buffer.write(' | Error: $error');
    return buffer.toString();
  }
}
