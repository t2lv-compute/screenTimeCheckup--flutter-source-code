class NotificationMessage {
  final String id;
  final String title;
  final String body;

  const NotificationMessage({
    required this.id,
    required this.title,
    required this.body,
  });

  static const List<NotificationMessage> all = [
    NotificationMessage(
      id: 'classic',
      title: 'Time to check in!',
      body: 'What are you doing right now?',
    ),
    NotificationMessage(
      id: 'intermission',
      title: 'And now, a brief intermission',
      body: 'Brought to you by your productivity goals. Are we going back to the show, or changing the channel?',
    ),
    NotificationMessage(
      id: 'goal',
      title: "How's your focus?",
      body: 'Are you working on what you planned?',
    ),
    NotificationMessage(
      id: 'quick',
      title: 'Quick check!',
      body: 'On track with your goal?',
    ),
    NotificationMessage(
      id: 'reflect',
      title: 'Moment of reflection',
      body: 'Is this the best use of your time right now?',
    ),
    NotificationMessage(
      id: 'awareness',
      title: 'Screen time check',
      body: 'What has your attention right now?',
    ),
    NotificationMessage(
      id: 'accountability',
      title: 'Check in now',
      body: 'What should you be doing right now?',
    ),
    NotificationMessage(
      id: 'intentional',
      title: 'Intentional break?',
      body: 'Is this intentional, or are you drifting?',
    ),
    NotificationMessage(
      id: 'honest',
      title: 'Honest check-in',
      body: 'Would you be happy if someone saw your screen right now?',
    ),
    NotificationMessage(
      id: 'sponsored_by',
      title: 'Today is NOT sponsored by...',
      body: '...the app you’re currently in. Are we doing the thing or just visiting?',
    ),
    NotificationMessage(
      id: 'simple_ping',
      title: 'Ping!',
      body: 'Just a quick check-in. What are you up to?',
    ),
    NotificationMessage(
      id: 'intentionality',
      title: 'Checking Intention',
      body: 'Did you mean to spend your time this way?',
    ),
    NotificationMessage(
      id: 'progress_update',
      title: 'Status Update',
      body: 'Are you still working on your last logged activity?',
    ),
  ];
}
