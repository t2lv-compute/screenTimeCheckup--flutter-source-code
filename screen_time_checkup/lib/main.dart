import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'pages/home_page.dart';
import 'pages/logger_page.dart';
import 'pages/stats_page.dart';
import 'pages/settings_page.dart';
import 'services/platform_service.dart';
import 'widgets/floating_balloons.dart';
import 'widgets/tutorial_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState()..loadData(),
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'Screen Time Checkup',
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color.fromARGB(255, 0, 50, 0),
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color.fromARGB(255, 0, 50, 0),
                brightness: Brightness.dark,
              ),
            ),
            themeMode: switch (appState.settings.themeMode) {
              'dark' => ThemeMode.dark,
              'light' => ThemeMode.light,
              _ => ThemeMode.system,
            },
            home: const MainNavigationPage(),
          );
        },
      ),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;
  String? _lastShownError;
  bool _tutorialShown = false;
  String? _scrollTarget;

  ConfettiController? _successConfettiController;
  bool _successDialogOpen = false;

  @override
  void dispose() {
    _successConfettiController?.dispose();
    super.dispose();
  }

  void _openCheckIn() {
    // Close any open success dialog before opening a new check-in
    if (_successDialogOpen) {
      _successDialogOpen = false;
      Navigator.of(context).pop(); // dismiss dialog; .then() will clean up controller
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LoggerPage(
          onSubmitted: _onCheckInSubmitted,
        ),
      ),
    );
  }

  void _onCheckInSubmitted(bool isOnTrack) {
    // Pop the LoggerPage and switch to home tab
    Navigator.of(context).pop();
    setState(() => _selectedIndex = 0);

    final partyMode = isOnTrack
        ? context.read<AppState>().settings.partyMode
        : false;

    if (isOnTrack) {
      _successConfettiController?.dispose();
      _successConfettiController = ConfettiController(
        duration: const Duration(seconds: 3),
      );
    }

    // Show dialog after home page renders; confetti widgets mount inside the dialog.
    _successDialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black26,
        builder: (ctx) => _buildSuccessDialog(ctx, isOnTrack, partyMode),
      ).then((_) {
        if (mounted) {
          _successDialogOpen = false;
          _successConfettiController?.dispose();
          _successConfettiController = null;
          setState(() {}); // clear any lingering party state
        }
      });
      // Play confetti after dialog widgets are mounted (one more frame)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _successConfettiController?.play();
      });
    });
  }

  Widget _buildSuccessDialog(BuildContext ctx, bool isOnTrack, bool partyMode) {
    return Stack(
      children: [
        // The dialog card in the center
        Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 56,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'You have submitted a response.',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please leave this tab open and continue with your work.',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('OK'),
                    ),
                  ),
                  if (PlatformService().canMinimize) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await PlatformService().minimizeApp();
                        },
                        child: const Text('Switch Away'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Party effects rendered above the dialog card
        if (isOnTrack && _successConfettiController != null)
          ..._buildSuccessConfettiWidgets(partyMode),
        if (isOnTrack && partyMode)
          const FloatingBalloons(isPlaying: true),
      ],
    );
  }

  List<Widget> _buildSuccessConfettiWidgets(bool partyMode) {
    if (_successConfettiController == null) return [];

    const normalColors = [
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.teal,
      Colors.white,
    ];
    const partyColors = [
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.teal,
      Colors.white,
      Colors.yellow,
      Colors.orange,
      Colors.pink,
      Colors.purple,
      Colors.blue,
      Colors.red,
      Colors.cyan,
    ];

    final colors = partyMode ? partyColors : normalColors;
    final particles = partyMode ? 180 : 30;
    final maxForce = partyMode ? 50.0 : 30.0;
    final minForce = partyMode ? 25.0 : 15.0;

    Widget confettiWidget(Alignment alignment, double direction) => Align(
      alignment: alignment,
      child: ConfettiWidget(
        confettiController: _successConfettiController!,
        blastDirection: direction,
        shouldLoop: false,
        colors: colors,
        numberOfParticles: particles,
        gravity: 0.15,
        emissionFrequency: 0.03,
        maxBlastForce: maxForce,
        minBlastForce: minForce,
      ),
    );

    if (partyMode) {
      return [
        confettiWidget(Alignment.bottomLeft, -pi / 4),
        confettiWidget(Alignment.bottomRight, -3 * pi / 4),
        confettiWidget(Alignment.topLeft, pi / 4),
        confettiWidget(Alignment.topRight, 3 * pi / 4),
        confettiWidget(Alignment.topCenter, pi / 2),
        confettiWidget(Alignment.bottomCenter, -pi / 2),
      ];
    } else {
      return [
        confettiWidget(Alignment.bottomLeft, -pi / 4),
        confettiWidget(Alignment.bottomRight, -3 * pi / 4),
      ];
    }
  }

  void _navigateToSettings(String? scrollTarget) {
    setState(() {
      _selectedIndex = 2;
      _scrollTarget = scrollTarget;
    });
  }

  void _navigateToStats(String? scrollTarget) {
    setState(() {
      _selectedIndex = 1;
      _scrollTarget = scrollTarget;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // Show tutorial on first launch
    if (!appState.isLoading && !appState.settings.hasSeenTutorial && !_tutorialShown) {
      _tutorialShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => TutorialDialog(
              onComplete: () {
                appState.markTutorialSeen();
                Navigator.of(context).pop();
              },
            ),
          );
        }
      });
    }

    // Handle notification tap - open check-in as a route
    if (appState.openedFromNotification) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openCheckIn();
        appState.clearNotificationFlag();
      });
    }

    // Show error snackbar when error occurs
    if (appState.errorMessage != null && appState.errorMessage != _lastShownError) {
      _lastShownError = appState.errorMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appState.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Theme.of(context).colorScheme.onError,
              onPressed: () {
                appState.clearError();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      });
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final useNavigationRail = screenWidth >= 1200;

    // Capture and clear scroll target for one-shot use
    final currentScrollTarget = _scrollTarget;
    if (_scrollTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _scrollTarget = null);
        }
      });
    }

    Widget page = switch (_selectedIndex) {
      0 => HomePage(
        onNavigateToSettings: _navigateToSettings,
        onNavigateToStats: _navigateToStats,
        onOpenCheckIn: _openCheckIn,
      ),
      1 => StatsPage(initialScrollTarget: currentScrollTarget),
      2 => SettingsPage(initialScrollTarget: currentScrollTarget),
      _ => throw UnimplementedError('no widget for $_selectedIndex'),
    };

    final fab = FloatingActionButton.extended(
      onPressed: _openCheckIn,
      elevation: Theme.of(context).brightness == Brightness.dark ? 8 : 6,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1B5E20)
          : null,
      foregroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : null,
      icon: const Icon(Icons.edit_note),
      label: const Text('Check In'),
    );

    if (useNavigationRail) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: true,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (value) => setState(() {
                _selectedIndex = value;
                _scrollTarget = null;
              }),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: fab,
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.area_chart_outlined),
                  selectedIcon: Icon(Icons.area_chart),
                  label: Text('Statistics'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                child: page,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Container(
        color: Theme.of(context).colorScheme.surface,
        child: page,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _selectedIndex != 0 ? fab : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) => setState(() {
          _selectedIndex = value;
          _scrollTarget = null;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.area_chart),
            label: 'Statistics',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
