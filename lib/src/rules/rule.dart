import '../context/project_snapshot.dart';
import '../core/config.dart';
import '../core/finding.dart';
import '../core/redaction.dart';
import '../core/severity.dart';
import '../network/signals.dart';

/// One audit check that turns a project snapshot into findings.
///
/// Implementations must be deterministic for the same [RuleScope]. They
/// should call [emit] so messages are redacted and the configured severity
/// override is applied.
abstract interface class AuditRule {
  /// Stable id such as `FG-SEC-001`.
  String get id;

  /// Short name shown by `flutterguard rules list`.
  String get title;

  /// Module grouping used by reports, such as `security`.
  String get category;

  /// Severity used when configuration does not override [id].
  Severity get defaultSeverity;

  /// What the rule looks for, printed by `flutterguard rules explain`.
  String get description;

  /// Suggested next step. [emit] copies this onto each finding unless the
  /// caller passes a different recommendation.
  String get recommendation;

  /// Whether a hit is a review signal rather than a confirmed defect.
  bool get heuristic;

  /// Module switch that can disable this rule from configuration.
  AuditModule get module;

  /// Runs the check for one project.
  ///
  /// [scope] carries that project, the rest of the workspace, the loaded
  /// configuration, and any network signals. Returns an empty list when
  /// nothing matches. Does not write files.
  List<Finding> evaluate(RuleScope scope);
}

/// Inputs available to [AuditRule.evaluate].
final class RuleScope {
  /// Binds one [project] to the [workspace], [config], and [signals].
  const RuleScope({
    required this.project,
    required this.workspace,
    required this.config,
    required this.signals,
  });

  /// Project currently being checked.
  final ProjectSnapshot project;

  /// Every project discovered for this scan, including [project].
  ///
  /// Rules that compare identifiers across apps read this list.
  final List<ProjectSnapshot> workspace;

  /// Configuration already validated for this scan.
  final FlutterGuardConfig config;

  /// Outdated-package and advisory data for [project].
  ///
  /// Network checks are disabled unless configuration and the CLI both
  /// enable them. Disabled signals carry an empty package list.
  final ExternalSignals signals;
}

/// Builds one [Finding] for [rule] using [scope].
///
/// [message] and [recommendation] are passed through secret redaction.
/// [severity] replaces the rule default before configuration overrides are
/// applied. [heuristic] replaces [AuditRule.heuristic] when set.
///
/// [path] is a project-relative path. In a monorepo it is prefixed with the
/// project's path relative to the scan root. [line] and [column] are
/// 1-based when the hit has a source location. [enclosing] is a declaration
/// name used in the fingerprint. [fixId] and [fixPayload] are set only when
/// auto-fix knows how to edit that hit.
///
/// This function does not write the finding anywhere. The caller collects
/// the returned value.
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
