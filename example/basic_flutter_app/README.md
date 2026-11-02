# Basic Flutter application

This is a runnable Flutter app: `lib/main.dart`, a notes feature, a widget test, Android, iOS, and web metadata, and `.flutterguard.yaml`.

From the repository root:

```bash
cd example/basic_flutter_app
flutter pub get
flutter analyze
flutter test
cd ../..
dart run bin/flutterguard.dart example/basic_flutter_app --offline
```

The annotated configuration for every field is [`../flutterguard.yaml`](../flutterguard.yaml). See [`../README.md`](../README.md).
