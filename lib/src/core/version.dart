/// Published package version. Keep this aligned with `pubspec.yaml`.
const String packageVersion = '0.1.0';

/// User-facing product name.
const String toolName = 'FlutterGuard';

/// pub.dev package name.
const String packageName = 'flutterguard_audit';

/// Terminal executable name. This stays stable if the package slug changes.
const String executableName = 'flutterguard';

const int configSchemaVersion = 1;
const int reportSchemaVersion = 1;
const int baselineSchemaVersion = 1;

/// Process exit codes used by every command.
abstract final class ExitCodes {
  static const int success = 0;
  static const int gateFailed = 1;
  static const int usage = 2;
  static const int failure = 3;
}
