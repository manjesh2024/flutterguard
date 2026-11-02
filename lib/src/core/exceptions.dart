import 'version.dart';

/// Base type for failures that map to a stable process exit code.
///
/// Callers catch this type when they want the message and [exitCode]
/// without treating the failure as an unexpected crash. The [message] is
/// safe to print; it does not include secret values collected by a scan.
///
/// ```dart
/// try {
///   loadConfig(rootPath: root);
/// } on FlutterGuardException catch (error) {
///   stderr.writeln(error.message);
///   exitCode = error.exitCode;
/// }
/// ```
sealed class FlutterGuardException implements Exception {
  /// Stores [message] as the text returned by [toString].
  FlutterGuardException(this.message);

  /// Actionable explanation of why the command stopped.
  final String message;

  /// Process status for this failure.
  ///
  /// Configuration, usage, and discovery failures use [ExitCodes.usage].
  /// Unexpected local failures use [ExitCodes.failure].
  int get exitCode;

  /// Returns [message] with no exception type prefix.
  @override
  String toString() => message;
}

/// The configuration file exists but cannot be used safely.
///
/// Thrown for malformed YAML, unknown keys, an unsupported schema version,
/// and paths that escape the project. A missing default `.flutterguard.yaml`
/// is not this error; that case uses built-in defaults.
final class ConfigException extends FlutterGuardException {
  /// Creates a configuration failure whose text is [message].
  ConfigException(super.message);

  /// Always [ExitCodes.usage].
  @override
  int get exitCode => ExitCodes.usage;
}

/// The invocation itself is invalid.
///
/// Thrown for an unknown command, a missing required argument, or a request
/// that would replace an existing file without `--force`.
final class UsageException extends FlutterGuardException {
  /// Creates a usage failure whose text is [message].
  UsageException(super.message);

  /// Always [ExitCodes.usage].
  @override
  int get exitCode => ExitCodes.usage;
}

/// No usable Flutter project was found, or discovery was refused.
///
/// Thrown when `single` mode is pointed at a directory that is not a Flutter
/// project, or when `monorepo` mode finds nothing to scan.
final class DiscoveryException extends FlutterGuardException {
  /// Creates a discovery failure whose text is [message].
  DiscoveryException(super.message);

  /// Always [ExitCodes.usage].
  @override
  int get exitCode => ExitCodes.usage;
}

/// The scan could not finish because of an unexpected local failure.
///
/// This is not used for a quality-gate failure. A finished scan that fails
/// the gate returns [ExitCodes.gateFailed] without throwing.
final class ScanException extends FlutterGuardException {
  /// Creates a runtime failure whose text is [message].
  ScanException(super.message);

  /// Always [ExitCodes.failure].
  @override
  int get exitCode => ExitCodes.failure;
}
