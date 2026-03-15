# music-life

iOS/Android Music App

## API documentation

API documentation is generated automatically with `dart doc` in GitHub Actions
and published to GitHub Pages alongside the project's static documentation.

- Published docs landing page: `docs/index.html` in the Pages artifact
- Local generation command:

```bash
dart doc --output docs/api
```

## Golden testing

Golden tests for major screens are in `test/screens`.

- Default test runs execute screen rendering assertions only.
- To run pixel-by-pixel golden comparisons (and generate/update baselines), use:

```bash
flutter test --dart-define=RUN_SCREEN_GOLDENS=true --update-goldens test/screens
```

- CI validates the checked-in screen baselines with the same
  `RUN_SCREEN_GOLDENS=true` flag during `flutter test`.
