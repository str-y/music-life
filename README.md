# music-life

iOS/Android Music App

## Golden testing

Golden tests for major screens are in `test/screens`.

- Default test runs execute screen rendering assertions only.
- To run pixel-by-pixel golden comparisons (and generate/update baselines), use:

```bash
flutter test --dart-define=RUN_SCREEN_GOLDENS=true --update-goldens test/screens
```

- CI validates the checked-in screen baselines with the same
  `RUN_SCREEN_GOLDENS=true` flag during `flutter test`.

## Build flavors

The app supports isolated development, staging, and production entrypoints.
Android also defines matching native product flavors with separate app labels and
application ID suffixes.

- Any platform:
  - Development: `flutter run -t lib/main_dev.dart`
  - Staging: `flutter run -t lib/main_staging.dart`
  - Production: `flutter run -t lib/main_prod.dart`
- Android with native product flavors:
  - Development: `flutter run --flavor dev -t lib/main_dev.dart`
  - Staging: `flutter run --flavor staging -t lib/main_staging.dart`
  - Production: `flutter run --flavor prod -t lib/main_prod.dart`

Each flavor uses its own `AppConfig`, API base URL, Android app label, and
shared-preferences storage namespace so non-production builds do not reuse
production data on the same device.

For Android production builds, set `-PPROD_ADMOB_APPLICATION_ID=...` to supply
the real AdMob application ID instead of the non-production placeholder.
