class QuickPreset {
  final String doingTag;
  final String shouldDoTag;

  const QuickPreset({required this.doingTag, required this.shouldDoTag});

  bool get isOnTrack => doingTag.toLowerCase() == shouldDoTag.toLowerCase();

  Map<String, dynamic> toJson() => {'doing': doingTag, 'shouldDo': shouldDoTag};

  factory QuickPreset.fromJson(Map<String, dynamic> json) => QuickPreset(
        doingTag: json['doing'] as String? ?? '',
        shouldDoTag: json['shouldDo'] as String? ?? '',
      );
}
