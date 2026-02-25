# Screen Time Checkup

A Flutter PWA that nudges you to reflect on how you're spending your screen time. Periodic notifications ask what you're doing and whether it aligns with your goals. Over time, your check-in history becomes a clear picture of where your attention actually goes.

## Features

- **Periodic check-in notifications** — set an interval (e.g. every 30 minutes) or pick specific times of day
- **Snooze from the notification** — tap "Snooze 5 min" or "Snooze 15 min" directly on the notification without opening the app
- **Adaptive notification messages** — 13 different prompts, weighted by your response time so the ones that work best for you appear more often
- **On-Track Trend chart** — browse daily, weekly, and monthly bar charts showing your on-track percentage over time
- **Key Statistics** — donut chart, streak counter, response rate, most common distraction, and most/least productive hour
- **Goal follow-through** — see how consistently you stay on track for each of your goals
- **Check-in history** — full log of every entry with tags, notes, and on-track status
- **Customisable layout** — hide or reorder the stats sections to suit your workflow
- **PWA** — installable on Android (Chrome) and iOS (Safari → Add to Home Screen)

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.x or later
- Chrome (for web development)

### Run locally

```bash
cd screen_time_checkup
flutter pub get
flutter run -d chrome
```

### Build for production

```bash
flutter build web --base-href /your-repo-name/
```

The output in `build/web/` is a self-contained static site ready for GitHub Pages or any static host.

## Project Structure

```
lib/
  models/         # AppSettings, LogEntry, NotificationMessage
  pages/          # home_page, logger_page, stats_page, settings_page
  providers/      # AppState (Provider — all business logic and computed stats)
  services/       # Notification + platform services (web/mobile split via conditional imports)
  widgets/        # Reusable chart and card widgets
web/
  sw.js           # Custom service worker (wraps Flutter's generated SW + adds notification actions)
  index.html
  manifest.json
test/             # Unit tests
integration_test/ # Integration tests
```

## Adding Notification Messages

Open `lib/models/notification_message.dart` and add an entry to the `all` list:

```dart
NotificationMessage(
  id: 'my_message',       // unique snake_case string
  title: 'Your title',
  body: 'Your body text.',
),
```

New messages start with a weight of 1.0. The app will up-weight them automatically if users respond quickly.

## Architecture Notes

- State management: `Provider` via `AppState`
- Storage: `shared_preferences` (all data is local, nothing leaves the device)
- Notifications on web: browser Notification API, shown via service worker so snooze action buttons work
- Notifications on mobile: `flutter_local_notifications` via a `MethodChannel`
- Platform-specific code uses Dart's conditional imports (`if (dart.library.io) '..._mobile.dart'`)
