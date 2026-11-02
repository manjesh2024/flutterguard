import '../baseline/baseline.dart';
import '../core/config.dart';
import '../core/finding.dart';

/// Outcome of comparing findings with the configured quality gate.
final class QualityGateResult {
  /// Records whether the gate [passed] and the human-readable [reasons].
  ///
  /// [reasons] is empty when [passed] is true.
  const QualityGateResult({required this.passed, required this.reasons});

  /// Whether every configured gate condition was satisfied.
  final bool passed;

  /// Explanations for a failed gate, in the order the checks ran.
  ///
  /// Empty when [passed] is true.
  final List<String> reasons;

  /// JSON object with `passed` and `reasons` for the scan report.
  Map<String, Object?> toJson() => {'passed': passed, 'reasons': reasons};
}

/// Evaluates [config] against the findings that will appear in the report.
///
/// [findings] are the reported findings after suppression and, when a
/// baseline is enabled, after baseline filtering. [baseline] supplies the
/// new-finding counts used by `failOnNew` and `maxNewFindings`.
///
/// The gate fails when any reported finding has a severity in
/// `config.failOn`, when `maxFindings` is set and [findings] is longer, or
/// when the baseline is enabled and the new-finding limits fail. It does
/// not throw. A failed gate is represented by [QualityGateResult.passed]
/// set to false.
QualityGateResult evaluateGate({
  required FlutterGuardConfig config,
  required List<Finding> findings,
  required BaselineComparison baseline,
}) {
  final reasons = <String>[];
  final blocking = findings
      .where((finding) => config.failOn.contains(finding.severity))
      .length;
  if (blocking > 0) {
    final names = config.failOn.map((severity) => severity.name).join(', ');
    reasons.add('$blocking finding(s) at severity $names.');
  }
  final maxFindings = config.maxFindings;
  if (maxFindings != null && findings.length > maxFindings) {
    reasons.add('${findings.length} findings exceed maxFindings $maxFindings.');
  }
  if (baseline.enabled && config.failOnNew) {
    final blockingNew = baseline.newFindings
        .where((finding) => config.failOn.contains(finding.severity))
        .length;
    final maxNew = config.maxNewFindings;
    if (maxNew != null && baseline.newFindings.length > maxNew) {
      reasons.add(
        '${baseline.newFindings.length} new findings exceed maxNewFindings $maxNew.',
      );
    } else if (maxNew == null && blockingNew > 0) {
      reasons.add('$blockingNew new finding(s) are at a failing severity.');
    }
  }
  return QualityGateResult(passed: reasons.isEmpty, reasons: reasons);
}
