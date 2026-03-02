import 'package:flutter/material.dart';

class TutorialDialog extends StatefulWidget {
  final VoidCallback onComplete;

  const TutorialDialog({super.key, required this.onComplete});

  @override
  State<TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<TutorialDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const _totalPages = 4;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 320,
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
                children: [
                  _buildPage(
                    icon: Icons.timer_outlined,
                    title: 'Welcome to\nScreen Time Checkup',
                    body:
                        'This app helps you stay honest about how you spend your time.\n\n'
                        'You set a session intention, then get periodic check-ins '
                        'asking what you\'re actually doing.\n\n'
                        'Over time you\'ll see patterns — and close the gap between '
                        'what you intend to do and what you end up doing.',
                  ),
                  _buildPage(
                    icon: Icons.category_outlined,
                    title: 'Two Kinds of Activities',
                    body:
                        'Your activities are split into two groups:\n\n'
                        'Focus Activities \u2014 the productive things you want '
                        'to be doing (work, study, exercise...)\n\n'
                        'Distractions \u2014 the things that pull you off track '
                        '(social media, aimless browsing...)\n\n'
                        'You can customise both lists in Settings.',
                  ),
                  _buildPage(
                    icon: Icons.flag_outlined,
                    title: 'Session Intentions',
                    body:
                        'Before you start working, set an intention \u2014 a short '
                        'description of what you want to accomplish.\n\n'
                        'Each check-in asks whether what you\'re doing matches that '
                        'intention. After a while, you\'ll be prompted to confirm '
                        'you\'re still on the same task or switch to a new one.\n\n'
                        'You can set your intention any time from the home screen.',
                  ),
                  _buildPage(
                    icon: Icons.edit_note,
                    title: 'How Check-Ins Work',
                    body:
                        'When a check-in fires, you\'ll log:\n\n'
                        '1. What you\'re doing right now\n'
                        '2. What you should be doing\n'
                        '3. How well you\'re sticking to your intention\n\n'
                        'Quick presets let you answer in one tap for your most '
                        'common combinations. The app tracks your on-track rate '
                        'and shows trends in the Stats tab.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _totalPages,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _currentPage
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _currentPage < _totalPages - 1
                    ? () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        )
                    : widget.onComplete,
                child: Text(
                    _currentPage < _totalPages - 1 ? 'Next' : 'Get Started'),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildPage({
    required IconData icon,
    required String title,
    required String body,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        children: [
          Icon(icon, size: 48, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
