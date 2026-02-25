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
  static const _totalPages = 3;

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
                        'This app helps you stay aware of how you spend your time.\n\n'
                        'You\'ll get periodic notifications asking you to check in '
                        'on what you\'re doing.',
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
                        'You can customize both lists in Settings.',
                  ),
                  _buildPage(
                    icon: Icons.edit_note,
                    title: 'How Check-Ins Work',
                    body:
                        'When you check in, you\'ll answer:\n\n'
                        '1. What are you doing?\n'
                        '    (any activity)\n\n'
                        '2. What should you be doing?\n'
                        '    (focus activities only)\n\n'
                        'The app tracks whether you\'re on track and shows you '
                        'patterns over time.',
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
