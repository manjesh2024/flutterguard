import '../../core/config.dart';
import '../../core/finding.dart';
import '../../core/severity.dart';
import '../rule.dart';

final _placeholderId = RegExp(
  r'^(com\.example(\..*)?|com\.yourcompany\..*|your\.bundle\.identifier)$',
);

/// Whether [value] is a Flutter template application or bundle identifier.
///
/// After trimming, matches `com.example`, `com.example.*`,
/// `com.yourcompany.*`, and `your.bundle.identifier`.
bool isPlaceholderIdentifier(String value) =>
    _placeholderId.hasMatch(value.trim());

/// Checks Android `applicationId` values for absence and template placeholders.
///
/// Projects without Android are skipped. A project with no Gradle files is
/// reported immediately. Otherwise each id is checked with
/// [isPlaceholderIdentifier], and Gradle files that declare no id at all are
/// reported once.
final class AndroidApplicationIdRule implements AuditRule {
  @override
  String get id => 'FG-BRAND-001';
  @override
  String get title => 'Android application ID';
  @override
  String get category => 'branding';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.branding;
  @override
  String get description =>
      'Checks Android applicationId values for missing and template placeholders.';
  @override
  String get recommendation =>
      'Set a unique applicationId in android/app/build.gradle for every shipped flavor.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    if (!scope.project.platforms.contains('android')) {
      return const [];
    }
    final findings = <Finding>[];
    if (scope.project.gradleFiles.isEmpty) {
      findings.add(
        emit(
          this,
          scope,
          message: 'Android project has no build.gradle applicationId.',
          path: 'android',
        ),
      );
      return findings;
    }
    var sawId = false;
    for (final gradle in scope.project.gradleFiles) {
      for (final id in gradle.applicationIds) {
        sawId = true;
        if (isPlaceholderIdentifier(id)) {
          findings.add(
            emit(
              this,
              scope,
              message:
                  'Android applicationId "$id" is still a template placeholder.',
              path: gradle.path,
            ),
          );
        }
      }
    }
    if (!sawId) {
      findings.add(
        emit(
          this,
          scope,
          message: 'Android Gradle files do not declare an applicationId.',
          path: scope.project.gradleFiles.first.path,
        ),
      );
    }
    return findings;
  }
}

/// Checks iOS bundle identifiers for absence and template placeholders.
///
/// Projects without iOS are skipped. An empty identifier list is one finding.
/// Each remaining identifier that [isPlaceholderIdentifier] accepts is
/// reported against `ios`.
final class IosBundleIdentifierRule implements AuditRule {
  @override
  String get id => 'FG-BRAND-002';
  @override
  String get title => 'iOS bundle identifier';
  @override
  String get category => 'branding';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.branding;
  @override
  String get description =>
      'Checks iOS bundle identifiers from Info.plist, xcconfig, and the Xcode project.';
  @override
  String get recommendation =>
      'Set PRODUCT_BUNDLE_IDENTIFIER to the shipped bundle id, not a Flutter template value.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    if (!scope.project.platforms.contains('ios')) {
      return const [];
    }
    final ids = scope.project.bundleIdentifiers;
    if (ids.isEmpty) {
      return [
        emit(
          this,
          scope,
          message: 'iOS project does not declare a bundle identifier.',
          path: 'ios',
        ),
      ];
    }
    return [
      for (final id in ids)
        if (isPlaceholderIdentifier(id))
          emit(
            this,
            scope,
            message:
                'iOS bundle identifier "$id" is still a template placeholder.',
            path: 'ios',
          ),
    ];
  }
}

/// Reports default application names that disagree across platforms.
///
/// Flavor-specific names are ignored. The remaining names are compared
/// case-insensitively after trimming, and one finding lists every source
/// when two or more distinct names remain.
final class ApplicationNameRule implements AuditRule {
  @override
  String get id => 'FG-BRAND-003';
  @override
  String get title => 'Application name consistency';
  @override
  String get category => 'branding';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.branding;
  @override
  String get description =>
      'Compares default, non-flavor application names across Android, iOS, and web.';
  @override
  String get recommendation =>
      'Use one customer-facing name, or give flavor-specific names an explicit flavor.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final names = scope.project.names
        .where((name) => name.flavor == null)
        .toList();
    final distinct = <String>{};
    for (final name in names) {
      distinct.add(name.value.trim().toLowerCase());
    }
    if (distinct.length < 2) {
      return const [];
    }
    final rendered = names
        .map((name) => '${name.value} (${name.source})')
        .join(', ');
    return [
      emit(
        this,
        scope,
        message: 'Application names differ: $rendered.',
        path: names.first.source,
      ),
    ];
  }
}

/// Checks that each present platform ships a launcher icon or favicon file.
///
/// Android requires a non-empty `ic_launcher` file under a mipmap directory.
/// iOS requires a path containing `AppIcon.appiconset`. Web requires
/// `web/favicon.png`, reported at low severity when it is missing. Platforms
/// that are not part of the project are skipped.
final class LauncherIconRule implements AuditRule {
  @override
  String get id => 'FG-BRAND-004';
  @override
  String get title => 'Launcher icons';
  @override
  String get category => 'branding';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.branding;
  @override
  String get description =>
      'Checks that existing platforms ship a launcher icon or favicon file.';
  @override
  String get recommendation =>
      'Add the platform icon set. An empty or missing icon is not treated as a brand review.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    final files = scope.project.files.files;
    if (scope.project.platforms.contains('android')) {
      final icons = files.where(
        (file) =>
            file.relativePosix.contains('mipmap') &&
            file.relativePosix.contains('ic_launcher'),
      );
      if (icons.isEmpty) {
        findings.add(
          emit(
            this,
            scope,
            message: 'Android launcher icon ic_launcher is missing.',
            path: 'android/app/src/main/res',
          ),
        );
      } else if (icons.every((file) => file.size == 0)) {
        findings.add(
          emit(
            this,
            scope,
            message: 'Android launcher icon files are empty.',
            path: icons.first.relativePosix,
          ),
        );
      }
    }
    if (scope.project.platforms.contains('ios')) {
      final hasIcon = files.any(
        (file) => file.relativePosix.contains('AppIcon.appiconset'),
      );
      if (!hasIcon) {
        findings.add(
          emit(
            this,
            scope,
            message: 'iOS AppIcon.appiconset is missing.',
            path: 'ios/Runner/Assets.xcassets',
          ),
        );
      }
    }
    if (scope.project.platforms.contains('web') &&
        !files.any((file) => file.relativePosix == 'web/favicon.png')) {
      findings.add(
        emit(
          this,
          scope,
          message: 'Web favicon.png is missing.',
          path: 'web',
          severity: Severity.low,
        ),
      );
    }
    return findings;
  }
}

/// Heuristic that product flavors resolve to distinct ids and exist on iOS.
///
/// Gradle files with fewer than two flavors are skipped. A flavor that sets
/// neither an application id nor a suffix is reported. Flavors that resolve
/// to the same id are reported together. When the project also has iOS, each
/// flavor name must appear in some path under `ios/`.
final class FlavorBrandingRule implements AuditRule {
  @override
  String get id => 'FG-BRAND-005';
  @override
  String get title => 'Flavor branding';
  @override
  String get category => 'branding';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.branding;
  @override
  String get description =>
      'Checks that Android product flavors resolve to distinct ids and that iOS has a matching flavor file.';
  @override
  String get recommendation =>
      'Give each flavor its own applicationId or suffix, and add an iOS xcconfig or scheme with the flavor name.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final gradle in scope.project.gradleFiles) {
      if (gradle.flavors.length < 2) {
        continue;
      }
      final defaultId = gradle.applicationIds.isEmpty
          ? null
          : gradle.applicationIds.first;
      final resolved = <String, List<String>>{};
      for (final flavor in gradle.flavors) {
        final id = flavor.resolvedId(defaultId);
        if (id == null) {
          findings.add(
            emit(
              this,
              scope,
              message:
                  'Flavor "${flavor.name}" does not set applicationId or applicationIdSuffix.',
              path: gradle.path,
            ),
          );
          continue;
        }
        resolved.putIfAbsent(id, () => []).add(flavor.name);
      }
      for (final entry in resolved.entries) {
        if (entry.value.length > 1) {
          findings.add(
            emit(
              this,
              scope,
              message:
                  'Flavors ${entry.value.join(' and ')} resolve to the same applicationId ${entry.key}.',
              path: gradle.path,
            ),
          );
        }
      }
      if (scope.project.platforms.contains('ios')) {
        final iosFiles = scope.project.files.files
            .where((file) => file.relativePosix.startsWith('ios/'))
            .map((file) => file.relativePosix.toLowerCase())
            .toList();
        for (final flavor in gradle.flavors) {
          final needle = flavor.name.toLowerCase();
          final matched = iosFiles.any((path) => path.contains(needle));
          if (!matched) {
            findings.add(
              emit(
                this,
                scope,
                message:
                    'Android flavor "${flavor.name}" has no iOS file containing that flavor name.',
                path: gradle.path,
              ),
            );
          }
        }
      }
    }
    return findings;
  }
}

/// Checks that `flutter/assets` entries in `pubspec.yaml` exist on disk.
///
/// Paths are compared inside the project using `/` separators. An entry that
/// ends with `/` matches any file under that prefix; every other entry must
/// equal a project-relative path.
final class AssetConsistencyRule implements AuditRule {
  @override
  String get id => 'FG-BRAND-006';
  @override
  String get title => 'Asset consistency';
  @override
  String get category => 'branding';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.branding;
  @override
  String get description =>
      'Checks that flutter/assets entries in pubspec.yaml exist in the project.';
  @override
  String get recommendation =>
      'Add the missing asset or remove the pubspec entry. Paths are resolved inside the project only.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    final files = scope.project.files.files
        .map((file) => file.relativePosix)
        .toSet();
    for (final asset in scope.project.pubspec.assets) {
      final relative = asset.replaceAll('\\', '/');
      final exists = relative.endsWith('/')
          ? files.any((file) => file.startsWith(relative))
          : files.contains(relative);
      if (!exists) {
        findings.add(
          emit(
            this,
            scope,
            message: 'pubspec asset "$relative" does not exist.',
            path: 'pubspec.yaml',
          ),
        );
      }
    }
    return findings;
  }
}

/// Built-in branding rules, in a stable evaluation order.
List<AuditRule> brandingRules() => [
  AndroidApplicationIdRule(),
  IosBundleIdentifierRule(),
  ApplicationNameRule(),
  LauncherIconRule(),
  FlavorBrandingRule(),
  AssetConsistencyRule(),
];
