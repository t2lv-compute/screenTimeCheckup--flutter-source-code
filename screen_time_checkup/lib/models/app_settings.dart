import 'quick_preset.dart';

class AppSettings {
  final List<String> focusTags;
  final List<String> distractionTags;
  final int checkInIntervalMinutes;
  /// One of 'light', 'dark', or 'system'.
  final String themeMode;
  final bool hasSeenTutorial;

  bool get isDarkMode => themeMode == 'dark';
  final bool partyMode;
  /// Scheduled reminder times in "HH:mm" format (24-hour)
  final List<String> scheduledTimes;
  final String sessionIntention;
  final bool intervalEnabled;
  final bool scheduledEnabled;

  // Page layout customization
  final List<String> homePageSectionOrder;
  final List<String> homePageHiddenSections;
  final List<String> statsPageSectionOrder;
  final List<String> statsPageHiddenSections;

  /// Number of interval notifications that have fired without a check-in response.
  /// Incremented when a notification fires, decremented when the user taps it.
  final int remainingCheckIns;

  /// Learned weights for notification messages (message id → weight).
  /// Missing keys default to 1.0. Updated after each notification response.
  final Map<String, double> notificationWeights;

  final List<QuickPreset> quickPresets;

  static const List<String> defaultFocusTags = [
    'school',
    'work',
    'email',
  ];

  static const List<String> defaultDistractionTags = [
    'social media',
    'websurfing',
  ];

  static const List<String> defaultHomePageSectionOrder = [
    'timer',
    'intention',
    'streak',
    'checkin',
    'quickStats',
  ];

  static const List<String> defaultStatsPageSectionOrder = [
    'trendChart',
    'keyStats',
    'history',
  ];

  AppSettings({
    List<String>? focusTags,
    List<String>? distractionTags,
    this.checkInIntervalMinutes = 15,
    this.themeMode = 'system',
    this.hasSeenTutorial = false,
    this.partyMode = false,
    List<String>? scheduledTimes,
    this.sessionIntention = '',
    this.intervalEnabled = true,
    this.scheduledEnabled = true,
    List<String>? homePageSectionOrder,
    List<String>? homePageHiddenSections,
    List<String>? statsPageSectionOrder,
    List<String>? statsPageHiddenSections,
    this.remainingCheckIns = 0,
    List<QuickPreset>? quickPresets,
    Map<String, double>? notificationWeights,
  })  : quickPresets = quickPresets ?? [],
        notificationWeights = notificationWeights ?? {},
        focusTags = focusTags ?? defaultFocusTags,
        distractionTags = distractionTags ?? defaultDistractionTags,
        scheduledTimes = scheduledTimes ?? [],
        homePageSectionOrder = homePageSectionOrder ?? defaultHomePageSectionOrder,
        homePageHiddenSections = homePageHiddenSections ?? [],
        statsPageSectionOrder = statsPageSectionOrder ?? defaultStatsPageSectionOrder,
        statsPageHiddenSections = statsPageHiddenSections ?? [];

  List<String> get allTags => [...focusTags, ...distractionTags];

  AppSettings copyWith({
    List<String>? focusTags,
    List<String>? distractionTags,
    int? checkInIntervalMinutes,
    String? themeMode,
    bool? hasSeenTutorial,
    bool? partyMode,
    List<String>? scheduledTimes,
    String? sessionIntention,
    bool? intervalEnabled,
    bool? scheduledEnabled,
    List<String>? homePageSectionOrder,
    List<String>? homePageHiddenSections,
    List<String>? statsPageSectionOrder,
    List<String>? statsPageHiddenSections,
    int? remainingCheckIns,
    List<QuickPreset>? quickPresets,
    Map<String, double>? notificationWeights,
  }) =>
      AppSettings(
        focusTags: focusTags ?? this.focusTags,
        distractionTags: distractionTags ?? this.distractionTags,
        checkInIntervalMinutes:
            checkInIntervalMinutes ?? this.checkInIntervalMinutes,
        themeMode: themeMode ?? this.themeMode,
        hasSeenTutorial: hasSeenTutorial ?? this.hasSeenTutorial,
        partyMode: partyMode ?? this.partyMode,
        scheduledTimes: scheduledTimes ?? this.scheduledTimes,
        sessionIntention: sessionIntention ?? this.sessionIntention,
        intervalEnabled: intervalEnabled ?? this.intervalEnabled,
        scheduledEnabled: scheduledEnabled ?? this.scheduledEnabled,
        homePageSectionOrder: homePageSectionOrder ?? this.homePageSectionOrder,
        homePageHiddenSections: homePageHiddenSections ?? this.homePageHiddenSections,
        statsPageSectionOrder: statsPageSectionOrder ?? this.statsPageSectionOrder,
        statsPageHiddenSections: statsPageHiddenSections ?? this.statsPageHiddenSections,
        remainingCheckIns: remainingCheckIns ?? this.remainingCheckIns,
        quickPresets: quickPresets ?? this.quickPresets,
        notificationWeights: notificationWeights ?? this.notificationWeights,
      );

  Map<String, dynamic> toJson() => {
        'focusTags': focusTags,
        'distractionTags': distractionTags,
        'checkInIntervalMinutes': checkInIntervalMinutes,
        'themeMode': themeMode,
        'hasSeenTutorial': hasSeenTutorial,
        'partyMode': partyMode,
        'scheduledTimes': scheduledTimes,
        'sessionIntention': sessionIntention,
        'intervalEnabled': intervalEnabled,
        'scheduledEnabled': scheduledEnabled,
        'homePageSectionOrder': homePageSectionOrder,
        'homePageHiddenSections': homePageHiddenSections,
        'statsPageSectionOrder': statsPageSectionOrder,
        'statsPageHiddenSections': statsPageHiddenSections,
        'remainingCheckIns': remainingCheckIns,
        'quickPresets': quickPresets.map((p) => p.toJson()).toList(),
        'notificationWeights': notificationWeights,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    List<String> focusTags;
    List<String> distractionTags;

    if (json.containsKey('focusTags')) {
      // New format
      focusTags = List<String>.from(json['focusTags'] ?? []);
      distractionTags = List<String>.from(json['distractionTags'] ?? []);
    } else if (json.containsKey('actionTags')) {
      // Legacy migration: put all existing tags into focus
      focusTags = List<String>.from(json['actionTags'] ?? []);
      distractionTags = [];
    } else {
      focusTags = [];
      distractionTags = [];
    }

    // Migrate legacy isDarkMode bool to themeMode string
    final String themeMode;
    if (json.containsKey('themeMode')) {
      themeMode = json['themeMode'] as String;
    } else {
      themeMode = (json['isDarkMode'] == true) ? 'dark' : 'light';
    }

    // Graceful fallback for page layout fields
    List<String> parseStringList(dynamic value, List<String> fallback) {
      if (value is List) {
        try {
          return List<String>.from(value);
        } catch (_) {
          return fallback;
        }
      }
      return fallback;
    }

    // Migrate legacy section IDs (overview → trendChart + keyStats, tagBreakdown removed)
    List<String> migrateIds(List<String> ids) {
      final result = <String>[];
      for (final id in ids) {
        if (id == 'overview') {
          result.add('trendChart');
          result.add('keyStats');
        } else if (id == 'tagBreakdown') {
          // merged into keyStats — skip
        } else {
          result.add(id);
        }
      }
      // Deduplicate while preserving order
      final seen = <String>{};
      return result.where(seen.add).toList();
    }

    var statsOrder = migrateIds(parseStringList(
      json['statsPageSectionOrder'],
      AppSettings.defaultStatsPageSectionOrder,
    ));
    // Ensure keyStats is present after trendChart if migration added trendChart
    if (statsOrder.contains('trendChart') && !statsOrder.contains('keyStats')) {
      final idx = statsOrder.indexOf('trendChart');
      statsOrder.insert(idx + 1, 'keyStats');
    }

    final statsHidden = parseStringList(json['statsPageHiddenSections'], [])
        .where((id) => id != 'tagBreakdown')
        .map((id) => id == 'overview' ? 'trendChart' : id)
        .toList();

    return AppSettings(
      focusTags: focusTags,
      distractionTags: distractionTags,
      checkInIntervalMinutes: json['checkInIntervalMinutes'] ?? 15,
      themeMode: themeMode,
      hasSeenTutorial: json['hasSeenTutorial'] ?? false,
      partyMode: json['partyMode'] ?? false,
      scheduledTimes: List<String>.from(json['scheduledTimes'] ?? []),
      sessionIntention: json['sessionIntention'] as String? ?? '',
      intervalEnabled: json['intervalEnabled'] ?? true,
      scheduledEnabled: json['scheduledEnabled'] ?? true,
      homePageSectionOrder: parseStringList(
        json['homePageSectionOrder'],
        AppSettings.defaultHomePageSectionOrder,
      ),
      homePageHiddenSections: parseStringList(
        json['homePageHiddenSections'],
        [],
      ),
      statsPageSectionOrder: statsOrder,
      statsPageHiddenSections: statsHidden,
      remainingCheckIns: json['remainingCheckIns'] as int? ?? 0,
      quickPresets: (json['quickPresets'] as List?)
              ?.map((e) => QuickPreset.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      notificationWeights: (json['notificationWeights'] as Map?)
              ?.map((k, v) => MapEntry(k as String, (v as num).toDouble())) ??
          {},
    );
  }
}
