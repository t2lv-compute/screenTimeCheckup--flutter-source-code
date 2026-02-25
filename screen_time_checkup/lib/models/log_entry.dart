class LogEntry {
  final DateTime timestamp;
  final String doingTag;
  final String shouldDoTag;
  final int? importance;
  /// Seconds from notification to response. Null if not from a notification.
  final int? responseTimeSeconds;
  /// Optional free-text notes for context.
  final String? notes;
  /// Adherence to session intention (0-10 scale). Null if no intention was set.
  final int? intentionAdherence;
  /// True when this entry was auto-generated to record a missed notification.
  final bool isMissed;

  LogEntry({
    required this.timestamp,
    required this.doingTag,
    required this.shouldDoTag,
    this.importance,
    this.responseTimeSeconds,
    this.notes,
    this.intentionAdherence,
    this.isMissed = false,
  });

  /// Convenience constructor for an auto-generated missed-notification entry.
  LogEntry.missed({required this.timestamp})
      : doingTag = '',
        shouldDoTag = '',
        importance = null,
        responseTimeSeconds = null,
        notes = null,
        intentionAdherence = null,
        isMissed = true;

  /// Missed entries are never on-track.
  bool get isOnTrack =>
      !isMissed && doingTag.toLowerCase() == shouldDoTag.toLowerCase();

  /// Whether this entry was triggered by a notification.
  bool get isFromNotification => responseTimeSeconds != null;

  /// Whether the user responded within 3 minutes (180 seconds).
  bool get isQuickResponse =>
      responseTimeSeconds != null && responseTimeSeconds! <= 180;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'doingTag': doingTag,
        'shouldDoTag': shouldDoTag,
        if (importance != null) 'importance': importance,
        if (responseTimeSeconds != null)
          'responseTimeSeconds': responseTimeSeconds,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (intentionAdherence != null)
          'intentionAdherence': intentionAdherence,
        if (isMissed) 'isMissed': true,
      };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        timestamp: DateTime.parse(json['timestamp']),
        doingTag: json['doingTag'] ?? '',
        shouldDoTag: json['shouldDoTag'] ?? '',
        importance: json['importance'] as int?,
        responseTimeSeconds: json['responseTimeSeconds'] as int?,
        notes: json['notes'] as String?,
        intentionAdherence: json['intentionAdherence'] as int?,
        isMissed: json['isMissed'] == true,
      );
}
