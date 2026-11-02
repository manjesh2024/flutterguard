import '../../core/config.dart';
import '../../core/finding.dart';
import '../../core/glob.dart';
import '../../core/severity.dart';
import '../rule.dart';

final class CustomContentRule implements AuditRule {
  CustomContentRule(this.policy);

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

List<AuditRule> customRulesFrom(FlutterGuardConfig config) {
  return [for (final policy in config.customRules) CustomContentRule(policy)];
}
