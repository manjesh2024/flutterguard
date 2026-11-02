import 'dart:convert';
import 'dart:io';

/// Dart and Flutter versions detected for a scan.
final class ToolchainInfo {
  /// Stores [dartVersion] and an optional [flutterVersion].
  const ToolchainInfo({
    required this.dartVersion,
    required this.flutterVersion,
  });

  /// Dart SDK version, or `unknown` when `dart --version` could not be read.
  final String dartVersion;

  /// Flutter framework version, or null when Flutter was not found.
  final String? flutterVersion;

  /// Placeholder used when neither toolchain version was read.
  ///
  /// [dartVersion] is `unknown` and [flutterVersion] is null.
  static const unknown = ToolchainInfo(
    dartVersion: 'unknown',
    flutterVersion: null,
  );
}

/// Runs `dart --version` and `flutter --version --machine`.
final class ToolchainProbe {
  /// Creates a probe with no retained state.
  const ToolchainProbe();

  /// Returns versions from the `dart` and `flutter` executables on `PATH`.
  ///
  /// Dart output is parsed for `Dart SDK version:`. If that pattern is
  /// missing, the trimmed combined stdout and stderr is used, or `unknown`
  /// when the text is empty or the process cannot start. Flutter prefers
  /// `frameworkVersion` from the machine JSON. When that JSON decodes but has
  /// no string `frameworkVersion`, the first output line is used. A missing
  /// executable, empty output, or invalid JSON yields a null Flutter version.
  /// Those failures are not thrown.
  Future<ToolchainInfo> detect() async {
    final dartVersion = await _dart();
    final flutterVersion = await _flutter();
    return ToolchainInfo(
      dartVersion: dartVersion,
      flutterVersion: flutterVersion,
    );
  }

  Future<String> _dart() async {
    try {
      final result = await Process.run('dart', ['--version']);
      final text = '${result.stdout}${result.stderr}'.trim();
      final match = RegExp(r'Dart SDK version:\s*([^\s]+)').firstMatch(text);
      return match?.group(1) ?? (text.isEmpty ? 'unknown' : text);
    } on ProcessException {
      return 'unknown';
    }
  }

  Future<String?> _flutter() async {
    try {
      final result = await Process.run('flutter', ['--version', '--machine']);
      final text = '${result.stdout}'.trim();
      if (text.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(text);
      if (decoded is Map && decoded['frameworkVersion'] is String) {
        return decoded['frameworkVersion'] as String;
      }
      return text.split('\n').first;
    } on ProcessException {
      return null;
    } on FormatException {
      return null;
    }
  }
}
