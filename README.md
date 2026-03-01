# music-life

iOS/Android Music App

## Golden testing

Golden tests for major screens are in `test/screens`.

- Default test runs execute screen rendering assertions only.
- To run pixel-by-pixel golden comparisons (and generate/update baselines), use:

```bash
flutter test --dart-define=RUN_SCREEN_GOLDENS=true --update-goldens test/screens
```
