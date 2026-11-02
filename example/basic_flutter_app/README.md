# Basic Flutter application

This is a runnable Flutter app: `lib/main.dart`, a notes feature, a widget test, Android, iOS, and web metadata, and `flutterguard.yaml`. `flutter pub get` writes `pubspec.lock`. That file is not committed. A scan does not need it, and a cold pub cache would otherwise report a missing LICENSE file for a locked dependency.

From the repository root:

```bash
cd example/basic_flutter_app
flutter pub get
flutter analyze
flutter test
cd ../..
dart run bin/flutterguard.dart example/basic_flutter_app --offline --config example/basic_flutter_app/flutterguard.yaml
```

The annotated configuration for every field is [`../flutterguard.yaml`](../flutterguard.yaml). See [`../README.md`](../README.md).
