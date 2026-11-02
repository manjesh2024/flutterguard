import '../../analyzer/manifest_parser.dart';
import '../../core/config.dart';
import '../../core/finding.dart';
import '../../core/severity.dart';
import '../rule.dart';

/// Checks an existing `android/` tree for a manifest and exported components.
///
/// Projects without Android are skipped. Reports a missing manifest, a
/// manifest parse error, a missing application label, and each exported
/// component that has no intent filter. The exported-component finding is
/// marked heuristic.
final class AndroidPlatformRule implements AuditRule {
  @override
  String get id => 'FG-PLAT-001';
  @override
  String get title => 'Android project';
  @override
  String get category => 'platform';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.platform;
  @override
  String get description =>
      'Checks an existing android/ directory for a manifest and exported components without intent filters. Debug, profile, and release overlays inherit the main application label.';
  @override
  String get recommendation =>
      'Add the missing manifest entry on the main source set, or an intent filter before exporting a component.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    if (!scope.project.platforms.contains('android')) {
      return const [];
    }
    final findings = <Finding>[];
    if (scope.project.manifests.isEmpty) {
      findings.add(
        emit(
          this,
          scope,
          message: 'android/ has no AndroidManifest.xml.',
          path: 'android',
        ),
      );
    }
    final manifests = scope.project.manifests;
    final mains = manifests.where(
      (manifest) => isMainAndroidManifest(manifest.path),
    );
    final labelManifests = mains.isEmpty ? manifests : mains;
    for (final manifest in manifests) {
      if (manifest.error != null) {
        findings.add(
          emit(
            this,
            scope,
            message:
                'AndroidManifest.xml could not be parsed: ${manifest.error}',
            path: manifest.path,
          ),
        );
      }
      for (final component in manifest.exportedActivitiesWithoutIntent) {
        findings.add(
          emit(
            this,
            scope,
            message: 'Exported component $component has no intent filter.',
            path: manifest.path,
            heuristic: true,
          ),
        );
      }
    }
    for (final manifest in labelManifests) {
      final label = manifest.label?.trim();
      if (label == null || label.isEmpty) {
        findings.add(
          emit(
            this,
            scope,
            message: 'Android application label is missing.',
            path: manifest.path,
          ),
        );
      }
    }
    return findings;
  }
}

/// Checks an existing `ios/` tree for Info.plist identity and privacy strings.
///
/// Projects without iOS are skipped. A missing Info.plist and a missing
/// bundle identifier are reported at high severity. A missing iOS display
/// name, each empty privacy key, and each plist error are also reported.
final class IosPlatformRule implements AuditRule {
  @override
  String get id => 'FG-PLAT-002';
  @override
  String get title => 'iOS project';
  @override
  String get category => 'platform';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.platform;
  @override
  String get description =>
      'Checks an existing ios/ directory for Info.plist identity and empty privacy strings.';
  @override
  String get recommendation =>
      'Set the bundle identifier and a non-empty usage description for every privacy key.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    if (!scope.project.platforms.contains('ios')) {
      return const [];
    }
    final findings = <Finding>[];
    final hasPlist = scope.project.files.files.any(
      (file) => file.relativePosix.endsWith('Info.plist'),
    );
    if (!hasPlist) {
      findings.add(
        emit(
          this,
          scope,
          message: 'ios/ has no Info.plist.',
          path: 'ios',
          severity: Severity.high,
        ),
      );
    }
    if (scope.project.bundleIdentifiers.isEmpty) {
      findings.add(
        emit(
          this,
          scope,
          message: 'iOS bundle identifier was not found.',
          path: 'ios',
          severity: Severity.high,
        ),
      );
    }
    if (!scope.project.names.any(
      (name) => name.source.contains('ios') || name.source.endsWith('.plist'),
    )) {
      findings.add(
        emit(
          this,
          scope,
          message: 'iOS display name was not found.',
          path: 'ios',
        ),
      );
    }
    for (final key in scope.project.emptyPrivacyKeys) {
      findings.add(
        emit(
          this,
          scope,
          message: '$key is empty.',
          path: 'ios/Runner/Info.plist',
        ),
      );
    }
    for (final error in scope.project.plistErrors) {
      findings.add(emit(this, scope, message: error, path: 'ios'));
    }
    return findings;
  }
}

/// Checks an existing `web/` tree for `index.html` and `manifest.json`.
///
/// Projects without web are skipped. A missing `web/index.html` is reported
/// at high severity. A missing `web/manifest.json` uses the rule default.
final class WebPlatformRule implements AuditRule {
  @override
  String get id => 'FG-PLAT-003';
  @override
  String get title => 'Web project';
  @override
  String get category => 'platform';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.platform;
  @override
  String get description =>
      'Checks an existing web/ directory for index.html and manifest.json.';
  @override
  String get recommendation =>
      'Restore the Flutter web template files before building for web.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    if (!scope.project.platforms.contains('web')) {
      return const [];
    }
    final findings = <Finding>[];
    if (!scope.project.containsRelative('web/index.html')) {
      findings.add(
        emit(
          this,
          scope,
          message: 'web/index.html is missing.',
          path: 'web',
          severity: Severity.high,
        ),
      );
    }
    if (!scope.project.containsRelative('web/manifest.json')) {
      findings.add(
        emit(
          this,
          scope,
          message: 'web/manifest.json is missing.',
          path: 'web',
        ),
      );
    }
    return findings;
  }
}

/// Checks an existing `windows/` tree for `CMakeLists.txt` and `Runner.rc`.
///
/// Projects without Windows are skipped. A missing CMake file is reported at
/// high severity. A missing `windows/runner/Runner.rc` uses the rule default.
final class WindowsPlatformRule implements AuditRule {
  @override
  String get id => 'FG-PLAT-004';
  @override
  String get title => 'Windows project';
  @override
  String get category => 'platform';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.platform;
  @override
  String get description =>
      'Checks an existing windows/ directory for CMake and Runner.rc.';
  @override
  String get recommendation => 'Restore the Flutter windows runner files.';

  @override
  List<Finding> evaluate(RuleScope scope) => _desktop(
    this,
    scope,
    'windows',
    'windows/CMakeLists.txt',
    'windows/runner/Runner.rc',
  );
}

/// Checks an existing `macos/` tree for an Xcode project and bundle identifier.
///
/// Projects without macOS are skipped. The project check looks for a
/// `.pbxproj` path containing `macos/`. The identifier check looks for the
/// text `PRODUCT_BUNDLE_IDENTIFIER` in a file under `macos/`.
final class MacosPlatformRule implements AuditRule {
  @override
  String get id => 'FG-PLAT-005';
  @override
  String get title => 'macOS project';
  @override
  String get category => 'platform';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.platform;
  @override
  String get description =>
      'Checks an existing macos/ directory for the Xcode project and bundle identifier.';
  @override
  String get recommendation =>
      'Restore the Flutter macOS runner and set PRODUCT_BUNDLE_IDENTIFIER.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    if (!scope.project.platforms.contains('macos')) {
      return const [];
    }
    final findings = <Finding>[];
    final hasProject = scope.project.files.files.any(
      (file) =>
          file.relativePosix.contains('macos/') &&
          file.relativePosix.endsWith('.pbxproj'),
    );
    if (!hasProject) {
      findings.add(
        emit(
          this,
          scope,
          message: 'macos/ has no Xcode project.',
          path: 'macos',
        ),
      );
    }
    final hasBundle = scope.project.files.files.any((file) {
      if (!file.relativePosix.startsWith('macos/') || file.text == null) {
        return false;
      }
      return file.text!.contains('PRODUCT_BUNDLE_IDENTIFIER');
    });
    if (!hasBundle) {
      findings.add(
        emit(
          this,
          scope,
          message: 'macOS PRODUCT_BUNDLE_IDENTIFIER was not found.',
          path: 'macos',
        ),
      );
    }
    return findings;
  }
}

/// Checks an existing `linux/` tree for CMake and `my_application.cc`.
///
/// Projects without Linux are skipped. A missing `linux/CMakeLists.txt` is
/// reported at high severity. A missing `linux/runner/my_application.cc` uses
/// the rule default.
final class LinuxPlatformRule implements AuditRule {
  @override
  String get id => 'FG-PLAT-006';
  @override
  String get title => 'Linux project';
  @override
  String get category => 'platform';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.platform;
  @override
  String get description =>
      'Checks an existing linux/ directory for CMake and my_application.cc.';
  @override
  String get recommendation => 'Restore the Flutter Linux runner files.';

  @override
  List<Finding> evaluate(RuleScope scope) => _desktop(
    this,
    scope,
    'linux',
    'linux/CMakeLists.txt',
    'linux/runner/my_application.cc',
  );
}

List<Finding> _desktop(
  AuditRule rule,
  RuleScope scope,
  String platform,
  String cmake,
  String entry,
) {
  if (!scope.project.platforms.contains(platform)) {
    return const [];
  }
  final findings = <Finding>[];
  if (!scope.project.containsRelative(cmake)) {
    findings.add(
      emit(
        rule,
        scope,
        message: '$cmake is missing.',
        path: platform,
        severity: Severity.high,
      ),
    );
  }
  if (!scope.project.containsRelative(entry)) {
    findings.add(
      emit(rule, scope, message: '$entry is missing.', path: platform),
    );
  }
  return findings;
}

/// Built-in platform rules, in a stable evaluation order.
List<AuditRule> platformRules() => [
  AndroidPlatformRule(),
  IosPlatformRule(),
  WebPlatformRule(),
  WindowsPlatformRule(),
  MacosPlatformRule(),
  LinuxPlatformRule(),
];
