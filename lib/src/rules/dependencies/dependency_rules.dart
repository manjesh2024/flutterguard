import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/config.dart';
import '../../core/finding.dart';
import '../../core/severity.dart';
import '../rule.dart';

const toolingPackages = {
  'build_runner',
  'build',
  'json_serializable',
  'freezed',
  'riverpod_generator',
  'flutter_gen_runner',
  'flutter_lints',
  'lints',
  'very_good_analysis',
  'flutter_launcher_icons',
  'flutter_native_splash',
  'melos',
  'custom_lint',
  'build_test',
  'mockito',
  'source_gen',
};

const deprecatedPackages = {
  'pedantic': 'lints',
  'package_info': 'package_info_plus',
  'device_info': 'device_info_plus',
  'connectivity': 'connectivity_plus',
  'share': 'share_plus',
  'android_alarm_manager': 'android_alarm_manager_plus',
  'flutter_webview_plugin': 'webview_flutter',
};

final class UnusedDependencyRule implements AuditRule {
  @override
  String get id => 'FG-DEP-001';
  @override
  String get title => 'Unused direct dependency';
  @override
  String get category => 'dependencies';
  @override
  Severity get defaultSeverity => Severity.low;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.dependencies;
  @override
  String get description =>
      'Reports a direct dependency that is never referenced by package: import or analysis_options. Codegen and lint packages in the built-in tooling list are skipped.';
  @override
  String get recommendation =>
      'Remove the dependency or import it. The tooling allow list is not a complete catalog.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final corpus = _corpus(scope);
    final findings = <Finding>[];
    for (final dependency in [
      ...scope.project.pubspec.dependencies,
      ...scope.project.pubspec.devDependencies,
    ]) {
      if (dependency.source == 'sdk' ||
          toolingPackages.contains(dependency.name)) {
        continue;
      }
      final needle = 'package:${dependency.name}/';
      final optionsNeedle = 'package:${dependency.name}';
      if (corpus.contains(needle) || corpus.contains(optionsNeedle)) {
        continue;
      }
      findings.add(
        emit(
          this,
          scope,
          message:
              'Direct dependency ${dependency.name} has no package import in the scanned files.',
          path: 'pubspec.yaml',
        ),
      );
    }
    return findings;
  }
}

final class OutdatedDependencyRule implements AuditRule {
  @override
  String get id => 'FG-DEP-002';
  @override
  String get title => 'Outdated dependency';
  @override
  String get category => 'dependencies';
  @override
  Severity get defaultSeverity => Severity.low;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.dependencies;
  @override
  String get description =>
      'Uses dart pub outdated only when network.outdatedChecks is enabled. Otherwise it records that the check was skipped.';
  @override
  String get recommendation =>
      'Upgrade on a branch and run the test suite. A newer version is not automatically safe.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    if (scope.signals.outdatedStatus == 'disabled') {
      return const [];
    }
    if (scope.signals.outdatedStatus != 'ok') {
      return [
        emit(
          this,
          scope,
          message:
              'Outdated dependency check did not complete: ${scope.signals.outdatedStatus}.',
          path: 'pubspec.yaml',
          severity: Severity.info,
        ),
      ];
    }
    return [
      for (final package in scope.signals.outdated)
        if (package.current != null &&
            package.latest != null &&
            package.current != package.latest)
          emit(
            this,
            scope,
            message:
                '${package.name} ${package.current} has newer version ${package.latest} according to pub outdated.',
            path: 'pubspec.lock',
          ),
    ];
  }
}

final class DeprecatedPackageRule implements AuditRule {
  @override
  String get id => 'FG-DEP-003';
  @override
  String get title => 'Deprecated package indicator';
  @override
  String get category => 'dependencies';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.dependencies;
  @override
  String get description =>
      'Matches a small curated list of packages that have a maintained replacement. The list is not exhaustive.';
  @override
  String get recommendation =>
      'Read the replacement package notes before migrating. This indicator is not a vulnerability.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final dependency in [
      ...scope.project.pubspec.dependencies,
      ...scope.project.pubspec.devDependencies,
    ]) {
      final replacement = deprecatedPackages[dependency.name];
      if (replacement == null) {
        continue;
      }
      findings.add(
        emit(
          this,
          scope,
          message:
              '${dependency.name} is on the curated discontinued list. A common replacement is $replacement.',
          path: 'pubspec.yaml',
        ),
      );
    }
    for (final package in scope.signals.outdated.where(
      (item) => item.discontinued,
    )) {
      findings.add(
        emit(
          this,
          scope,
          message: '${package.name} is marked discontinued by pub outdated.',
          path: 'pubspec.lock',
        ),
      );
    }
    return findings;
  }
}

final class LicenseMetadataRule implements AuditRule {
  @override
  String get id => 'FG-DEP-004';
  @override
  String get title => 'License metadata';
  @override
  String get category => 'dependencies';
  @override
  Severity get defaultSeverity => Severity.low;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.dependencies;
  @override
  String get description =>
      'Reads LICENSE files already present in the local pub cache. This is metadata, not a legal opinion.';
  @override
  String get recommendation =>
      'Run dart pub get and review the license file. Do not treat a missing cache entry as a license violation.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    if (scope.project.pubspec.license == null ||
        scope.project.pubspec.license!.trim().isEmpty) {
      findings.add(
        emit(
          this,
          scope,
          message: 'pubspec.yaml has no license field.',
          path: 'pubspec.yaml',
          severity: Severity.info,
        ),
      );
    }
    for (final locked in scope.project.lockedPackages.where(
      (item) => item.direct,
    )) {
      if (locked.name == 'flutter' || locked.name == 'flutter_test') {
        continue;
      }
      final kind = cachedLicenseKind(locked.name, locked.version);
      if (kind == null) {
        findings.add(
          emit(
            this,
            scope,
            message:
                'No LICENSE file for ${locked.name} ${locked.version} was found in the local pub cache.',
            path: 'pubspec.lock',
            severity: Severity.info,
          ),
        );
      } else if (kind == 'unknown') {
        findings.add(
          emit(
            this,
            scope,
            message:
                'LICENSE file for ${locked.name} ${locked.version} did not match a known license heading.',
            path: 'pubspec.lock',
          ),
        );
      }
    }
    return findings;
  }
}

final class DependencySourceRule implements AuditRule {
  @override
  String get id => 'FG-DEP-005';
  @override
  String get title => 'Dependency source';
  @override
  String get category => 'dependencies';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.dependencies;
  @override
  String get description =>
      'Reports path and git dependencies in the production dependency section.';
  @override
  String get recommendation =>
      'Prefer a hosted version constraint for released apps. Path and git sources are valid during development.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final dependency in scope.project.pubspec.dependencies) {
      if (dependency.source != 'path' && dependency.source != 'git') {
        continue;
      }
      findings.add(
        emit(
          this,
          scope,
          message:
              '${dependency.name} uses a ${dependency.source} source in dependencies.',
          path: 'pubspec.yaml',
        ),
      );
    }
    return findings;
  }
}

final class VulnerabilityRule implements AuditRule {
  @override
  String get id => 'FG-DEP-006';
  @override
  String get title => 'Vulnerability advisory';
  @override
  String get category => 'dependencies';
  @override
  Severity get defaultSeverity => Severity.high;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.dependencies;
  @override
  String get description =>
      'Queries the OSV API for locked package versions only when network.vulnerabilityChecks is enabled. No project source is uploaded.';
  @override
  String get recommendation =>
      'Read the advisory and upgrade or apply the documented mitigation. An advisory id is not an exploit.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    if (scope.signals.vulnerabilityStatus == 'disabled') {
      return const [];
    }
    if (scope.signals.vulnerabilityStatus != 'ok') {
      return [
        emit(
          this,
          scope,
          message:
              'Vulnerability check did not complete: ${scope.signals.vulnerabilityStatus}.',
          path: 'pubspec.lock',
          severity: Severity.info,
        ),
      ];
    }
    return [
      for (final advisory in scope.signals.advisories)
        emit(
          this,
          scope,
          message:
              '${advisory.package} ${advisory.version} matches advisory ${advisory.id}: ${advisory.summary}',
          path: 'pubspec.lock',
        ),
    ];
  }
}

String _corpus(RuleScope scope) {
  final buffer = StringBuffer();
  for (final file in scope.project.files.files) {
    final text = file.text;
    if (text != null) {
      buffer.writeln(text);
    }
  }
  return buffer.toString();
}

String? cachedLicenseKind(String package, String version) {
  final cache =
      Platform.environment['PUB_CACHE'] ??
      p.join(Platform.environment['HOME'] ?? '', '.pub-cache');
  final directories = [
    Directory(p.join(cache, 'hosted', 'pub.dev', '$package-$version')),
    Directory(p.join(cache, 'hosted', 'pub.dartlang.org', '$package-$version')),
  ];
  for (final directory in directories) {
    if (!directory.existsSync()) {
      continue;
    }
    for (final name in const [
      'LICENSE',
      'LICENSE.md',
      'LICENSE.txt',
      'COPYING',
    ]) {
      final file = File(p.join(directory.path, name));
      if (!file.existsSync()) {
        continue;
      }
      final text = file.readAsStringSync().toLowerCase();
      if (text.contains('mit license') ||
          text.contains('permission is hereby granted')) {
        return 'MIT';
      }
      if (text.contains('apache license')) {
        return 'Apache-2.0';
      }
      if (text.contains('bsd')) {
        return 'BSD';
      }
      if (text.contains('isc license')) {
        return 'ISC';
      }
      if (text.contains('gnu general public')) {
        return 'GPL';
      }
      return 'unknown';
    }
  }
  return null;
}

List<AuditRule> dependencyRules() => [
  UnusedDependencyRule(),
  OutdatedDependencyRule(),
  DeprecatedPackageRule(),
  LicenseMetadataRule(),
  DependencySourceRule(),
  VulnerabilityRule(),
];
