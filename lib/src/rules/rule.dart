import '../context/project_snapshot.dart';
import '../core/config.dart';
import '../core/finding.dart';
import '../core/redaction.dart';
import '../core/severity.dart';
import '../network/signals.dart';

abstract interface class AuditRule {
  String get id;
  String get title;
  String get category;
  Severity get defaultSeverity;
  String get description;
  String get recommendation;
  bool get heuristic;
  AuditModule get module;

  List<Finding> evaluate(RuleScope scope);
}

final class RuleScope {
  const RuleScope({
    required this.project,
    required this.workspace,
    required this.config,
    required this.signals,
  });

  final ProjectSnapshot project;
  final List<ProjectSnapshot> workspace;
  final FlutterGuardConfig config;
  final ExternalSignals signals;
}

Finding emit(
  AuditRule rule,
  RuleScope scope, {
  required String message,
  String? path,
  int? line,
  int? column,
  String? enclosing,
  String? fixId,
  String? fixPayload,
  Severity? severity,
  bool? heuristic,
  String? recommendation,
}) {
  return Finding(
    ruleId: rule.id,
    severity: scope.config.severityFor(
      rule.id,
      severity ?? rule.defaultSeverity,
    ),
    message: redactSecrets(message),
    recommendation: redactSecrets(recommendation ?? rule.recommendation),
    category: rule.category,
    heuristic: heuristic ?? rule.heuristic,
    packageName: scope.project.project.name,
    path: _scopedPath(scope, path),
    line: line,
    column: column,
    enclosing: enclosing,
    fixId: fixId,
    fixPayload: fixPayload,
  );
}

String? _scopedPath(RuleScope scope, String? path) {
  if (path == null) {
    return null;
  }
  final root = scope.project.project.relativePosix;
  if (root == '.' || root.isEmpty) {
    return path;
  }
  return '$root/$path';
}
