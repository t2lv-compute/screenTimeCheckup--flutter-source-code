import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_state.dart';
import '../widgets/title_text.dart';
import '../widgets/tag_input.dart';
import '../services/file_service.dart';
import '../services/platform_service.dart';

class SettingsPage extends StatefulWidget {
  final String? initialScrollTarget;

  const SettingsPage({super.key, this.initialScrollTarget});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _intervalController;
  late TextEditingController _intentionController;
  final FileService _fileService = FileService();
  final PlatformService _platformService = PlatformService();
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _settingsKey = GlobalKey();
  final GlobalKey _dataManagementKey = GlobalKey();
  final GlobalKey _intentionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _intervalController = TextEditingController();
    _intentionController = TextEditingController();

    if (widget.initialScrollTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleScrollTarget(widget.initialScrollTarget!);
      });
    }

    // Re-check PWA installability after the page settles so the button
    // appears even if beforeinstallprompt fires while this page is open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialScrollTarget != null &&
        widget.initialScrollTarget != oldWidget.initialScrollTarget) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleScrollTarget(widget.initialScrollTarget!);
      });
    }
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _intentionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScrollTarget(String target) {
    switch (target) {
      case 'intention':
        _scrollToSection(_intentionKey);
      case 'settings':
        _scrollToSection(_settingsKey);
      case 'dataManagement':
        _scrollToSection(_dataManagementKey);
    }
  }

  void _scrollToSection(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = key.currentContext;
      if (context != null) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          final position = box.localToGlobal(Offset.zero);
          final targetOffset = _scrollController.offset + position.dy - 15.0;
          _scrollController.animateTo(
            targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  String _formatTime(String time24) {
    final parts = time24.split(':');
    if (parts.length != 2) return time24;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$hour12:$minute $period';
  }

  Future<void> _showAddTimeDialog(BuildContext context, AppState appState) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return child!;
      },
    );

    if (picked != null) {
      final time24 = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await appState.addScheduledTime(time24);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder scheduled for ${_formatTime(time24)}')),
        );
      }
    }
  }

  void _showIosInstallSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add to Home Screen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Install this app on your iPhone or iPad in 3 steps:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            _iosStep(context, Icons.ios_share, 'Tap the Share button',
                'The box with an arrow pointing up at the bottom of Safari.'),
            _iosStep(context, Icons.add_box_outlined, 'Tap "Add to Home Screen"',
                'Scroll down in the share sheet to find it.'),
            _iosStep(context, Icons.check_circle_outline, 'Tap "Add"',
                'The app will appear on your home screen like a native app.'),
          ],
        ),
      ),
    );
  }

  Widget _iosStep(BuildContext context, IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTroubleshootDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: ((MediaQuery.of(context).size.width - 480) / 2).clamp(24.0, double.infinity),
          vertical: 24,
        ),
        title: const Text('Troubleshoot'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'If you are not receiving notifications, expand your platform below for steps to fix it.',
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('macOS / Chrome', style: TextStyle(fontWeight: FontWeight.bold)),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('1. Open System Settings'),
                        Text('2. Go to Notifications'),
                        Text('3. Find Google Chrome in the list'),
                        Text('4. Toggle "Allow Notifications" on'),
                      ],
                    ),
                  ),
                ],
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Windows / Edge', style: TextStyle(fontWeight: FontWeight.bold)),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('1. Open Windows Settings > System > Notifications'),
                        Text('2. Ensure Microsoft Edge is toggled on'),
                        Text('3. Also check Edge site permissions:'),
                        Text('   edge://settings/content/notifications'),
                        Text('4. Make sure this site is not in the "Block" list'),
                      ],
                    ),
                  ),
                ],
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Windows / Chrome', style: TextStyle(fontWeight: FontWeight.bold)),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('1. Open Windows Settings > System > Notifications'),
                        Text('2. Ensure Google Chrome is toggled on'),
                        Text('3. Also check Chrome site permissions:'),
                        Text('   chrome://settings/content/notifications'),
                        Text('4. Make sure this site is not in the "Block" list'),
                      ],
                    ),
                  ),
                ],
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Android', style: TextStyle(fontWeight: FontWeight.bold)),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('1. Open Settings > Apps > find your browser'),
                        Text('2. Tap Notifications and enable them'),
                        Text('3. In your browser, open site settings for this page'),
                        Text('4. Set Notifications to "Allow"'),
                        Text('5. For reliable delivery: Settings > Battery > Battery Optimization'),
                        Text('   Find your browser and select "Don\'t optimize"'),
                      ],
                    ),
                  ),
                ],
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Web (General)', style: TextStyle(fontWeight: FontWeight.bold)),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('1. Click the padlock icon in the address bar'),
                        Text('2. Find "Notifications" and set it to "Allow"'),
                        Text('3. If notifications are greyed out, go to your browser\'s'),
                        Text('   site settings and reset permissions for this page'),
                        Text('4. Reload the page and tap "Allow" when prompted'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(AppState appState) {
    return ExpansionTile(
          key: _settingsKey,
          title: const Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          initiallyExpanded: true,
          onExpansionChanged: (expanded) {
            if (expanded) _scrollToSection(_settingsKey);
          },
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Focus Activities',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Things you want to be doing \u2014 your productive activities',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  TagInput(
                    initialTags: appState.settings.focusTags,
                    onTagsChanged: (tags) => appState.updateFocusTags(tags),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Distractions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Things that pull you off track',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  TagInput(
                    initialTags: appState.settings.distractionTags,
                    onTagsChanged: (tags) => appState.updateDistractionTags(tags),
                  ),
                  const SizedBox(height: 24),
                  Column(
                    key: _intentionKey,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Session Intention',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Set a goal for your current session to stay focused',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _intentionController,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                hintText: 'e.g., Finish the report',
                                suffixIcon: appState.settings.sessionIntention.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.close),
                                        tooltip: 'Clear intention',
                                        onPressed: () {
                                          _intentionController.clear();
                                          appState.clearSessionIntention();
                                        },
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              final text = _intentionController.text.trim();
                              if (text.isNotEmpty) {
                                appState.updateSessionIntention(text);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Session intention saved'),
                                  ),
                                );
                              }
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Session duration — how long before the intention prompt reappears
                  const Text(
                    'Session Duration',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'How long before you\'re asked to re-confirm your intention',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<int>(value: appState.settings.sessionDurationMinutes, items: const [
                    DropdownMenuItem(value: 30, child: Text('30 min')),
                    DropdownMenuItem(value: 60, child: Text('1 hour')),
                    DropdownMenuItem(value: 90, child: Text('1.5 hours')),
                    DropdownMenuItem(value: 120, child: Text('2 hours')),
                    DropdownMenuItem(value: 180, child: Text('3 hours')),
                    DropdownMenuItem(value: 240, child: Text('4 hours')),
                    DropdownMenuItem(value: 480, child: Text('8 hours')),
                  ], onChanged: (value) {
                    if (value != null) {
                      appState.updateSessionDuration(value);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Session duration set to ${value >= 60 ? '${value ~/ 60} hour${value > 60 ? 's' : ''}' : '$value min'}')),
                      );
                    }
                  }),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Interval Check-ins (minutes)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Switch(
                        value: appState.settings.intervalEnabled,
                        onChanged: (value) => appState.toggleIntervalEnabled(value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _intervalController,
                          textAlign: TextAlign.center,
                          enabled: appState.settings.intervalEnabled,
                          style: const TextStyle(fontSize: 16),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'e.g., 15',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: appState.settings.intervalEnabled
                            ? () {
                                final minutes =
                                    int.tryParse(_intervalController.text);
                                if (minutes != null && minutes > 0) {
                                  appState.updateInterval(minutes);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Check-in scheduled every $minutes minutes'),
                                    ),
                                  );
                                }
                              }
                            : null,
                        child: const Text('Save & Schedule'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Scheduled Reminders',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Switch(
                        value: appState.settings.scheduledEnabled,
                        onChanged: (value) => appState.toggleScheduledEnabled(value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text(
                          'Get notified at specific times each day',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      IconButton(
                        onPressed: appState.settings.scheduledEnabled
                            ? () => _showAddTimeDialog(context, appState)
                            : null,
                        icon: const Icon(Icons.add_alarm),
                        tooltip: 'Add time',
                      ),
                    ],
                  ),
                  if (appState.settings.scheduledTimes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Opacity(
                        opacity: appState.settings.scheduledEnabled ? 1.0 : 0.5,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: appState.settings.scheduledTimes.map((time) {
                            return Chip(
                              label: Text(_formatTime(time)),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: appState.settings.scheduledEnabled
                                  ? () => appState.removeScheduledTime(time)
                                  : null,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [OutlinedButton.icon(
                    onPressed: () {
                      appState.testNotification();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notification sent! Check your system tray.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications),
                    label: const Text('Test Notification'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showTroubleshootDialog(context),
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Troubleshoot'),
                  ),
                  ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Theme',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'light',
                            icon: Icon(Icons.light_mode_outlined),
                            label: Text('Light'),
                          ),
                          ButtonSegment(
                            value: 'system',
                            icon: Icon(Icons.brightness_auto_outlined),
                            label: Text('Auto'),
                          ),
                          ButtonSegment(
                            value: 'dark',
                            icon: Icon(Icons.dark_mode_outlined),
                            label: Text('Dark'),
                          ),
                        ],
                        selected: {appState.settings.themeMode},
                        onSelectionChanged: (selection) =>
                            appState.setThemeMode(selection.first),
                      ),
                    ],
                  ),
                  if (_platformService.canInstallPwa) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_platformService.isIosSafari) {
                            _showIosInstallSheet(context);
                          } else {
                            _platformService.promptPwaInstall();
                          }
                        },
                        icon: const Icon(Icons.install_mobile),
                        label: Text(_platformService.isIosSafari
                            ? 'Add to Home Screen'
                            : 'Install App'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
  }

  Widget _buildDataManagementSection(AppState appState) {
    return ExpansionTile(
          key: _dataManagementKey,
          title: const Text('Data Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          initiallyExpanded: true,
          onExpansionChanged: (expanded) {
            if (expanded) _scrollToSection(_dataManagementKey);
          },
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Backup your data to avoid losing it when browser storage is cleared.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final json = appState.exportLogsToJson();
                            final filename = 'screen_time_backup_${DateTime.now().toIso8601String().split('T')[0]}.json';
                            await _fileService.downloadJson(json, filename);
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Backup downloaded!')),
                            );
                          },
                          icon: const Icon(Icons.download),
                          label: const Text('Export'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final json = await _fileService.pickAndReadJsonFile();
                            if (json != null) {
                              final success = await appState.importLogsFromJson(json);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(success
                                      ? 'Data imported successfully!'
                                      : 'Failed to import data'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.upload),
                          label: const Text('Import'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final csv = appState.exportLogsToCsv();
                            final filename =
                                'screen_time_backup_${DateTime.now().toIso8601String().split('T')[0]}.csv';
                            await _fileService.downloadCsv(csv, filename);
                            messenger.showSnackBar(
                              const SnackBar(
                                  content: Text('CSV exported!')),
                            );
                          },
                          icon: const Icon(Icons.download),
                          label: const Text('Export CSV'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final csv =
                                await _fileService.pickAndReadCsvFile();
                            if (csv != null) {
                              final success =
                                  await appState.importLogsFromCsv(csv);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(success
                                      ? 'CSV imported successfully!'
                                      : 'Failed to import CSV'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.upload),
                          label: const Text('Import CSV'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: appState.totalLogs == 0
                              ? null
                              : () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Clear All Logs?'),
                                      content: const Text(
                                        'This will permanently delete all your check-in logs. This action cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Theme.of(context).colorScheme.error,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    await appState.clearAllLogs();
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('All logs cleared')),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Clear Logs'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (appState.settings.focusTags.isEmpty && appState.settings.distractionTags.isEmpty)
                              ? null
                              : () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Reset Tags?'),
                                      content: const Text(
                                        'This will remove all your activity tags. You will need to add new tags before logging.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Theme.of(context).colorScheme.error,
                                          ),
                                          child: const Text('Reset'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    await appState.updateFocusTags([]);
                                    await appState.updateDistractionTags([]);
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('Tags reset')),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.label_off),
                          label: const Text('Reset Tags'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final screenWidth = MediaQuery.of(context).size.width;
    final useTwoColumns = screenWidth >= 768;

    if (_intervalController.text.isEmpty && !appState.isLoading) {
      _intervalController.text =
          appState.settings.checkInIntervalMinutes.toString();
    }

    if (!appState.isLoading && _intentionController.text.isEmpty && appState.settings.sessionIntention.isNotEmpty) {
      _intentionController.text = appState.settings.sessionIntention;
    }

    if (appState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (useTwoColumns) {
      return ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        children: [
          const TitleText(text: 'Settings'),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildSettingsSection(appState)),
              const SizedBox(width: 16),
              Expanded(child: _buildDataManagementSection(appState)),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse('https://forms.gle/bw5Lekf1AjL6fF4eA')),
              icon: const Icon(Icons.feedback_outlined),
              label: const Text('Submit Feedback'),
            ),
          ),
          const SizedBox(height: 80),
        ],
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      children: [
        const TitleText(text: 'Settings'),
        const SizedBox(height: 16),
        _buildSettingsSection(appState),
        _buildDataManagementSection(appState),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse('https://forms.gle/bw5Lekf1AjL6fF4eA')),
            icon: const Icon(Icons.feedback_outlined),
            label: const Text('Submit Feedback'),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
