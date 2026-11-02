import 'package:flutterguard_audit/flutterguard_audit.dart';
import 'package:flutterguard_audit/src/toolchain/toolchain.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

void main() {
  test('a temp directory reached through /var is still scanned', () async {
    if (!fixturesPresent) {
      markTestSkipped(
        'test/fixtures is omitted from the pub package so fixture apps are not analyzed as this package.',
      );
      return;
    }
    final directory = tempFixture('clean_app');
    final execution = await const FlutterGuardScanner().scan(
      ScanRequest(
        rootPath: directory.path,
        offline: true,
        writeReports: false,
        toolchain: const ToolchainInfo(
          dartVersion: '3.13.5',
          flutterVersion: '3.47.7',
        ),
        now: DateTime.utc(2026, 1, 2, 3, 4, 5),
      ),
    );
    final escaped = execution.report.findings.where(
      (finding) => finding.ruleId == 'FG-SEC-008',
    );
    expect(escaped, isEmpty);
    expect(execution.report.projects, isNotEmpty);
  });
}
