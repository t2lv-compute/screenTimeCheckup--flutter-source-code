import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../models/log_entry.dart';
import '../models/notification_message.dart';
import '../models/quick_preset.dart';
import '../services/storage_service.dart';
import '../services/storage_service_interface.dart';
import '../services/notification_service.dart';
import '../services/notification_service_interface.dart';
import '../services/logger_service.dart';

class AppState extends ChangeNotifier {
  final StorageServiceInterface _storage;
  final NotificationServiceInterface _notifications;
  final LoggerService _logger;

  AppState({
    StorageServiceInterface? storage,
    NotificationServiceInterface? notifications,
    LoggerService? logger,
  })  : _storage = storage ?? StorageService(),
        _notifications = notifications ?? NotificationService(),
        _logger = logger ?? LoggerService();

  AppSettings _settings = AppSettings();
  List<LogEntry> _logs = [];
  bool _isLoading = true;
  bool _openedFromNotification = false;
  DateTime? _notificationTapTime;
  String? _errorMessage;
  DateTime? _scheduledAt;
  DateTime? _snoozedUntil;
  Timer? _snoozeCountdownTimer;
  final _random = Random();
  String? _lastShownMessageId;

  // Pagination
  static const int _logsPerPage = 20;
  int _displayedLogsCount = _logsPerPage;

  // Cached statistics
  int? _cachedOnTrackCount;
  double? _cachedOnTrackPercentage;
  Map<String, int>? _cachedTagUsageStats;
  Map<String, int>? _cachedTagGoalCount;
  Map<String, int>? _cachedTagOnTrackCount;
  List<LogEntry>? _cachedRecentLogs;
  List<LogEntry>? _cachedSortedLogs;
  int? _cachedNotificationResponseCount;
  int? _cachedQuickResponseCount;
  int? _cachedCurrentStreak;
  int? _cachedLongestStreak;
  int? _cachedMissedCheckInCount;

  AppSettings get settings => _settings;
  List<LogEntry> get logs => _logs;
  bool get isLoading => _isLoading;
  bool get openedFromNotification => _openedFromNotification;
  String? get errorMessage => _errorMessage;
  DateTime? get scheduledAt => _scheduledAt;

  /// The next time a fixed-schedule notification will fire, or null if none active.
  DateTime? get nextScheduledTime {
    if (!_settings.scheduledEnabled || _settings.scheduledTimes.isEmpty) return null;
    final now = DateTime.now();
    DateTime? nearest;
    for (final timeStr in _settings.scheduledTimes) {
      final parts = timeStr.split(':');
      if (parts.length != 2) continue;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) continue;
      var candidate = DateTime(now.year, now.month, now.day, h, m);
      if (!candidate.isAfter(now)) candidate = candidate.add(const Duration(days: 1));
      if (nearest == null || candidate.isBefore(nearest)) nearest = candidate;
    }
    return nearest;
  }

  /// Duration of the current notification window, used for the progress ring.
  /// Interval mode → the interval itself. Scheduled mode → gap between
  /// the previous and next fixed-schedule times.
  Duration get notificationWindowDuration {
    final now = DateTime.now();

    DateTime? intervalNext;
    if (_settings.intervalEnabled && _scheduledAt != null) {
      final interval = Duration(minutes: _settings.checkInIntervalMinutes);
      final elapsed = now.difference(_scheduledAt!);
      final periodsElapsed = elapsed.inMilliseconds ~/ interval.inMilliseconds;
      intervalNext = _scheduledAt!.add(interval * (periodsElapsed + 1));
    }

    final scheduledNext = nextScheduledTime;

    // Interval fires next (or is the only active type) — use interval duration.
    if (intervalNext != null &&
        (scheduledNext == null || intervalNext.isBefore(scheduledNext))) {
      return Duration(minutes: _settings.checkInIntervalMinutes);
    }

    // Scheduled fires next — window = most recent past scheduled time → next.
    if (scheduledNext != null) {
      DateTime? prevScheduled;
      for (final timeStr in _settings.scheduledTimes) {
        final parts = timeStr.split(':');
        if (parts.length != 2) continue;
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h == null || m == null) continue;
        var candidate = DateTime(now.year, now.month, now.day, h, m);
        if (candidate.isAfter(now)) {
          candidate = candidate.subtract(const Duration(days: 1));
        }
        if (prevScheduled == null || candidate.isAfter(prevScheduled)) {
          prevScheduled = candidate;
        }
      }
      if (prevScheduled != null) return scheduledNext.difference(prevScheduled);
      return scheduledNext.difference(now);
    }

    return Duration(minutes: _settings.checkInIntervalMinutes);
  }

  /// Returns the sooner of the next interval and next scheduled notification time.
  DateTime? get nextNotificationTime {
    // While snoozed, show when the snooze expires.
    if (_snoozedUntil != null) {
      return _snoozedUntil!.isAfter(DateTime.now()) ? _snoozedUntil : null;
    }

    DateTime? intervalNext;
    if (_settings.intervalEnabled && _scheduledAt != null) {
      final interval = Duration(minutes: _settings.checkInIntervalMinutes);
      final elapsed = DateTime.now().difference(_scheduledAt!);
      final periodsElapsed = elapsed.inMilliseconds ~/ interval.inMilliseconds;
      intervalNext = _scheduledAt!.add(interval * (periodsElapsed + 1));
    }

    final scheduledNext = nextScheduledTime;

    if (intervalNext == null && scheduledNext == null) return null;
    if (intervalNext == null) return scheduledNext;
    if (scheduledNext == null) return intervalNext;
    return intervalNext.isBefore(scheduledNext) ? intervalNext : scheduledNext;
  }

  // Paginated logs (sorted by timestamp, newest first)
  List<LogEntry> get sortedLogs {
    _cachedSortedLogs ??= List<LogEntry>.from(_logs)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return _cachedSortedLogs!;
  }

  List<LogEntry> get displayedLogs {
    final sorted = sortedLogs;
    if (_displayedLogsCount >= sorted.length) {
      return sorted;
    }
    return sorted.take(_displayedLogsCount).toList();
  }

  bool get hasMoreLogs => _displayedLogsCount < _logs.length;

  void loadMoreLogs() {
    _displayedLogsCount += _logsPerPage;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Statistics getters with memoization
  int get totalLogs => _logs.length;

  int get onTrackCount {
    _cachedOnTrackCount ??= _logs.where((log) => log.isOnTrack).length;
    return _cachedOnTrackCount!;
  }

  double get onTrackPercentage {
    _cachedOnTrackPercentage ??=
        totalLogs == 0 ? 0 : (onTrackCount / totalLogs) * 100;
    return _cachedOnTrackPercentage!;
  }

  Map<String, int> get tagUsageStats {
    if (_cachedTagUsageStats == null) {
      final stats = <String, int>{};
      for (final log in _logs.where((l) => !l.isMissed)) {
        stats[log.doingTag] = (stats[log.doingTag] ?? 0) + 1;
      }
      _cachedTagUsageStats = stats;
    }
    return _cachedTagUsageStats!;
  }

  /// How many times each tag was set as the goal (shouldDoTag).
  Map<String, int> get tagGoalCount {
    if (_cachedTagGoalCount == null) {
      final stats = <String, int>{};
      for (final log in _logs.where((l) => !l.isMissed)) {
        stats[log.shouldDoTag] = (stats[log.shouldDoTag] ?? 0) + 1;
      }
      _cachedTagGoalCount = stats;
    }
    return _cachedTagGoalCount!;
  }

  /// How many times the user was on-track for each shouldDoTag goal.
  Map<String, int> get tagOnTrackCount {
    if (_cachedTagOnTrackCount == null) {
      final stats = <String, int>{};
      for (final log in _logs) {
        if (log.isOnTrack) {
          stats[log.shouldDoTag] = (stats[log.shouldDoTag] ?? 0) + 1;
        }
      }
      _cachedTagOnTrackCount = stats;
    }
    return _cachedTagOnTrackCount!;
  }

  List<LogEntry> get recentLogs {
    if (_cachedRecentLogs == null) {
      final sorted = List<LogEntry>.from(_logs)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _cachedRecentLogs = sorted.take(10).toList();
    }
    return _cachedRecentLogs!;
  }

  /// Count of today's check-ins.
  int get todayLogCount {
    final now = DateTime.now();
    return _logs.where((log) =>
      log.timestamp.year == now.year &&
      log.timestamp.month == now.month &&
      log.timestamp.day == now.day
    ).length;
  }

  /// On-track percentage for today only.
  double get todayOnTrackPercentage {
    final now = DateTime.now();
    final today = _logs.where((log) =>
      log.timestamp.year == now.year &&
      log.timestamp.month == now.month &&
      log.timestamp.day == now.day
    ).toList();
    if (today.isEmpty) return 0;
    return (today.where((log) => log.isOnTrack).length / today.length) * 100;
  }

  /// Most recent check-in entry, or null if no logs exist.
  LogEntry? get lastCheckIn => sortedLogs.isEmpty ? null : sortedLogs.first;

  /// The distraction tag most commonly logged as `doingTag`, or null if none.
  String? get mostCommonDistractionTag {
    final distractionSet =
        _settings.distractionTags.map((t) => t.toLowerCase()).toSet();
    final counts = <String, int>{};
    for (final log in _logs.where((l) => !l.isMissed)) {
      if (distractionSet.contains(log.doingTag.toLowerCase())) {
        counts[log.doingTag] = (counts[log.doingTag] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Hour of day (0–23) with the highest all-time on-trackness, or null.
  int? get mostProductiveHour => _peakTroughHours().$1;

  /// Hour of day (0–23) with the lowest all-time on-trackness, or null.
  int? get leastProductiveHour => _peakTroughHours().$2;

  (int?, int?) _peakTroughHours() {
    final entries = _logs.where((l) => !l.isMissed).toList();
    final data = _onTracknessFromLogs(entries, (l) => l.timestamp.hour);
    if (data.isEmpty) return (null, null);
    final peak = data.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final trough =
        data.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
    return (peak, trough);
  }

  /// Groups [entries] by [keyOf] and computes fraction that isOnTrack per group.
  Map<int, double> _onTracknessFromLogs(
      List<LogEntry> entries, int Function(LogEntry) keyOf) {
    final totals = <int, int>{};
    final onTrack = <int, int>{};
    for (final e in entries) {
      final k = keyOf(e);
      totals[k] = (totals[k] ?? 0) + 1;
      if (e.isOnTrack) onTrack[k] = (onTrack[k] ?? 0) + 1;
    }
    return {
      for (final k in totals.keys) k: (onTrack[k] ?? 0) / totals[k]!
    };
  }

  /// Hourly on-trackness (key = 0–23) for one calendar day.
  Map<int, double> hourlyOnTracknessForDay(DateTime day) {
    final entries = _logs
        .where((l) =>
            !l.isMissed &&
            l.timestamp.year == day.year &&
            l.timestamp.month == day.month &&
            l.timestamp.day == day.day)
        .toList();
    return _onTracknessFromLogs(entries, (l) => l.timestamp.hour);
  }

  /// Daily on-trackness (key = 0 Mon … 6 Sun) for the ISO week containing [weekDay].
  Map<int, double> dailyOnTracknessForWeek(DateTime weekDay) {
    final monday = weekDay.subtract(Duration(days: weekDay.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final entries = _logs
        .where((l) =>
            !l.isMissed &&
            !l.timestamp.isBefore(
                DateTime(monday.year, monday.month, monday.day)) &&
            !l.timestamp.isAfter(DateTime(
                sunday.year, sunday.month, sunday.day, 23, 59, 59)))
        .toList();
    return _onTracknessFromLogs(entries, (l) => l.timestamp.weekday - 1);
  }

  /// Per-day on-trackness (key = day-of-month 1–31) for a year/month.
  Map<int, double> dailyOnTracknessForMonth(int year, int month) {
    final entries = _logs
        .where((l) =>
            !l.isMissed &&
            l.timestamp.year == year &&
            l.timestamp.month == month)
        .toList();
    return _onTracknessFromLogs(entries, (l) => l.timestamp.day);
  }

  /// Number of entries triggered by notifications.
  int get notificationResponseCount {
    _cachedNotificationResponseCount ??=
        _logs.where((log) => log.isFromNotification).length;
    return _cachedNotificationResponseCount!;
  }

  /// Number of entries where user responded within 3 minutes.
  int get quickResponseCount {
    _cachedQuickResponseCount ??=
        _logs.where((log) => log.isQuickResponse).length;
    return _cachedQuickResponseCount!;
  }

  /// Percentage of notification responses that were within 3 minutes.
  /// Returns 0 if no notification responses recorded.
  double get quickResponsePercentage {
    if (notificationResponseCount == 0) return 0;
    return (quickResponseCount / notificationResponseCount) * 100;
  }

  void _invalidateStatsCache() {
    _cachedOnTrackCount = null;
    _cachedOnTrackPercentage = null;
    _cachedTagUsageStats = null;
    _cachedTagGoalCount = null;
    _cachedTagOnTrackCount = null;
    _cachedRecentLogs = null;
    _cachedSortedLogs = null;
    _cachedNotificationResponseCount = null;
    _cachedQuickResponseCount = null;
    _cachedCurrentStreak = null;
    _cachedLongestStreak = null;
    _cachedMissedCheckInCount = null;
  }

  int get missedCheckInCount {
    _cachedMissedCheckInCount ??= _logs.where((l) => l.isMissed).length;
    return _cachedMissedCheckInCount!;
  }

  /// Consecutive days ending today (or yesterday if today has no check-ins yet)
  /// where each day has at least one on-track check-in.
  int get currentStreak {
    _cachedCurrentStreak ??= _computeCurrentStreak();
    return _cachedCurrentStreak!;
  }

  int _computeCurrentStreak() {
    if (_logs.isEmpty) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final onTrackDays = <DateTime>{};
    for (final log in _logs) {
      if (log.isOnTrack) {
        onTrackDays.add(DateTime(
          log.timestamp.year, log.timestamp.month, log.timestamp.day));
      }
    }
    if (onTrackDays.isEmpty) return 0;

    var checkDay = today;
    // If today has no on-track logs but has other logs, streak is broken.
    // If today has no logs at all, start counting from yesterday.
    if (!onTrackDays.contains(today)) {
      final hasAnyToday = _logs.any((log) {
        final d = DateTime(log.timestamp.year, log.timestamp.month, log.timestamp.day);
        return d == today;
      });
      if (hasAnyToday) return 0;
      checkDay = today.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (onTrackDays.contains(checkDay)) {
      streak++;
      checkDay = checkDay.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// The longest streak of consecutive on-track days ever achieved.
  int get longestStreak {
    _cachedLongestStreak ??= _computeLongestStreak();
    return _cachedLongestStreak!;
  }

  int _computeLongestStreak() {
    if (_logs.isEmpty) return 0;
    final onTrackDays = <DateTime>{};
    for (final log in _logs) {
      if (log.isOnTrack) {
        onTrackDays.add(DateTime(
          log.timestamp.year, log.timestamp.month, log.timestamp.day));
      }
    }
    if (onTrackDays.isEmpty) return 0;

    final sorted = onTrackDays.toList()..sort();
    int longest = 1;
    int current = 1;
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i].difference(sorted[i - 1]).inDays == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  /// Weighted-random selection of a notification message.
  /// Side effect: sets [_lastShownMessageId] so the weight can be updated
  /// when the user responds.
  (String, String) _pickNotificationMessage() {
    final messages = NotificationMessage.all;
    final weights = messages
        .map((m) => (_settings.notificationWeights[m.id] ?? 1.0).clamp(0.2, 5.0))
        .toList();
    final total = weights.fold(0.0, (a, b) => a + b);
    var pick = _random.nextDouble() * total;
    for (int i = 0; i < messages.length; i++) {
      pick -= weights[i];
      if (pick <= 0) {
        _lastShownMessageId = messages[i].id;
        return (messages[i].title, messages[i].body);
      }
    }
    _lastShownMessageId = messages.last.id;
    return (messages.last.title, messages.last.body);
  }

  void _updateNotificationWeight(String messageId, int responseTimeSeconds) {
    final current = _settings.notificationWeights[messageId] ?? 1.0;
    final factor = responseTimeSeconds <= 60
        ? 1.15
        : responseTimeSeconds <= 180
            ? 1.05
            : 0.9;
    final updated = Map<String, double>.from(_settings.notificationWeights)
      ..[messageId] = (current * factor).clamp(0.2, 5.0);
    _settings = _settings.copyWith(notificationWeights: updated);
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    _logger.debug('Initializing notifications...', 'AppState');
    await _notifications.initialize();
    _notifications.setOnNotificationTap(_onNotificationTapped);
    _notifications.setMessagePicker(_pickNotificationMessage);

    _logger.debug('Loading settings...', 'AppState');
    _settings = await _storage.loadSettings();

    // Seed default presets on first run (before user has created any).
    if (_settings.quickPresets.isEmpty) {
      _settings = _settings.copyWith(quickPresets: AppSettings.defaultPresets);
      await _storage.saveSettings(_settings);
    }

    _logger.debug('Loading logs...', 'AppState');
    _logs = await _storage.loadLogs();
    _invalidateStatsCache();

    // Restore notification tap time if page was reloaded after notification tap
    _logger.debug('Checking for saved notification tap time...', 'AppState');
    final savedTapTime = await _storage.loadNotificationTapTime();
    if (savedTapTime != null) {
      _notificationTapTime = savedTapTime;
      _openedFromNotification = true;
    }

    // Schedule notifications if permission already granted (don't prompt on startup)
    _logger.debug('Scheduling notifications if permission already granted...', 'AppState');
    try {
      if (_settings.intervalEnabled) {
        await _notifications.scheduleCheckIn(_settings.checkInIntervalMinutes);
        _scheduledAt = DateTime.now();
      }

      // Also schedule any saved time-based reminders
      if (_settings.scheduledEnabled && _settings.scheduledTimes.isNotEmpty) {
        _logger.debug('Scheduling ${_settings.scheduledTimes.length} time-based reminders...', 'AppState');
        await _notifications.scheduleAtTimes(_settings.scheduledTimes);
      }
    } catch (e) {
      _logger.debug('Could not schedule notifications: $e', 'AppState');
    }

    _logger.debug('Load complete!', 'AppState');
    _isLoading = false;
    notifyListeners();
  }

  void _onNotificationTapped() {
    _openedFromNotification = true;
    _notificationTapTime = DateTime.now();
    // Persist tap time in case page reloads
    _storage.saveNotificationTapTime(_notificationTapTime!);
    // Decrement counter: this notification was acknowledged
    if (_settings.remainingCheckIns > 0) {
      _settings = _settings.copyWith(
        remainingCheckIns: _settings.remainingCheckIns - 1,
      );
      _storage.saveSettings(_settings); // fire-and-forget
    }
    notifyListeners();
  }

  /// Called when an interval notification fires (detected by the home page timer).
  /// Increments the remaining check-ins counter and persists it.
  Future<void> onNotificationFired() async {
    _settings = _settings.copyWith(
      remainingCheckIns: _settings.remainingCheckIns + 1,
    );
    try {
      await _storage.saveSettings(_settings);
    } on StorageException catch (e) {
      _logger.error('Failed to save remainingCheckIns after notification fire', e, null, 'AppState');
    }
    notifyListeners();
  }

  Future<void> updateFocusTags(List<String> tags) async {
    _settings = _settings.copyWith(focusTags: tags);
    try {
      await _storage.saveSettings(_settings);
    } on StorageException catch (e) {
      _errorMessage = e.message;
      _logger.error('Failed to update focus tags', e, null, 'AppState');
    }
    notifyListeners();
  }

  Future<void> updateDistractionTags(List<String> tags) async {
    _settings = _settings.copyWith(distractionTags: tags);
    try {
      await _storage.saveSettings(_settings);
    } on StorageException catch (e) {
      _errorMessage = e.message;
      _logger.error('Failed to update distraction tags', e, null, 'AppState');
    }
    notifyListeners();
  }

  Future<void> markTutorialSeen() async {
    _settings = _settings.copyWith(hasSeenTutorial: true);
    try {
      await _storage.saveSettings(_settings);
    } on StorageException catch (e) {
      _errorMessage = e.message;
      _logger.error('Failed to mark tutorial seen', e, null, 'AppState');
    }
    notifyListeners();
  }

  Future<void> updateInterval(int minutes) async {
    // Cap at 12 hours (720 minutes)
    final clampedMinutes = minutes.clamp(1, 720);
    _settings = _settings.copyWith(checkInIntervalMinutes: clampedMinutes);
    try {
      await _storage.saveSettings(_settings);
    } on StorageException catch (e) {
      _errorMessage = e.message;
      _logger.error('Failed to update interval', e, null, 'AppState');
    }

    if (_settings.intervalEnabled) {
      final hasPermission = await _notifications.requestPermissions();
      if (hasPermission) {
        await _notifications.scheduleCheckIn(clampedMinutes);
        _scheduledAt = DateTime.now();
      }
    }

    notifyListeners();
  }

  Future<void> updateSessionIntention(String intention) async {
    _settings = _settings.copyWith(sessionIntention: intention);
    try {
      await _storage.saveSettings(_settings);
    } on StorageException catch (e) {
      _errorMessage = e.message;
      _logger.error('Failed to update session intention', e, null, 'AppState');
    }
    notifyListeners();
  }

  Future<void> clearSessionIntention() async {
    await updateSessionIntention('');
  }

  Future<void> addLogEntry(String doing, String shouldDo, {int? importance, int? intentionAdherence, String? notes}) async {
    // Calculate response time if opened from notification
    int? responseTimeSeconds;
    if (_notificationTapTime != null) {
      responseTimeSeconds =
          DateTime.now().difference(_notificationTapTime!).inSeconds;
      _notificationTapTime = null;
      // Clear persisted tap time
      _storage.clearNotificationTapTime();

      // Update notification message weight based on how quickly the user responded.
      if (_lastShownMessageId != null) {
        _updateNotificationWeight(_lastShownMessageId!, responseTimeSeconds);
        _lastShownMessageId = null;
      }
    }

    final entry = LogEntry(
      timestamp: DateTime.now(),
      doingTag: doing,
      shouldDoTag: shouldDo,
      importance: importance,
      responseTimeSeconds: responseTimeSeconds,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      intentionAdherence: intentionAdherence,
    );

    // Insert missed check-ins for any notifications that fired without a response.
    // The counter was incremented by onNotificationFired() and decremented by
    // _onNotificationTapped(), so its current value = number of missed notifications.
    if (_settings.intervalEnabled && _settings.remainingCheckIns > 0) {
      final interval = Duration(minutes: _settings.checkInIntervalMinutes);
      final count = _settings.remainingCheckIns;
      _settings = _settings.copyWith(remainingCheckIns: 0);
      // Approximate timestamps: count back from now by interval for each missed fire
      for (int i = count; i >= 1; i--) {
        final missedEntry = LogEntry.missed(
          timestamp: DateTime.now().subtract(interval * i),
        );
        _logs.add(missedEntry);
        try {
          await _storage.addLog(missedEntry);
        } on StorageException catch (e) {
          _logger.error('Failed to save missed entry', e, null, 'AppState');
        }
      }
    }

    _logs.add(entry);
    _invalidateStatsCache();
    try {
      await _storage.addLog(entry);
    } on StorageException catch (e) {
      _errorMessage = e.message;
      _logger.error('Failed to add log entry', e, null, 'AppState');
    }

    // Reset the interval timer so the countdown starts fresh from now.
    if (_settings.intervalEnabled) {
      _scheduledAt = DateTime.now();
      try {
        await _notifications.scheduleCheckIn(_settings.checkInIntervalMinutes);
      } catch (e) {
        _logger.debug('Could not reschedule notification after check-in: $e', 'AppState');
      }
      // Save settings (persists any remainingCheckIns reset from above)
      try {
        await _storage.saveSettings(_settings);
      } on StorageException catch (e) {
        _logger.error('Failed to save settings after check-in', e, null, 'AppState');
      }
    }

    _updateDynamicPresets();
    notifyListeners();
  }

  /// Recomputes quick presets from log frequency after every check-in.
  /// The top N most-used (doing, shouldDo) pairs replace the current preset list.
  void _updateDynamicPresets() {
    const maxPresets = 5;

    // Count how often each (doing, shouldDo) pair has been logged.
    final counts = <(String, String), int>{};
    for (final log in _logs) {
      if (log.isMissed) continue;
      final key = (log.doingTag, log.shouldDoTag);
      counts[key] = (counts[key] ?? 0) + 1;
    }

    // Sort by frequency descending and take the top N.
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final newPresets = sorted
        .take(maxPresets)
        .map((e) => QuickPreset(doingTag: e.key.$1, shouldDoTag: e.key.$2))
        .toList();

    _settings = _settings.copyWith(quickPresets: newPresets);
    unawaited(_storage.saveSettings(_settings));
  }

  void setOpenedFromNotification(bool value) {
    _openedFromNotification = value;
    notifyListeners();
  }

  void clearNotificationFlag() {
    _openedFromNotification = false;
  }

  /// Pause check-in notifications for [delay], then automatically resume.
  Future<void> snoozeCheckIn(Duration delay) async {
    _snoozedUntil = DateTime.now().add(delay);
    _snoozeCountdownTimer?.cancel();
    _snoozeCountdownTimer = Timer(delay, () {
      _snoozedUntil = null;
      _snoozeCountdownTimer = null;
      // Resume the periodic schedule from now
      if (_settings.intervalEnabled) {
        _scheduledAt = DateTime.now();
        _notifications.scheduleCheckIn(_settings.checkInIntervalMinutes);
      }
      notifyListeners();
    });

    if (_settings.intervalEnabled) {
      await _notifications.snoozeCheckIn(delay);
    }
    notifyListeners();
  }

  Future<void> setThemeMode(String mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    try {
      await _storage.saveSettings(_settings);
    } on StorageException catch (e) {
      _errorMessage = e.message;
      _logger.error('Failed to toggle dark mode', e, null, 'AppState');
    }
    notifyListeners();
  }

  Future<void> testNotification() async {
    await _notifications.showTestNotification();
  }

  Future<void> togglePartyMode() async {
    _settings = _settings.copyWith(partyMode: !_settings.partyMode);
    try {
      await _storage.saveSettings(_settings);
    } on StorageException catch (e) {
      _errorMessage = e.message;
      _logger.error('Failed to toggle party mode', e, null, 'AppState');
    }
    notifyListeners();
  }

  Future<void> addScheduledTime(String time) async {
    if (_settings.scheduledTimes.contains(time)) return;

    final newTimes = [..._settings.scheduledTimes, time];
    newTimes.sort(); // Sort times chronologically
    _settings = _settings.copyWith(scheduledTimes: newTimes);

    try {
      await _storage.saveSettings(_settings);
      if (_settings.scheduledEnabled) {
        await _notifications.scheduleAtTimes(newTimes);
      }
    } on StorageException catch (e) {
      _errorMessage = e.message;
      _logger.error('Failed to add scheduled time', e, null, 'AppState');
    }
    notifyListeners();
  }

  Future<void> removeScheduledTime(String time) async {
    final newTimes = _settings.scheduledTimes.where((t) => t != time).toList();
    _settings = _settings.copyWith(scheduledTimes: newTimes);

    try {
      await _storage.saveSettings(_settings);
      if (_settings.scheduledEnabled) {
        await _notifications.scheduleAtTimes(newTimes);
      }
    } on StorageException catch (e) {
      _errorMessage = e.message;
      _logger.error('Failed to remove scheduled time', e, null, 'AppState');
    }
    notifyListeners();
  }

  Future<void> toggleIntervalEnabled(bool enabled) async {
    _settings = _settings.copyWith(intervalEnabled: enabled);
    try {
      await _storage.saveSettings(_settings);
    } on StorageException catch (e) {
      _errorMessage = e.message;
      _logger.error('Failed to toggle interval enabled', e, null, 'AppState');
    }

    if (enabled) {
      final hasPermission = await _notifications.requestPermissions();
      if (hasPermission) {
        await _notifications.scheduleCheckIn(_settings.checkInIntervalMinutes);
        _scheduledAt = DateTime.now();
      }
    } else {
      await _notifications.cancelCheckIn();
      _scheduledAt = null;
    }

    notifyListeners();
  }

  Future<void> toggleScheduledEnabled(bool enabled) async {
    _settings = _settings.copyWith(scheduledEnabled: enabled);
    try {
      await _storage.saveSettings(_settings);
    } on StorageException catch (e) {
      _errorMessage = e.message;
      _logger.error('Failed to toggle scheduled enabled', e, null, 'AppState');
    }

    if (enabled && _settings.scheduledTimes.isNotEmpty) {
      await _notifications.scheduleAtTimes(_settings.scheduledTimes);
    } else if (!enabled) {
      await _notifications.cancelScheduledTimes();
    }

    notifyListeners();
  }

  String exportLogsToJson() {
    final data = {
      'exportDate': DateTime.now().toIso8601String(),
      'version': 1,
      'logs': _logs.map((log) => log.toJson()).toList(),
      'settings': _settings.toJson(),
    };
    _logger.info('Exported ${_logs.length} logs', 'AppState');
    return jsonEncode(data);
  }

  Future<bool> importLogsFromJson(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate required fields
      if (!data.containsKey('logs') || data['logs'] is! List) {
        _errorMessage = 'Invalid backup file: no logs found';
        notifyListeners();
        return false;
      }

      final List<dynamic> logsList = data['logs'];
      final importedLogs = logsList
          .map((json) => LogEntry.fromJson(json as Map<String, dynamic>))
          .toList();

      // Merge with existing logs, avoiding duplicates by timestamp
      final existingTimestamps = _logs.map((l) => l.timestamp.toIso8601String()).toSet();
      int addedCount = 0;

      for (final log in importedLogs) {
        if (!existingTimestamps.contains(log.timestamp.toIso8601String())) {
          _logs.add(log);
          addedCount++;
        }
      }

      _invalidateStatsCache();

      // Restore settings if present in backup
      if (data['settings'] != null) {
        _settings = AppSettings.fromJson(data['settings'] as Map<String, dynamic>);
        try {
          await _storage.saveSettings(_settings);
        } on StorageException catch (e) {
          _logger.error('Failed to save imported settings', e, null, 'AppState');
        }
      }

      try {
        await _storage.saveLogs(_logs);
      } on StorageException catch (e) {
        _errorMessage = e.message;
        _logger.error('Failed to save imported logs', e, null, 'AppState');
        notifyListeners();
        return false;
      }

      _logger.info('Imported $addedCount new logs (${importedLogs.length - addedCount} duplicates skipped)', 'AppState');
      notifyListeners();
      return true;
    } catch (e, stack) {
      _errorMessage = 'Failed to import: invalid file format';
      _logger.error('Failed to import logs', e, stack, 'AppState');
      notifyListeners();
      return false;
    }
  }

  Future<void> updateHomePageLayout(List<String> order, List<String> hidden) async {
    _settings = _settings.copyWith(
      homePageSectionOrder: order,
      homePageHiddenSections: hidden,
    );
    try {
      await _storage.saveSettings(_settings);
    } on StorageException catch (e) {
      _errorMessage = e.message;
      _logger.error('Failed to update home page layout', e, null, 'AppState');
    }
    notifyListeners();
  }

  Future<void> updateStatsPageLayout(List<String> order, List<String> hidden) async {
    _settings = _settings.copyWith(
      statsPageSectionOrder: order,
      statsPageHiddenSections: hidden,
    );
    try {
      await _storage.saveSettings(_settings);
    } on StorageException catch (e) {
      _errorMessage = e.message;
      _logger.error('Failed to update stats page layout', e, null, 'AppState');
    }
    notifyListeners();
  }

  Future<void> clearAllLogs() async {
    _logs.clear();
    _invalidateStatsCache();
    try {
      await _storage.clearLogs();
      _logger.info('All logs cleared', 'AppState');
    } on StorageException catch (e) {
      _errorMessage = e.message;
      _logger.error('Failed to clear logs', e, null, 'AppState');
    }
    notifyListeners();
  }

  // ── CSV export / import ──────────────────────────────────────────────────

  static String _csvEscape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  String exportLogsToCsv() {
    final buffer = StringBuffer();
    buffer.writeln(
        'timestamp,doingTag,shouldDoTag,importance,notes,responseTimeSeconds,intentionAdherence,isMissed');
    for (final log in _logs) {
      buffer.write(_csvEscape(log.timestamp.toIso8601String()));
      buffer.write(',');
      buffer.write(_csvEscape(log.doingTag));
      buffer.write(',');
      buffer.write(_csvEscape(log.shouldDoTag));
      buffer.write(',');
      buffer.write(log.importance != null ? log.importance.toString() : '');
      buffer.write(',');
      buffer.write(log.notes != null ? _csvEscape(log.notes!) : '');
      buffer.write(',');
      buffer.write(log.responseTimeSeconds != null
          ? log.responseTimeSeconds.toString()
          : '');
      buffer.write(',');
      buffer.write(log.intentionAdherence != null
          ? log.intentionAdherence.toString()
          : '');
      buffer.write(',');
      buffer.write(log.isMissed ? 'true' : '');
      buffer.writeln();
    }
    _logger.info('Exported ${_logs.length} logs as CSV', 'AppState');
    return buffer.toString();
  }

  Future<bool> importLogsFromCsv(String csvString) async {
    try {
      final rows = _parseCsvRows(csvString);
      if (rows.length < 2) {
        _errorMessage = 'Invalid CSV: no data rows found';
        notifyListeners();
        return false;
      }

      // Build column-name → index map from header row
      final header = rows.first;
      final colIndex = <String, int>{};
      for (int i = 0; i < header.length; i++) {
        colIndex[header[i].trim()] = i;
      }

      String field(List<String> row, String name) {
        final idx = colIndex[name];
        if (idx == null || idx >= row.length) return '';
        return row[idx];
      }

      final importedLogs = <LogEntry>[];
      for (final row in rows.skip(1)) {
        if (row.isEmpty || (row.length == 1 && row.first.isEmpty)) continue;
        final ts = field(row, 'timestamp');
        if (ts.isEmpty) continue;
        final entry = LogEntry(
          timestamp: DateTime.parse(ts),
          doingTag: field(row, 'doingTag'),
          shouldDoTag: field(row, 'shouldDoTag'),
          importance: int.tryParse(field(row, 'importance')),
          notes: field(row, 'notes').isEmpty ? null : field(row, 'notes'),
          responseTimeSeconds:
              int.tryParse(field(row, 'responseTimeSeconds')),
          intentionAdherence:
              int.tryParse(field(row, 'intentionAdherence')),
          isMissed: field(row, 'isMissed') == 'true',
        );
        importedLogs.add(entry);
      }

      final existingTimestamps =
          _logs.map((l) => l.timestamp.toIso8601String()).toSet();
      int addedCount = 0;
      for (final log in importedLogs) {
        if (!existingTimestamps.contains(log.timestamp.toIso8601String())) {
          _logs.add(log);
          addedCount++;
        }
      }

      _invalidateStatsCache();

      try {
        await _storage.saveLogs(_logs);
      } on StorageException catch (e) {
        _errorMessage = e.message;
        _logger.error('Failed to save imported CSV logs', e, null, 'AppState');
        notifyListeners();
        return false;
      }

      _logger.info(
          'Imported $addedCount new logs from CSV (${importedLogs.length - addedCount} duplicates skipped)',
          'AppState');
      notifyListeners();
      return true;
    } catch (e, stack) {
      _errorMessage = 'Failed to import CSV: invalid file format';
      _logger.error('Failed to import CSV logs', e, stack, 'AppState');
      notifyListeners();
      return false;
    }
  }

  /// RFC 4180-compliant CSV parser. Returns a list of rows, each row a list
  /// of field strings.
  List<List<String>> _parseCsvRows(String csv) {
    final rows = <List<String>>[];
    final fields = <String>[];
    final fieldBuf = StringBuffer();
    bool inQuotes = false;
    int i = 0;

    while (i < csv.length) {
      final ch = csv[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < csv.length && csv[i + 1] == '"') {
            fieldBuf.write('"');
            i += 2;
          } else {
            inQuotes = false;
            i++;
          }
        } else {
          fieldBuf.write(ch);
          i++;
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
          i++;
        } else if (ch == ',') {
          fields.add(fieldBuf.toString());
          fieldBuf.clear();
          i++;
        } else if (ch == '\r') {
          fields.add(fieldBuf.toString());
          fieldBuf.clear();
          rows.add(List<String>.from(fields));
          fields.clear();
          // Skip following \n if present
          if (i + 1 < csv.length && csv[i + 1] == '\n') i++;
          i++;
        } else if (ch == '\n') {
          fields.add(fieldBuf.toString());
          fieldBuf.clear();
          rows.add(List<String>.from(fields));
          fields.clear();
          i++;
        } else {
          fieldBuf.write(ch);
          i++;
        }
      }
    }
    // Handle last field / row (no trailing newline)
    if (fieldBuf.isNotEmpty || fields.isNotEmpty) {
      fields.add(fieldBuf.toString());
      rows.add(List<String>.from(fields));
    }
    return rows;
  }

  // ── Quick-reply presets ──────────────────────────────────────────────────

  Future<void> addQuickPreset(String doingTag, String shouldDoTag) async {
    if (_settings.quickPresets
        .any((p) => p.doingTag == doingTag && p.shouldDoTag == shouldDoTag)) {
      return;
    }
    _settings = _settings.copyWith(quickPresets: [
      ..._settings.quickPresets,
      QuickPreset(doingTag: doingTag, shouldDoTag: shouldDoTag),
    ]);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> removeQuickPreset(int index) async {
    final updated = List<QuickPreset>.from(_settings.quickPresets)
      ..removeAt(index);
    _settings = _settings.copyWith(quickPresets: updated);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }
}
