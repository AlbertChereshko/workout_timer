# Project Overview
Flutter workout timer application (Tabata, EMOM, AMRAP, HIIT, intervals).

# Architecture & Tech Stack
- Framework: Flutter / Dart (Material 3)
- State Management: flutter_riverpod (using riverpod_annotation & code generation)
- Navigation: go_router
- Storage: hive_flutter (local DB for workouts/history), shared_preferences (app settings)
- Backend & Auth: Firebase (core, auth, cloud_firestore), google_sign_in
- Audio & Feedback: audioplayers, flutter_tts, vibration
- Device & System: wakelock_plus (keep screen on during timers), flutter_local_notifications, home_widget
- AI Integration: google_generative_ai

# Build & Run Commands
- Codegen: `dart run build_runner build --delete-conflicting-outputs`
- Clean: `flutter clean && flutter pub get`
- Analyze: `flutter analyze`
- Tests: `flutter test`
- Run: `flutter run`

# Working Rules for Assistant
- Do NOT rewrite whole files if changing < 10 lines; provide targeted, minimal diffs.
- Use Riverpod code generation syntax (`@riverpod`) instead of manual StateNotifierProvider where applicable.
- Keep UI widgets pure and lightweight; business and timer logic belongs inside Riverpod providers.
- Handle active timer ticks and lifecycle carefully (pause/resume with app lifecycle via WidgetsBindingObserver).
- Never inspect `build/`, `.dart_tool/`, `android/`, `ios/` folders unless explicitly requested.
- Do not read binary files (`.wav`, `.mp3`, `.png`, `.jpg`).
