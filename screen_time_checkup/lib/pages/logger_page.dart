import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/tag_selector.dart';

class LoggerPage extends StatefulWidget {
  final void Function(bool isOnTrack)? onSubmitted;

  const LoggerPage({super.key, this.onSubmitted});

  @override
  State<LoggerPage> createState() => _LoggerPageState();
}

class _LoggerPageState extends State<LoggerPage> {
  String? _doingTag;
  String? _shouldDoTag;
  double _adherenceValue = 5.0;
  bool _showNotes = false;
  bool _tagsInitialized = false;

  final TextEditingController _notesController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_tagsInitialized) {
      _tagsInitialized = true;
      final appState = context.read<AppState>();
      if (appState.sortedLogs.isNotEmpty) {
        // Pre-populate "should do" from the last check-in — it usually stays
        // constant within a session. "Doing" is left blank since that's the
        // variable the user needs to report fresh each time.
        _shouldDoTag = appState.sortedLogs.first.shouldDoTag;
        final lastAdherence = appState.sortedLogs.first.intentionAdherence;
        if (lastAdherence != null) {
          _adherenceValue = lastAdherence.toDouble();
        } else {
          _adherenceValue = 5.0;
        }
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitLog(AppState appState) async {
    if (_doingTag == null || _shouldDoTag == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both tags before submitting'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final onTrack = _doingTag!.toLowerCase() == _shouldDoTag!.toLowerCase();
    final hasIntention = appState.settings.sessionIntention.isNotEmpty;

    await appState.addLogEntry(
      _doingTag!,
      _shouldDoTag!,
      intentionAdherence: hasIntention ? _adherenceValue.round() : null,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
    );

    if (mounted) {
      widget.onSubmitted?.call(onTrack);
    }
  }

  Future<void> _quickSubmit(AppState appState) async {
    final lastLog = appState.sortedLogs.first;
    final onTrack = lastLog.isOnTrack;
    await appState.addLogEntry(
      lastLog.doingTag,
      lastLog.shouldDoTag,
    );
    if (mounted) {
      widget.onSubmitted?.call(onTrack);
    }
  }

  Widget _buildQuickSubmit(AppState appState) {
    final lastLog = appState.sortedLogs.first;
    final isOnTrack = lastLog.isOnTrack;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _quickSubmit(appState),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                Icons.replay,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Same as last time',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Doing: ${lastLog.doingTag} · Should be: ${lastLog.shouldDoTag}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: Theme.of(context).brightness == Brightness.dark
                      ? [
                          BoxShadow(
                            color: (isOnTrack ? Colors.green : Colors.orange)
                                .withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  isOnTrack ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: isOnTrack ? Colors.green : Colors.orange,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetsRow(AppState appState) {
    final presets = appState.settings.quickPresets;
    if (presets.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(presets.length, (index) {
          final preset = presets[index];
          final color = preset.isOnTrack ? Colors.green : Colors.orange;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                await appState.addLogEntry(preset.doingTag, preset.shouldDoTag);
                if (mounted) {
                  widget.onSubmitted?.call(preset.isOnTrack);
                }
              },
              onLongPress: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Remove preset?'),
                    content: Text(
                        '${preset.doingTag} \u2192 ${preset.shouldDoTag}'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(ctx).colorScheme.error,
                        ),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await appState.removeQuickPreset(index);
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${preset.doingTag} \u2192 ${preset.shouldDoTag}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFormView(AppState appState, List<String> allTags, List<String> focusTags) {
    final screenWidth = MediaQuery.of(context).size.width;
    final useConstrainedWidth = screenWidth > 600;

    final hasIntention = appState.settings.sessionIntention.isNotEmpty;

    // Build the new response form content
    final newResponseForm = FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Session intention card
        if (hasIntention)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.flag,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session Intention',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            appState.settings.sessionIntention,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Doing tag selector (all activities)
        TagSelector(
          label: 'What are you doing?',
          selectedTag: _doingTag,
          availableTags: allTags,
          onChanged: (tag) => setState(() => _doingTag = tag),
        ),
        const SizedBox(height: 16),

        // Should-do tag selector (focus activities only)
        TagSelector(
          label: 'What should you be doing?',
          selectedTag: _shouldDoTag,
          availableTags: focusTags,
          onChanged: (tag) => setState(() => _shouldDoTag = tag),
        ),
        const SizedBox(height: 16),

        // Intention adherence — 3 quick-tap buttons instead of a slider
        const Text(
          'Did you stay on intention?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final entry in const [
              ('Not at all', 0.0),
              ('Somewhat', 5.0),
              ('Fully', 10.0),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: _adherenceValue == entry.$2
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      foregroundColor: _adherenceValue == entry.$2
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => setState(() => _adherenceValue = entry.$2),
                    child: Text(entry.$1, style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // Notes — collapsed by default to reduce visual noise
        if (_showNotes)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  autofocus: true,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Add context about what you\'re working on...',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          )
        else
          TextButton.icon(
            onPressed: () => setState(() => _showNotes = true),
            icon: const Icon(Icons.note_add_outlined, size: 18),
            label: const Text('Add a note'),
            style: TextButton.styleFrom(
              foregroundColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
              padding: EdgeInsets.zero,
            ),
          ),

        const SizedBox(height: 16),

        const SizedBox(height: 8),

        // Submit button
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: (allTags.isEmpty || focusTags.isEmpty) ? null : () => _submitLog(appState),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.send_rounded,
                    size: 32,
                    color: (allTags.isEmpty || focusTags.isEmpty)
                        ? Theme.of(context).disabledColor
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      allTags.isEmpty
                          ? 'Add tags in Settings first'
                          : focusTags.isEmpty
                              ? 'Add Focus Activities in Settings'
                              : 'Submit log',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: (allTags.isEmpty || focusTags.isEmpty)
                            ? Theme.of(context).disabledColor
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (allTags.isEmpty || focusTags.isEmpty) ...[
          const SizedBox(height: 16),
          Text(
            focusTags.isEmpty && allTags.isNotEmpty
                ? 'Add at least one Focus Activity in Settings to answer "What should you be doing?"'
                : 'Go to Home to add activity tags before logging',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ],
      ),
    );

    final screenHeight = MediaQuery.of(context).size.height;
    final useExpansionTile = screenHeight < 450;

    Widget content;
    if (appState.sortedLogs.isNotEmpty) {
      if (useExpansionTile) {
        // Compact view: quick submit + expandable new response form
        content = Column(
          children: [
            _buildQuickSubmit(appState),
            const SizedBox(height: 12),
            _buildPresetsRow(appState),
            if (appState.settings.quickPresets.isNotEmpty)
              const SizedBox(height: 4),
            ExpansionTile(
              title: const Text(
                'Or fill out a new response',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              tilePadding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: newResponseForm,
                ),
              ],
            ),
          ],
        );
      } else {
        // Taller view: quick submit + form shown directly
        content = Column(
          children: [
            _buildQuickSubmit(appState),
            const SizedBox(height: 16),
            _buildPresetsRow(appState),
            if (appState.settings.quickPresets.isNotEmpty)
              const SizedBox(height: 8),
            const SizedBox(height: 8),
            Text(
              'Or fill out a new response:',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            newResponseForm,
          ],
        );
      }
    } else {
      // No previous logs, show form directly
      content = newResponseForm;
    }

    if (useConstrainedWidth) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: content,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: content,
    );
  }

  bool get _hasUnsavedData =>
      _doingTag != null || _shouldDoTag != null || _notesController.text.isNotEmpty;

  Future<void> _handleBackPressed() async {
    if (!_hasUnsavedData) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard check-in?'),
        content: const Text('Your unsaved selections will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (shouldDiscard == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _snooze(AppState appState) async {
    await appState.snoozeCheckIn(const Duration(minutes: 10));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final allTags = appState.settings.allTags;
    final focusTags = appState.settings.focusTags;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBackPressed();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Check In'),
          actions: [
            TextButton(
              onPressed: () => _snooze(appState),
              child: const Text('Snooze 10 min'),
            ),
          ],
        ),
        body: _buildFormView(appState, allTags, focusTags),
      ),
    );
  }
}
