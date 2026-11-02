import 'dart:io';

import 'package:flutterguard_audit/flutterguard_audit.dart';
import 'package:flutterguard_audit/src/analyzer/manifest_parser.dart';
import 'package:flutterguard_audit/src/context/project_snapshot.dart';
import 'package:flutterguard_audit/src/rules/dependencies/dependency_rules.dart';
import 'package:flutterguard_audit/src/toolchain/toolchain.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/fixtures.dart';

void main() {
  if (!fixturesPresent) {
    test('accuracy fixtures ship with the source repository', () {
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

  test(
    'display names ignore engine metadata and resolve PRODUCT_NAME',
    () async {
      final directory = tempFixture('template_names');
      final before = checksums(directory);
      final execution = await scan(directory);
      expect(checksums(directory), before);
      final rules = execution.report.findings.map((finding) => finding.ruleId);
      expect(rules, isNot(contains('FG-BRAND-003')));
      expect(
        execution.report.findings.map((finding) => finding.message),
        isNot(contains('Android application label is missing.')),
      );
      final names = execution.report.projects.expand(
        (project) => project.names,
      );
      expect(
        names.map((name) => name.value),
        containsAll(['smoke_app', 'Smoke App']),
      );
      expect(names.map((name) => name.value), isNot(contains('App')));
      expect(
        names.map((name) => name.value),
        isNot(contains(r'$(PRODUCT_NAME)')),
      );
    },
  );

  test('flavor names do not conflict with the shared display name', () async {
    final execution = await scan(tempFixture('flavor_names'));
    final rules = execution.report.findings.map((finding) => finding.ruleId);
    expect(rules, isNot(contains('FG-BRAND-003')));
    expect(rules, isNot(contains('FG-BRAND-005')));
  });

  test('constructor and extension uses keep imports', () async {
    final execution = await scan(tempFixture('imported_symbol'));
    final unused = execution.report.findings
        .where((finding) => finding.ruleId == 'FG-QUAL-008')
        .map((finding) => finding.path)
        .toList();
    expect(unused, ['lib/unused_import.dart']);
  });

  test(
    'short labels, debug text, and tests are not user-facing strings',
    () async {
      final execution = await scan(tempFixture('non_ui_strings'));
      expect(
        execution.report.findings.map((finding) => finding.ruleId),
        isNot(contains('FG-L10N-006')),
      );
    },
  );

  test(
    'a Flutter application is not flagged for a missing pubspec license',
    () async {
      final execution = await scan(tempFixture('license_app'));
      expect(
        execution.report.findings.map((finding) => finding.message).join('\n'),
        isNot(contains('pubspec.yaml has no license field')),
      );
    },
  );

  test(
    'dependency usage is heuristic and does not edit pubspec.yaml',
    () async {
      final directory = tempFixture('dependency_usage');
      final pubspec = File(p.join(directory.path, 'pubspec.yaml'));
      final before = pubspec.readAsBytesSync();
      final execution = await scan(directory);
      expect(pubspec.readAsBytesSync(), before);
      final unused = execution.report.findings
          .where((finding) => finding.ruleId == 'FG-DEP-001')
          .toList();
      expect(unused, hasLength(1));
      expect(unused.single.message, contains('vector_math'));
      expect(unused.single.message, contains('heuristic'));
      expect(unused.single.message, contains('did not remove'));
    },
  );

  test(
    'license headings and SPDX identifiers classify without a legal conclusion',
    () {
      expect(classifyLicenseText('SPDX-License-Identifier: MIT\n'), 'MIT');
      expect(classifyLicenseText('BSD 3-Clause License\n'), 'BSD');
      expect(
        classifyLicenseText(
          'Copyright 2013 The Flutter Authors\n\n'
          'Redistribution and use in source and binary forms, with or without modification, are permitted.\n',
        ),
        'BSD',
      );
      expect(classifyLicenseText('no heading here'), 'unknown');
    },
  );

  test('build variables and manifest overlays resolve literally', () {
    expect(
      canonicalDisplayName('Smoke App'),
      canonicalDisplayName('smoke_app'),
    );
    expect(
      canonicalDisplayName('Multi Android'),
      isNot(canonicalDisplayName('Multi iOS')),
    );
    expect(
      resolveBuildVariables(r'${PRODUCT_NAME}', {'PRODUCT_NAME': 'smoke_app'}),
      'smoke_app',
    );
    expect(
      resolveBuildVariables(r'$(PRODUCT_NAME)', {'PRODUCT_NAME': 'smoke_app'}),
      'smoke_app',
    );
    expect(
      resolveBuildVariables(r'$(TARGET_NAME)', {
        'TARGET_NAME': r'$(PRODUCT_NAME)',
      }),
      isNull,
    );
    expect(
      isMainAndroidManifest('android/app/src/main/AndroidManifest.xml'),
      isTrue,
    );
    expect(
      isMainAndroidManifest('android/app/src/debug/AndroidManifest.xml'),
      isFalse,
    );
    expect(
      isMainAndroidManifest('android/app/src/profile/AndroidManifest.xml'),
      isFalse,
    );
    expect(
      isEngineFrameworkPlist('ios/Flutter/AppFrameworkInfo.plist'),
      isTrue,
    );
  });

  test('html dashboard stays local and links the other reports', () async {
    final directory = tempFixture('template_names');
    await scan(directory);
    final html = File(p.join(directory.path, 'build/flutterguard/index.html'))
        .readAsStringSync();
    expect(html, contains('href="report.json"'));
    expect(html, contains('href="report.md"'));
    expect(html, contains('href="report.sarif"'));
    expect(html, contains('prefers-color-scheme'));
    expect(html.toLowerCase(), isNot(contains('https://')));
    expect(html.toLowerCase(), isNot(contains('http://')));
    expect(html, isNot(contains('<script src')));
    expect(html, isNot(contains('<link rel="stylesheet" href')));
  });
}
