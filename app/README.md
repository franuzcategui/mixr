# Mixr App

Minimal Flutter app setup for the Mixr MVP.

## Environment

Supabase is configured via `--dart-define` at runtime:

```bash
flutter run \
  --dart-define=SUPABASE_URL=your_supabase_url \
  --dart-define=SUPABASE_ANON_KEY=your_supabase_anon_key
```

## Integration Tests

Edge Functions integration tests are skipped unless you provide the required
environment variables:

```bash
flutter test \
  --dart-define=SUPABASE_URL=your_supabase_url \
  --dart-define=SUPABASE_ANON_KEY=your_supabase_anon_key \
  --dart-define=SUPABASE_REFRESH_TOKEN=your_supabase_refresh_token \
  --dart-define=JOIN_EVENT_TOKEN=your_join_event_token \
  --dart-define=EVENT_ID=your_event_id \
  --dart-define=SWIPED_ID=your_swiped_user_id \
  --dart-define=SWIPE_DIRECTION=right
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
