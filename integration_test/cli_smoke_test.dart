import 'dart:io';

import 'package:test/test.dart';

void main() {
  final dart = Platform.resolvedExecutable;

  Future<ProcessResult> run(List<String> args, {String? workingDirectory}) {
    return Process.run(
      dart,
      ['run', 'bin/flutterguard.dart', ...args],
      workingDirectory: workingDirectory ?? Directory.current.path,
      stdoutEncoding: systemEncoding,
      stderrEncoding: systemEncoding,
    );
  }

  test('executable help and version', () async {
    final help = await run(['--help']);
    expect(help.exitCode, 0);
    expect(help.stdout, contains('flutterguard'));
    final version = await run(['--version']);
    expect(version.exitCode, 0);
    expect(version.stdout, contains('0.1.2'));
  });

  test(
    'executable scans the clean fixture and fails closed on bad config',
    () async {
      if (!Directory('test/fixtures/clean_app').existsSync()) {
        markTestSkipped(
          'test/fixtures is omitted from the pub package so fixture apps are not analyzed as this package.',
        );
        return;
      }
      final clean = await run(['test/fixtures/clean_app', '--offline']);
      expect(clean.exitCode, 0, reason: '${clean.stdout}\n${clean.stderr}');
      expect(clean.stdout, contains('Quality gate: passed'));
      final bad = await run(['test/fixtures/malformed_config']);
      expect(bad.exitCode, 2);
      expect(bad.stderr, contains('version'));
      final security = await run(['test/fixtures/security_app', '--offline']);
      expect(security.exitCode, 1);
      expect(security.stdout, contains('Quality gate: failed'));
      expect(security.stdout.contains('AKIAIOSFODNN7EXAMPLE'), isFalse);
      expect(security.stdout.contains('supersecretvalue123'), isFalse);
    },
    // Each invocation compiles the CLI with `dart run`. Three scans exceed
    // the default 30 second test timeout on GitHub-hosted runners.
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
