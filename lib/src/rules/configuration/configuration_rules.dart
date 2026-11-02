import '../../analyzer/dart_index.dart';
import '../../core/config.dart';
import '../../core/finding.dart';
import '../../core/severity.dart';
import '../rule.dart';

final _urlPattern = RegExp(r'https?://[^\s<>]+', caseSensitive: false);

final class HardcodedEndpointRule implements AuditRule {
  @override
  String get id => 'FG-CFG-001';
  @override
  String get title => 'Hardcoded endpoint';
  @override
  String get category => 'configuration';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.configuration;
  @override
  String get description =>
      'Reports URL string literals that are not on the configured allow list.';
  @override
  String get recommendation =>
      'Move environment-specific hosts to String.fromEnvironment, a flavor file, or another ignored config source.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final file in scope.project.dartIndex.files) {
      if (file.generated) {
        continue;
      }
      final inTest =
          file.path.contains('/test/') || file.path.startsWith('test/');
      for (final literal in file.strings) {
        final match = _urlPattern.firstMatch(literal.value);
        if (match == null || _allowed(match.group(0)!, scope)) {
          continue;
        }
        findings.add(
          emit(
            this,
            scope,
            message: 'Hardcoded endpoint ${match.group(0)} in a Dart string.',
            path: file.path,
            line: literal.line,
            column: literal.column,
            enclosing: literal.enclosing,
            severity: inTest ? Severity.low : Severity.medium,
          ),
        );
      }
    }
    return findings;
  }

  bool _allowed(String url, RuleScope scope) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host.isEmpty) {
      return true;
    }
    for (final allowed in scope.config.allowedHosts) {
      final needle = allowed.toLowerCase();
      if (host == needle || host.endsWith('.$needle')) {
        return true;
      }
    }
    return false;
  }
}

final class EnvironmentMismatchRule implements AuditRule {
  @override
  String get id => 'FG-CFG-002';
  @override
  String get title => 'Production and staging mismatch';
  @override
  String get category => 'configuration';
  @override
  Severity get defaultSeverity => Severity.high;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.configuration;
  @override
  String get description =>
      'Flags a file that mentions a release or production guard and also embeds a staging, sandbox, or local URL.';
  @override
  String get recommendation =>
      'Select the host from the active flavor. This check is a heuristic, not proof of a bad release build.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final file in scope.project.dartIndex.files) {
      if (file.generated) {
        continue;
      }
      final source = _source(scope, file);
      if (source == null) {
        continue;
      }
      final release =
          source.contains('kReleaseMode') ||
          source.contains("'prod'") ||
          source.contains('"prod"') ||
          source.contains('"production"') ||
          source.contains("'production'");
      if (!release) {
        continue;
      }
      for (final literal in file.strings) {
        final match = _urlPattern.firstMatch(literal.value);
        if (match == null) {
          continue;
        }
        final host = Uri.tryParse(match.group(0)!)?.host.toLowerCase() ?? '';
        if (_staging(host)) {
          findings.add(
            emit(
              this,
              scope,
              message:
                  'Release or production marker shares a file with non-production host $host.',
              path: file.path,
              line: literal.line,
              column: literal.column,
              enclosing: literal.enclosing,
            ),
          );
        }
      }
    }
    return findings;
  }

  bool _staging(String host) {
    return host.contains('staging') ||
        host.contains('sandbox') ||
        host.contains('localhost') ||
        host.startsWith('dev.') ||
        host.contains('.dev');
  }
}

final class DuplicateIdentifierRule implements AuditRule {
  @override
  String get id => 'FG-CFG-003';
  @override
  String get title => 'Duplicate application identifiers';
  @override
  String get category => 'configuration';
  @override
  Severity get defaultSeverity => Severity.high;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.configuration;
  @override
  String get description =>
      'Reports the same Android applicationId or iOS bundle identifier used by more than one app.';
  @override
  String get recommendation =>
      'Give each installable app its own application id and bundle identifier.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    if (scope.workspace.isEmpty ||
        scope.workspace.first.project.rootPath !=
            scope.project.project.rootPath) {
      return const [];
    }
    final owners = <String, List<String>>{};
    for (final project in scope.workspace) {
      final ids = <String>{
        ...project.bundleIdentifiers,
        for (final gradle in project.gradleFiles) ...gradle.applicationIds,
      };
      for (final id in ids) {
        owners.putIfAbsent(id, () => []).add(project.project.name);
      }
    }
    final findings = <Finding>[];
    for (final entry in owners.entries) {
      final unique = entry.value.toSet();
      if (unique.length > 1) {
        findings.add(
          emit(
            this,
            scope,
            message: 'Identifier ${entry.key} is used by ${unique.join(', ')}.',
            path: 'pubspec.yaml',
          ),
        );
      }
    }
    return findings;
  }
}

final class DebugReleaseRule implements AuditRule {
  @override
  String get id => 'FG-CFG-004';
  @override
  String get title => 'Debug settings in release configuration';
  @override
  String get category => 'configuration';
  @override
  Severity get defaultSeverity => Severity.high;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.configuration;
  @override
  String get description =>
      'Reports debuggable release Gradle types and debuggable Android manifests.';
  @override
  String get recommendation =>
      'Set debuggable false for release builds and remove android:debuggable from the manifest.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final gradle in scope.project.gradleFiles) {
      if (gradle.releaseDebuggable) {
        findings.add(
          emit(
            this,
            scope,
            message: 'The release build type sets debuggable true.',
            path: gradle.path,
          ),
        );
      }
    }
    for (final manifest in scope.project.manifests) {
      if (manifest.debuggable) {
        findings.add(
          emit(
            this,
            scope,
            message: 'AndroidManifest sets android:debuggable="true".',
            path: manifest.path,
          ),
        );
      }
    }
    return findings;
  }
}

final class MissingEnvironmentRule implements AuditRule {
  @override
  String get id => 'FG-CFG-005';
  @override
  String get title => 'Missing environment configuration';
  @override
  String get category => 'configuration';
  @override
  Severity get defaultSeverity => Severity.low;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.configuration;
  @override
  String get description =>
      'Reports hardcoded URLs when the project shows no environment switch.';
  @override
  String get recommendation =>
      'Introduce String.fromEnvironment, a dotenv loader, or flavor configuration before shipping hosts.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final hasUrl = scope.project.dartIndex.files.any(
      (file) =>
          !file.generated &&
          !file.path.startsWith('test/') &&
          file.strings.any((literal) => _urlPattern.hasMatch(literal.value)),
    );
    if (!hasUrl) {
      return const [];
    }
    final hasEnv = scope.project.dartIndex.files.any(
      (file) => file.identifiers.contains('fromEnvironment'),
    );
    final hasDotenv = scope.project.dartIndex.files.any(
      (file) => file.importedPackages.contains('flutter_dotenv'),
    );
    final hasFile = scope.project.files.files.any(
      (file) =>
          file.relativePosix == '.env' || file.relativePosix.endsWith('/.env'),
    );
    if (hasEnv || hasDotenv || hasFile) {
      return const [];
    }
    return [
      emit(
        this,
        scope,
        message: 'Hardcoded URLs were found and no String.fromEnvironment, flutter_dotenv import, or .env file was found.',
        path: 'lib',
      ),
    ];
  }
}

final class BuildConfigurationRule implements AuditRule {
  @override
  String get id => 'FG-CFG-006';
  @override
  String get title => 'Build configuration';
  @override
  String get category => 'configuration';
  @override
  Severity get defaultSeverity => Severity.low;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.configuration;
  @override
  String get description =>
      'Reports very old minSdk values and release builds with minify disabled.';
  @override
  String get recommendation =>
      'Raise minSdk to a supported level and enable minify for release unless a documented shrinker exception exists.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final gradle in scope.project.gradleFiles) {
      final minSdk = gradle.minSdk;
      if (minSdk != null && minSdk < 21) {
        findings.add(
          emit(
            this,
            scope,
            message: 'minSdk $minSdk is below 21.',
            path: gradle.path,
            severity: Severity.medium,
          ),
        );
      }
      if (gradle.releaseMinify == false) {
        findings.add(
          emit(
            this,
            scope,
            message: 'Release minifyEnabled is false.',
            path: gradle.path,
          ),
        );
      }
    }
    return findings;
  }
}

String? _source(RuleScope scope, DartFileFacts file) {
  for (final indexed in scope.project.files.files) {
    if (indexed.relativePosix == file.path) {
      return indexed.text;
    }
  }
  return null;
}

List<AuditRule> configurationRules() => [
  HardcodedEndpointRule(),
  EnvironmentMismatchRule(),
  DuplicateIdentifierRule(),
  DebugReleaseRule(),
  MissingEnvironmentRule(),
  BuildConfigurationRule(),
];
