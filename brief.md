# NextClass — Project Brief

## What it is

NextClass is a Flutter app for university students to manage a weekly class timetable and quiz deadlines. It is designed for quick daily reference and local reminders, with a bold, high-contrast neo-brutalist interface. The repository also contains a static promotional website (`index.html`, `styles.css`, and `script.js`) and a standalone privacy-policy page.

## Main capabilities

- **Timetable setup:** Create a schedule manually or select/take a timetable photo. The app extracts classes, then opens a review flow to correct and save the results.
- **AI timetable parsing:** Compresses the selected image and sends it to Google Gemini through the `google_generative_ai` SDK. Parsed classes can include subject, weekday, start/end times, room, and instructor. Uncertain entries can be flagged for review. Scans are limited to 2 per day and 3 in a rolling 7-day window.
- **Today and Week views:** Browse today's classes and the weekly schedule, including class details and room/instructor information.
- **Quiz tracking:** Add, edit, complete, and delete quizzes associated with timetable classes. Upcoming quizzes are grouped by urgency (today, tomorrow, this week, and later); deletion supports undo.
- **Reminders:** Configure class reminder offsets and quiz reminders. Local notifications use device timezone handling and Android alarm support, with rescheduling on app startup and relevant changes.
- **Settings and privacy:** Manage reminder preferences, timetable display settings, scan quota, and view the in-app privacy policy. The app does not implement user accounts or cloud sync.
- **Connectivity awareness:** Displays offline status; schedule and quiz data are stored locally. AI photo parsing requires network access.

## Technology and structure

- **Client:** Flutter / Dart, package `nextclass`, version `1.0.0+1`; SDK constraint `^3.13.5`.
- **Platform code:** Android app (`com.nextclass.app`) with a small Kotlin method channel for the device timezone, plus notification receivers and Android notification resources. No iOS project is present in the checked-in file list.
- **State:** Provider-style `ChangeNotifier` classes in `lib/state/`.
- **Persistence:** SQLite via `sqflite`, with repositories in `lib/data/repositories/`. Main tables are classes, quizzes, settings, and scan quota. Quiz rows reference classes and cascade on class deletion; timetable replacement attempts to preserve and re-link existing quizzes.
- **Services:** `lib/services/timetable_parser_service.dart` handles image preprocessing, Gemini requests, JSON parsing, and scan history. `lib/domain/services/` contains local notifications, alarm scheduling, and connectivity handling.
- **UI:** `lib/ui/` is organized by onboarding, home, week, upload, review, quizzes, settings, and reusable shared components. App-wide colors and typography live in `lib/core/theme/`.
- **Website:** The root HTML/CSS/JS files form a separate marketing site; they are not the Flutter app entry point.

## Key entry points

- `lib/main.dart` — Flutter startup, theme, timezone initialization, and background notification setup.
- `lib/ui/main_navigation_screen.dart` — primary Today / Week / Quizzes navigation and screen coordination.
- `lib/data/database/app_database.dart` — SQLite schema and migrations.
- `lib/services/timetable_parser_service.dart` — timetable image parsing and scan limits.
- `lib/domain/services/notification_service.dart` — notification initialization and scheduling.
- `android/app/src/main/kotlin/com/nextclass/app/MainActivity.kt` — Android timezone method channel.

## Setup notes

- Install Flutter/Dart dependencies with `flutter pub get`.
- AI timetable parsing expects a Gemini API key at build/run time via `--dart-define=GEMINI_API_KEY=<key>`; the parser throws a configuration error if it is missing.
- Android release signing settings are read from the ignored `android/key.properties`; an example file is provided at `android/key.properties.example`.
- The app uses local storage and local notifications; there is no application backend or account system in this repository.

## Review note

The implementation sends a preprocessed timetable image to Google's Gemini API (`GenerativeModel.generateContent`). However, the in-app policy (`lib/ui/settings/privacy_policy_screen.dart`), standalone policy (`privacy_policy.html`), and marketing copy (`index.html`) say scanning runs entirely on-device/offline and that images are never uploaded. Those statements conflict with the code and should be reconciled before relying on or publishing those privacy claims. Also, the scan quota is enforced in client-side storage, not by a server.

## Tests

The repository contains 14 Flutter test files covering startup/widget behavior, parsing, persistence, screens/flows, notifications, offline behavior, shared components, and interaction/accessibility details. Tests were not run while preparing this brief.
