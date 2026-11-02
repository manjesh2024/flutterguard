import 'dart:io';

import 'package:flutterguard_audit/flutterguard_audit.dart';
import 'package:flutterguard_audit/src/discovery/discovery.dart';
import 'package:flutterguard_audit/src/toolchain/toolchain.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  const toolchain = ToolchainInfo(
    dartVersion: '3.13.5',
    flutterVersion: '3.47.7',
  );

  test('published configs match the hidden configs', () {
    for (final name in [
      'basic_flutter_app',
      'advanced_monorepo',
      'intentional_findings',
    ]) {
      final hidden = File('example/$name/.flutterguard.yaml')
          .readAsStringSync();
      final visible = File('example/$name/flutterguard.yaml')
          .readAsStringSync();
      expect(visible, hidden, reason: name);
    }
  });

  test('monorepo discovery finds the workspace packages', () {
    final root = Directory('example/advanced_monorepo').absolute.path;
    final config = loadConfig(rootPath: root);
    final projects = const ProjectDiscovery().discover(
      rootPath: root,
      config: config,
    );
    expect(projects.map((project) => project.name).toList(), [
      'admin_app',
      'shop_app',
      'shared_ui',
    ]);
  });

  test('basic example scan does not modify source', () async {
    final root = Directory('example/basic_flutter_app');
    final before = _checksums(root);
    final execution = await const FlutterGuardScanner().scan(
      ScanRequest(
        rootPath: root.path,
        offline: true,
        writeReports: false,
        now: DateTime.utc(2026, 11, 2),
        toolchain: toolchain,
      ),
    );
    expect(_checksums(root), before);
    expect(execution.exitCode, ExitCodes.success, reason: _dump(execution));
    expect(execution.report.findings, isEmpty, reason: _dump(execution));
  });

  test('intentional example reports the documented rules', () async {
    final root = Directory('example/intentional_findings');
    final before = _checksums(root);
    final execution = await const FlutterGuardScanner().scan(
      ScanRequest(
        rootPath: root.path,
        offline: true,
        writeReports: false,
        now: DateTime.utc(2026, 11, 2),
        toolchain: toolchain,
      ),
    );
    expect(_checksums(root), before);
    expect(execution.exitCode, ExitCodes.gateFailed);
    final rules = execution.report.findings.map((finding) => finding.ruleId);
    expect(
      rules,
      containsAll(const [
        'FG-BRAND-001',
        'FG-BRAND-002',
        'FG-BRAND-003',
        'FG-CFG-001',
        'FG-CFG-004',
        'FG-CFG-005',
        'FG-CFG-006',
        'FG-ARCH-001',
        'FG-QUAL-005',
        'FG-QUAL-006',
        'FG-QUAL-008',
        'FG-SEC-001',
        'FG-SEC-002',
        'FG-SEC-004',
        'FG-SEC-007',
        'FG-L10N-001',
        'FG-L10N-002',
        'FG-L10N-006',
        'FG-DEP-001',
        'FG-PLAT-001',
        'FG-PLAT-002',
      ]),
    );
    expect(rules, isNot(contains('FG-QUAL-004')));
    expect(
      execution.report.suppressed.map((item) => item.finding.ruleId),
      contains('FG-QUAL-004'),
    );
    expect(
      execution.report.findings.map((finding) => finding.path),
      isNot(contains('lib/generated/skipped.dart')),
    );
  });

  test('monorepo scan ignores the generated shop file', () async {
    final execution = await const FlutterGuardScanner().scan(
      ScanRequest(
        rootPath: Directory('example/advanced_monorepo').path,
        offline: true,
        writeReports: false,
        now: DateTime.utc(2026, 11, 2),
        toolchain: toolchain,
      ),
    );
    expect(
      execution.report.projects.map((project) => project.project.name).toList(),
      ['admin_app', 'shop_app', 'shared_ui'],
    );
    expect(
      execution.report.findings.map((finding) => finding.path).join('\n'),
      isNot(contains('generated/skipped.dart')),
    );
  });

  test('library API example runs', () async {
    final directory = Directory('example/library_api');
    final pubGet = await Process.run(Platform.resolvedExecutable, [
      'pub',
      'get',
    ], workingDirectory: directory.path);
    expect(pubGet.exitCode, 0, reason: '${pubGet.stdout}\n${pubGet.stderr}');
    final analyze = await Process.run(Platform.resolvedExecutable, [
      'analyze',
      '--fatal-infos',
    ], workingDirectory: directory.path);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
    final run = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/main.dart',
    ], workingDirectory: directory.path);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect(run.stdout, contains('ConfigException'));
    expect(run.stdout, contains('FG-BRAND-003'));
  });
}

Map<String, String> _checksums(Directory root) {
  final files = <String, String>{};
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final relative = p.relative(entity.path, from: root.path);
    if (relative.startsWith('build') ||
        relative.contains('${p.separator}build${p.separator}') ||
        relative.contains('.dart_tool')) {
      continue;
    }
    files[relative] = entity.readAsBytesSync().join(',');
  }
  return files;
}

String _dump(ScanExecution execution) {
  return execution.report.findings
      .map(
        (finding) =>
            '${finding.ruleId} ${finding.path}:${finding.line} ${finding.message}',
      )
      .join('\n');
}
