import 'dart:convert';
import 'dart:io';

final class ToolchainInfo {
  const ToolchainInfo({
    required this.dartVersion,
    required this.flutterVersion,
  });

  final String dartVersion;
  final String? flutterVersion;

  static const unknown = ToolchainInfo(
    dartVersion: 'unknown',
    flutterVersion: null,
  );
}

final class ToolchainProbe {
  const ToolchainProbe();

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
