import 'version.dart';

/// Base type for failures that map to a stable process exit code.
sealed class FlutterGuardException implements Exception {
  FlutterGuardException(this.message);

  final String message;

  int get exitCode;

  @override
  String toString() => message;
}

/// The configuration file exists but cannot be used safely.
final class ConfigException extends FlutterGuardException {
  ConfigException(super.message);

  @override
  int get exitCode => ExitCodes.usage;
}

/// The invocation itself is invalid.
final class UsageException extends FlutterGuardException {
  UsageException(super.message);

  @override
  int get exitCode => ExitCodes.usage;
}

/// No usable Flutter project was found, or discovery was refused.
final class DiscoveryException extends FlutterGuardException {
  DiscoveryException(super.message);

  @override
  int get exitCode => ExitCodes.usage;
}

/// The scan could not finish because of an unexpected local failure.
final class ScanException extends FlutterGuardException {
  ScanException(super.message);

  @override
  int get exitCode => ExitCodes.failure;
}
