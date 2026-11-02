import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:flutterguard_audit/flutterguard_audit.dart';
import 'package:flutterguard_audit/src/analyzer/complexity.dart';
import 'package:flutterguard_audit/src/analyzer/pubspec_reader.dart';
import 'package:flutterguard_audit/src/core/safe_path.dart';
import 'package:flutterguard_audit/src/network/signals.dart';
import 'package:flutterguard_audit/src/toolchain/toolchain.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('complexity counts the remaining decision forms', () {
    final parsed = parseString(
      content: '''
int sample(int value) {
  var total = 0;
  while (value > 0) {
    value--;
  }
  do {
    total++;
  } while (total < 1);
  switch (value) {
    case 1:
      break;
    default:
      break;
  }
  final kind = switch (value) {
    1 => 'one',
    _ => 'other',
  };
  final flag = value > 0 ? 1 : 0;
  try {
    total += flag;
  } catch (error) {
    total = 0;
  }
  final list = [
    for (final item in [1])
      if (item > 0) item,
  ];
  return total + (value > 0 || kind.isEmpty ? list.length : 0);
}
''',
    );
    final function = parsed.unit.declarations.first;
    expect(cyclomaticComplexity(function), greaterThan(8));
    expect(
      lineSpan(
        function,
        (offset) => parsed.lineInfo.getLocation(offset).lineNumber,
      ),
      greaterThan(5),
    );
  });

  test('severity SARIF levels and profile validation', () {
    expect(Severity.critical.sarifLevel, 'error');
    expect(Severity.high.sarifLevel, 'error');
    expect(Severity.medium.sarifLevel, 'warning');
    expect(Severity.low.sarifLevel, 'note');
    expect(Severity.info.sarifLevel, 'note');
    expect(
      () => architectureProfile('custom'),
      throwsA(isA<ConfigException>()),
    );
    expect(
      () => validateGlob('lib/[a].dart', 'include'),
      throwsA(isA<ConfigException>()),
    );
  });

  test('configuration rejects malformed documents', () {
    expect(() => parseConfig('version: [1]'), throwsA(isA<ConfigException>()));
    expect(
      () => parseConfig('version: 1\nnotAKey: true\n'),
      throwsA(isA<ConfigException>()),
    );
    expect(
      () => parseConfig('''
version: 1
architecture:
  profile: custom
'''),
      throwsA(isA<ConfigException>()),
    );
    expect(
      () => parseConfig('''
version: 1
reports:
  directory: /tmp/outside
'''),
      throwsA(isA<ConfigException>()),
    );
    expect(
      () => parseConfig('''
version: 1
suppressions:
  - rule: FG-QUAL-005
'''),
      throwsA(isA<ConfigException>()),
    );
    expect(
      () => parseConfig('''
version: 1
customRules:
  - id: FG-ARCH-001
    severity: low
    category: configuration
    message: no
    recommendation: no
    contains: x
'''),
      throwsA(isA<ConfigException>()),
    );
    final custom = parseConfig('''
version: 1
architecture:
  profile: custom
  layers:
    - name: ui
      paths: ["lib/ui/**"]
      mayImport: []
    - name: data
      paths: ["lib/data/**"]
      mayImport: [ui]
rules:
  FG-QUAL-005:
    enabled: false
    severity: info
''');
    expect(custom.architecture.profile, 'custom');
    expect(custom.architecture.layers, hasLength(2));
  });

  test('pubspec reader keeps path and git sources', () {
    final info = readPubspec('''
name: gap
dependencies:
  flutter:
    sdk: flutter
  local_pkg:
    path: ../local_pkg
  git_pkg:
    git: https://example.com/git_pkg.git
''');
    expect(
      info.dependencies.map((item) => item.source),
      containsAll(['sdk', 'path', 'git']),
    );
    expect(readPubspec('[').error, isNotNull);
    expect(readLockFile('packages: []'), isEmpty);
  });

  test('safe path refuses a lexical escape', () {
    final root = Directory.systemTemp.createTempSync('flutterguard_safe');
    addTearDown(() => root.deleteSync(recursive: true));
    final safe = SafePath(root.path);
    expect(safe.joinInside('../outside.txt'), isNull);
    expect(safe.isInside(p.join(root.path, 'lib', 'main.dart')), isTrue);
  });

  test(
    'gap project covers custom, platform, dependency, and network rules',
    () async {
      final root = Directory.systemTemp.createTempSync('flutterguard_gap');
      addTearDown(() => root.deleteSync(recursive: true));
      void write(String relative, String contents) {
        final file = File(p.join(root.path, relative));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(contents);
      }

      write('pubspec.yaml', '''
name: gap_app
description: coverage fixture
publish_to: none
version: 0.0.1
environment:
  sdk: ^3.13.0
dependencies:
  flutter:
    sdk: flutter
  pedantic: ^1.0.0
  analyzer: ^14.0.0
  args: ^2.0.0
  missing_pkg: ^0.0.1
  local_pkg:
    path: packages/local_pkg
  git_pkg:
    git:
      url: https://example.com/git_pkg.git
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
flutter:
  uses-material-design: true
''');
      write('pubspec.lock', '''
packages:
  analyzer:
    dependency: direct main
    version: "14.7.0"
  args:
    dependency: direct main
    version: "2.7.0"
  missing_pkg:
    dependency: direct main
    version: "0.0.1"
  flutter:
    dependency: direct main
    version: "0.0.0"
''');
      write('.flutterguard.yaml', '''
version: 1
architecture:
  profile: custom
  layers:
    - name: ui
      paths: ["lib/ui/**"]
      mayImport: []
    - name: data
      paths: ["lib/data/**"]
      mayImport: [ui]
reports:
  history: true
qualityGate:
  failOn: [critical]
  maxFindings: 1
  maxNewFindings: 0
baseline:
  enabled: true
  path: .flutterguard-baseline.json
  failOnNew: true
network:
  outdatedChecks: true
  vulnerabilityChecks: true
localization:
  requiredLocales: [en]
customRules:
  - id: FG-CUSTOM-001
    severity: low
    category: configuration
    message: Marker text is present.
    recommendation: Remove the marker.
    fileGlobs: ["**/*.dart"]
    contains: GAP_MARKER
''');
      write('.flutterguard-baseline.json', '''
{
  "schemaVersion": 1,
  "tool": "FlutterGuard",
  "toolVersion": "0.1.0",
  "generatedAt": "2026-01-01T00:00:00.000Z",
  "findings": []
}
''');
      write('lib/main.dart', "void main() { const marker = 'GAP_MARKER'; }\n");
      write(
        'lib/ui/page.dart',
        "import '../data/store.dart';\nclass Page {}\n",
      );
      write('lib/data/store.dart', 'class Store {}\n');
      write('lib/quality.dart', '''
void risky() {
  try {} catch (error) {}
  Future<void>.value().then((_) {});
}
''');
      write('android/app/src/main/AndroidManifest.xml', '''
<manifest package="com.gap.app">
  <application>
    <activity android:name=".Leak" android:exported="true"/>
  </application>
</manifest>
''');
      write('android/app/src/debug/AndroidManifest.xml', '<manifest>');
      write('ios/Runner/Info.plist', '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>NSCameraUsageDescription</key><string> </string>
  <key>NSAppTransportSecurity</key>
  <dict><key>NSAllowsArbitraryLoads</key><true/></dict>
</dict></plist>
''');
      write('ios/Broken.plist', 'this is not xml');
      write('web/favicon.png', 'png');
      write('windows/runner/notes.json', '{}\n');
      write('macos/Runner/Configs/AppInfo.xcconfig', '// no bundle\n');
      write('linux/runner/notes.json', '{}\n');

      final execution = await const FlutterGuardScanner().scan(
        ScanRequest(
          rootPath: root.path,
          offline: false,
          now: DateTime.utc(2026, 1, 2, 3, 4, 5),
          toolchain: const ToolchainInfo(
            dartVersion: '3.13.5',
            flutterVersion: '3.47.7',
          ),
          outdatedClient: _StaticOutdated(),
          vulnerabilityClient: _StaticVuln(),
        ),
      );
      final rules = execution.report.findings
          .map((finding) => finding.ruleId)
          .toSet();
      expect(rules, contains('FG-CUSTOM-001'));
      expect(rules, contains('FG-ARCH-001'));
      expect(rules, contains('FG-PLAT-003'));
      expect(rules, contains('FG-PLAT-004'));
      expect(rules, contains('FG-PLAT-005'));
      expect(rules, contains('FG-PLAT-006'));
      expect(rules, contains('FG-DEP-001'));
      expect(rules, contains('FG-DEP-002'));
      expect(rules, contains('FG-DEP-003'));
      expect(rules, contains('FG-DEP-005'));
      expect(rules, contains('FG-DEP-006'));
      expect(execution.exitCode, 1);
      expect(
        Directory(p.join(root.path, 'build', 'flutterguard', 'history'))
            .existsSync(),
        isTrue,
      );

      final failed = await const FlutterGuardScanner().scan(
        ScanRequest(
          rootPath: root.path,
          offline: false,
          writeReports: false,
          now: DateTime.utc(2026, 1, 2, 3, 4, 5),
          toolchain: const ToolchainInfo(
            dartVersion: '3.13.5',
            flutterVersion: null,
          ),
          outdatedClient: _FailingOutdated(),
          vulnerabilityClient: _FailingVuln(),
        ),
      );
      expect(
        failed.report.findings.map((finding) => finding.ruleId),
        containsAll(['FG-DEP-002', 'FG-DEP-006']),
      );
      expect(failed.report.warnings, isNotEmpty);
    },
  );
}

final class _StaticOutdated implements OutdatedClient {
  @override
  Future<List<OutdatedPackage>> fetch(String projectRoot) async {
    return const [
      OutdatedPackage(
        name: 'pedantic',
        current: '1.11.1',
        latest: '1.11.2',
        discontinued: true,
      ),
    ];
  }
}

final class _StaticVuln implements VulnerabilityClient {
  @override
  Future<List<PackageAdvisory>> fetch({
    required String package,
    required String version,
  }) async {
    return [
      PackageAdvisory(
        package: package,
        version: version,
        id: 'GHSA-0000-0000-0000',
        summary: 'Example advisory used by the test.',
      ),
    ];
  }
}

final class _FailingOutdated implements OutdatedClient {
  @override
  Future<List<OutdatedPackage>> fetch(String projectRoot) async {
    throw StateError('outdated mirror unavailable');
  }
}

final class _FailingVuln implements VulnerabilityClient {
  @override
  Future<List<PackageAdvisory>> fetch({
    required String package,
    required String version,
  }) async {
    throw StateError('osv unavailable');
  }
}
