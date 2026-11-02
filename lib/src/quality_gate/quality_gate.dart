import '../baseline/baseline.dart';
import '../core/config.dart';
import '../core/finding.dart';

final class QualityGateResult {
  const QualityGateResult({required this.passed, required this.reasons});

  final bool passed;
  final List<String> reasons;

  Map<String, Object?> toJson() => {'passed': passed, 'reasons': reasons};
}

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
