import 'dart:io';

import 'package:flutterguard_audit/flutterguard_audit.dart';
import 'package:flutterguard_audit/src/toolchain/toolchain.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  if (!fixturesPresent) {
    test('fixture scans ship with the source repository', () {
      markTestSkipped(
        'test/fixtures is omitted from the pub package so fixture apps are not analyzed as this package.',
      );
    });
    return;
  }
  const toolchain = ToolchainInfo(
    dartVersion: '3.13.5',
    flutterVersion: '3.47.7',
  );
  final now = DateTime.utc(2026, 1, 2, 3, 4, 5);

  Future<ScanExecution> scan(Directory directory) {
    return const FlutterGuardScanner().scan(
      ScanRequest(
        rootPath: directory.path,
        now: now,
        toolchain: toolchain,
        offline: true,
      ),
    );
  }

  Set<String> rulesOf(ScanExecution execution) {
    return execution.report.findings.map((finding) => finding.ruleId).toSet();
  }

  test('clean fixture passes the quality gate with no findings', () async {
    final directory = tempFixture('clean_app');
    final before = checksums(directory);
    final execution = await scan(directory);
    expect(execution.exitCode, ExitCodes.success);
    expect(execution.report.findings, isEmpty, reason: _dump(execution));
    expect(execution.report.gate.passed, isTrue);
    expect(checksums(directory), before);
    expect(
      File(p.join(directory.path, 'build/flutterguard/report.json'))
          .existsSync(),
      isTrue,
    );
    expect(
      File(p.join(directory.path, 'build/flutterguard/index.html'))
          .existsSync(),
      isTrue,
    );
    expect(
      File(p.join(directory.path, 'build/flutterguard/report.md')).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(directory.path, 'build/flutterguard/report.sarif'))
          .existsSync(),
      isTrue,
    );
  });

  test(
    'simple fixture reports print, todo, and a hardcoded endpoint',
    () async {
      final execution = await scan(tempFixture('simple_flutter'));
      expect(execution.exitCode, ExitCodes.success);
      expect(
        rulesOf(execution),
        containsAll(['FG-QUAL-004', 'FG-QUAL-005', 'FG-CFG-001']),
      );
      final url = execution.report.findings.firstWhere(
        (finding) => finding.ruleId == 'FG-CFG-001',
      );
      expect(url.path, 'lib/main.dart');
      expect(url.line, isNotNull);
      expect(url.severity, Severity.medium);
    },
  );

  test('multi-flavor fixture reports branding mismatches', () async {
    final execution = await scan(tempFixture('multi_flavor'));
    expect(rulesOf(execution), containsAll(['FG-BRAND-003', 'FG-BRAND-005']));
  });

  test(
    'clean architecture fixture reports layer and database violations',
    () async {
      final execution = await scan(tempFixture('clean_architecture'));
      expect(rulesOf(execution), contains('FG-ARCH-001'));
      expect(rulesOf(execution), contains('FG-ARCH-004'));
      final layer = execution.report.findings.firstWhere(
        (finding) => finding.ruleId == 'FG-ARCH-001',
      );
      expect(layer.path, contains('home_page.dart'));
      expect(layer.heuristic, isFalse);
    },
  );

  test(
    'bloc and riverpod fixtures do not assume a state-management architecture',
    () async {
      final bloc = await scan(tempFixture('bloc_app'));
      expect(rulesOf(bloc), contains('FG-ARCH-002'));
      expect(rulesOf(bloc), isNot(contains('FG-ARCH-001')));
      final riverpod = await scan(tempFixture('riverpod_app'));
      expect(rulesOf(riverpod), isNot(contains('FG-ARCH-001')));
      expect(
        rulesOf(riverpod).where((id) => id.startsWith('FG-ARCH-')),
        isEmpty,
      );
    },
  );

  test('monorepo discovery scans both apps and duplicate ids', () async {
    final execution = await scan(tempFixture('monorepo'));
    final names = execution.report.projects
        .map((project) => project.project.name)
        .toSet();
    expect(names, containsAll(['alpha', 'beta']));
    expect(rulesOf(execution), contains('FG-CFG-003'));
    expect(execution.exitCode, ExitCodes.gateFailed);
    expect(rulesOf(execution), contains('FG-QUAL-005'));
  });

  test('security fixture redacts secrets and fails the gate', () async {
    const secret = 'AKIAIOSFODNN7EXAMPLE';
    const assigned = 'supersecretvalue123';
    final directory = tempFixture('security_app');
    final before = checksums(directory);
    final execution = await scan(directory);
    expect(checksums(directory), before);
    expect(execution.exitCode, ExitCodes.gateFailed);
    expect(
      rulesOf(execution),
      containsAll([
        'FG-SEC-001',
        'FG-SEC-002',
        'FG-SEC-003',
        'FG-SEC-004',
        'FG-SEC-005',
        'FG-SEC-006',
        'FG-SEC-007',
        'FG-CFG-004',
      ]),
    );
    final rendered = [
      renderTerminal(execution.report),
      renderJson(execution.report),
      renderMarkdown(execution.report),
      renderSarif(execution.report),
      File(p.join(directory.path, 'build/flutterguard/index.html'))
          .readAsStringSync(),
    ].join('\n');
    expect(rendered.contains(secret), isFalse);
    expect(rendered.contains(assigned), isFalse);
    expect(rendered.toLowerCase(), contains('redacted'));
    final security = execution.report.findings.firstWhere(
      (finding) => finding.ruleId == 'FG-SEC-001',
    );
    expect(security.heuristic, isTrue);
    expect(security.severity, Severity.critical);
  });

  test(
    'localization fixture reports catalog problems and hardcoded copy',
    () async {
      final execution = await scan(tempFixture('localization_app'));
      expect(
        rulesOf(execution),
        containsAll([
          'FG-L10N-001',
          'FG-L10N-002',
          'FG-L10N-003',
          'FG-L10N-004',
          'FG-L10N-005',
          'FG-L10N-006',
        ]),
      );
    },
  );

  test('feature coupling reports cross-feature internals', () async {
    final execution = await scan(tempFixture('feature_coupling'));
    expect(rulesOf(execution), contains('FG-ARCH-005'));
  });

  test('reports are deterministic aside from the injected timestamp', () async {
    final first = await scan(tempFixture('simple_flutter'));
    final second = await scan(tempFixture('simple_flutter'));
    expect(
      first.report.findings.map((finding) => finding.toJson()).toList(),
      second.report.findings.map((finding) => finding.toJson()).toList(),
    );
    final html = File(
      p.join(
        tempFixture('simple_flutter').path,
        'build/flutterguard/index.html',
      ),
    );
    final execution = await scan(html.parent.parent.parent);
    expect(execution.report.dartVersion, '3.13.5');
  });

  test('html report contains the required sections', () async {
    final directory = tempFixture('security_app');
    await scan(directory);
    final html = File(p.join(directory.path, 'build/flutterguard/index.html'))
        .readAsStringSync();
    for (final section in [
      'Project metadata',
      'Scan timestamp',
      'Severity distribution',
      'Category summaries',
      'Rule ID',
      'Recommendation',
      'New, existing, and resolved',
      'suppression',
      'Quality gate',
      'not proof of a vulnerability',
    ]) {
      expect(html.toLowerCase(), contains(section.toLowerCase()));
    }
    final sarif = File(
      p.join(directory.path, 'build/flutterguard/report.sarif'),
    ).readAsStringSync();
    expect(sarif, contains('"version": "2.1.0"'));
  });
}

String _dump(ScanExecution execution) {
  return execution.report.findings
      .map(
        (finding) =>
            '${finding.ruleId} ${finding.path}:${finding.line} ${finding.message}',
      )
      .join('\n');
}
