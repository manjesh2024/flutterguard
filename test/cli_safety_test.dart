import 'dart:io';

import 'package:flutterguard_audit/flutterguard_audit.dart';
import 'package:flutterguard_audit/src/toolchain/toolchain.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  if (!fixturesPresent) {
    test('fixture CLI checks ship with the source repository', () {
      markTestSkipped(
        'test/fixtures is omitted from the pub package so fixture apps are not analyzed as this package.',
      );
    });
    return;
  }
  test(
    'malformed configuration returns exit code 2 and does not scan',
    () async {
      final directory = tempFixture('malformed_config');
      final cli = BufferCli();
      final code = await FlutterGuardCli(ioSink: cli).run([directory.path]);
      expect(code, ExitCodes.usage);
      expect(cli.err.toString(), contains('version'));
      expect(Directory(p.join(directory.path, 'build')).existsSync(), isFalse);
    },
  );

  test('help and unknown commands use stable exit codes', () async {
    final help = BufferCli();
    expect(
      await FlutterGuardCli(ioSink: help).run(['--help']),
      ExitCodes.success,
    );
    expect(help.out.toString(), contains('flutterguard'));
    final version = BufferCli();
    expect(
      await FlutterGuardCli(ioSink: version).run(['--version']),
      ExitCodes.success,
    );
    expect(version.out.toString(), contains(packageVersion));
    final rules = BufferCli();
    expect(
      await FlutterGuardCli(ioSink: rules).run(['rules', 'list']),
      ExitCodes.success,
    );
    expect(rules.out.toString(), contains('FG-ARCH-001'));
    final explain = BufferCli();
    expect(
      await FlutterGuardCli(ioSink: explain)
          .run(['rules', 'explain', 'FG-ARCH-001']),
      ExitCodes.success,
    );
    expect(explain.out.toString(), contains('Layer dependency'));
    final unknown = BufferCli();
    expect(
      await FlutterGuardCli(ioSink: unknown)
          .run(['rules', 'explain', 'FG-NOPE']),
      ExitCodes.usage,
    );
    final bad = BufferCli();
    expect(await FlutterGuardCli(ioSink: bad).run(['nope']), ExitCodes.usage);
  });

  test('doctor and init succeed', () async {
    final directory = tempFixture('clean_app');
    final doctor = BufferCli();
    expect(
      await FlutterGuardCli(ioSink: doctor)
          .run(['doctor', '--path', directory.path]),
      ExitCodes.success,
    );
    expect(doctor.out.toString(), contains('clean_app'));
    final init = BufferCli();
    expect(
      await FlutterGuardCli(ioSink: init)
          .run(['init', '--path', directory.path]),
      ExitCodes.success,
    );
    expect(
      File(p.join(directory.path, '.flutterguard.yaml')).existsSync(),
      isTrue,
    );
    final again = BufferCli();
    expect(
      await FlutterGuardCli(ioSink: again)
          .run(['init', '--path', directory.path]),
      ExitCodes.usage,
    );
  });

  test('baseline create, compare, and suppression', () async {
    final directory = tempFixture('simple_flutter');
    final create = BufferCli();
    expect(
      await FlutterGuardCli(ioSink: create)
          .run(['baseline', 'create', '--path', directory.path]),
      ExitCodes.success,
    );
    final config = File(p.join(directory.path, '.flutterguard.yaml'));
    config.writeAsStringSync('''
version: 1
baseline:
  enabled: true
  path: .flutterguard-baseline.json
suppressions:
  - rule: FG-QUAL-005
    path: "lib/main.dart"
    reason: "Sample output is intentional."
''');
    final execution = await const FlutterGuardScanner().scan(
      ScanRequest(
        rootPath: directory.path,
        toolchain: const ToolchainInfo(
          dartVersion: '3.13.5',
          flutterVersion: null,
        ),
        offline: true,
        writeReports: true,
      ),
    );
    expect(execution.report.suppressed, isNotEmpty);
    expect(
      execution.report.findings.map((finding) => finding.ruleId),
      isNot(contains('FG-QUAL-005')),
    );
    expect(execution.report.baseline.enabled, isTrue);
    final html = File(p.join(directory.path, 'build/flutterguard/index.html'))
        .readAsStringSync();
    expect(html, contains('Sample output is intentional.'));
  });

  test('auto-fix dry-run, apply, and revert', () async {
    final directory = tempFixture('auto_fix');
    final source = File(p.join(directory.path, 'lib/main.dart'));
    final original = source.readAsStringSync();
    final dry = BufferCli();
    expect(
      await FlutterGuardCli(ioSink: dry)
          .run(['fix', '--dry-run', '--path', directory.path]),
      ExitCodes.success,
    );
    expect(dry.out.toString(), contains('Dry run'));
    expect(source.readAsStringSync(), original);
    final apply = BufferCli();
    expect(
      await FlutterGuardCli(ioSink: apply)
          .run(['fix', '--path', directory.path]),
      ExitCodes.success,
    );
    expect(source.readAsStringSync(), isNot(contains("import 'dart:core'")));
    expect(source.readAsStringSync(), isNot(contains('dart:async')));
    expect(
      Directory(p.join(directory.path, '.flutterguard', 'backups'))
          .existsSync(),
      isTrue,
    );
    final revert = BufferCli();
    expect(
      await FlutterGuardCli(ioSink: revert)
          .run(['fix', '--revert', '--path', directory.path]),
      ExitCodes.success,
    );
    expect(source.readAsStringSync(), original);
  });

  test('symlink that leaves the project is not read', () async {
    final directory = tempFixture('clean_app');
    final outside = Directory.systemTemp.createTempSync('flutterguard_outside');
    File(p.join(outside.path, 'secret.txt'))
        .writeAsStringSync('AKIAIOSFODNN7EXAMPLE');
    try {
      Link(p.join(directory.path, 'lib', 'escaped.txt'))
          .createSync(p.join(outside.path, 'secret.txt'));
    } on FileSystemException catch (error) {
      markTestSkipped('This environment cannot create symlinks: $error');
      return;
    }
    final execution = await const FlutterGuardScanner().scan(
      ScanRequest(
        rootPath: directory.path,
        toolchain: const ToolchainInfo(
          dartVersion: '3.13.5',
          flutterVersion: null,
        ),
        offline: true,
        writeReports: true,
      ),
    );
    final rendered = File(
      p.join(directory.path, 'build/flutterguard/report.json'),
    ).readAsStringSync();
    expect(rendered.contains('AKIAIOSFODNN7EXAMPLE'), isFalse);
    expect(
      execution.report.findings.map((finding) => finding.ruleId),
      contains('FG-SEC-008'),
    );
  });

  test('inline suppression requires a reason', () async {
    final directory = tempFixture('simple_flutter');
    final file = File(p.join(directory.path, 'lib/main.dart'));
    file.writeAsStringSync(
      file.readAsStringSync().replaceFirst(
        'print(',
        '// flutterguard:ignore FG-QUAL-005\nprint(',
      ),
    );
    final execution = await const FlutterGuardScanner().scan(
      ScanRequest(
        rootPath: directory.path,
        toolchain: const ToolchainInfo(
          dartVersion: '3.13.5',
          flutterVersion: null,
        ),
        offline: true,
        writeReports: false,
      ),
    );
    expect(
      execution.report.findings.map((finding) => finding.ruleId),
      contains('FG-SUP-001'),
    );
    expect(
      execution.report.findings.map((finding) => finding.ruleId),
      contains('FG-QUAL-005'),
    );
  });
}
