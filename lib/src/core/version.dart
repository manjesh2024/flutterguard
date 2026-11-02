/// Published package version. Keep this aligned with `pubspec.yaml`.
const String packageVersion = '0.1.2';

/// User-facing product name.
const String toolName = 'FlutterGuard';

/// pub.dev package name.
const String packageName = 'flutterguard_audit';

/// Terminal executable name. This stays stable if the package slug changes.
const String executableName = 'flutterguard';

/// Integer `version` accepted in `.flutterguard.yaml`.
///
/// Any other value is a configuration error. FlutterGuard does not migrate
/// an older or newer schema.
const int configSchemaVersion = 1;

/// Integer `schemaVersion` written into `report.json`.
const int reportSchemaVersion = 1;

/// Integer `schemaVersion` written into baseline JSON files.
const int baselineSchemaVersion = 1;

/// Process exit codes used by every command.
///
/// `success` means the quality gate passed or a non-scan command finished.
/// `gateFailed` means the scan finished and the gate did not pass.
/// `usage` means the invocation, discovery, or configuration was refused.
/// `failure` means an unexpected local error stopped the command.
abstract final class ExitCodes {
  /// The quality gate passed, or the command completed without a scan.
  static const int success = 0;

  /// The scan finished and at least one quality-gate condition failed.
  static const int gateFailed = 1;

  /// The arguments, project discovery, or configuration file were rejected.
  static const int usage = 2;

  /// An unexpected local failure stopped the command before a normal result.
  static const int failure = 3;
}
