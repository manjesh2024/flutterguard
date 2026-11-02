import '../../core/config.dart';
import '../../core/finding.dart';
import '../../core/glob.dart';
import '../../core/severity.dart';
import '../rule.dart';

/// Audit rule built from one user-configured text search.
///
/// Evaluation keeps files whose relative path matches the globs on [policy]
/// and that have readable text. The first index of the policy's search text
/// becomes a finding on that line, using the policy message, recommendation,
/// severity, category, and heuristic flag.
final class CustomContentRule implements AuditRule {
  /// Creates a rule that searches for the text declared by [policy].
  CustomContentRule(this.policy);

  /// User policy that supplies the id, message, file globs, and search text.
  final CustomRulePolicy policy;

  @override
  String get id => policy.id;
  @override
  String get title => policy.message;
  @override
  String get category => policy.category;
  @override
  Severity get defaultSeverity => policy.severity;
  @override
  bool get heuristic => policy.heuristic;
  @override
  AuditModule get module => AuditModule.configuration;
  @override
  String get description => policy.message;
  @override
  String get recommendation => policy.recommendation;

  @override
  List<Finding> evaluate(RuleScope scope) {
    final matchers = [
      for (final pattern in policy.fileGlobs) GlobMatcher(pattern),
    ];
    final findings = <Finding>[];
    for (final file in scope.project.files.files) {
      final text = file.text;
      if (text == null || !anyGlobMatches(matchers, file.relativePosix)) {
        continue;
      }
      final index = text.indexOf(policy.contains);
      if (index < 0) {
        continue;
      }
      final line = text.substring(0, index).split('\n').length;
      findings.add(
        emit(
          this,
          scope,
          message: policy.message,
          path: file.relativePosix,
          line: line,
          recommendation: policy.recommendation,
        ),
      );
    }
    return findings;
  }
}

/// Builds one [CustomContentRule] for each custom rule on [config].
///
/// The list follows configuration order and is empty when [config] declares
/// no custom rules.
List<AuditRule> customRulesFrom(FlutterGuardConfig config) {
  return [for (final policy in config.customRules) CustomContentRule(policy)];
}
