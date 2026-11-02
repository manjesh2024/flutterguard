import 'fingerprint.dart';
import 'redaction.dart';
import 'severity.dart';

/// One audit result. Models are immutable and safe to put in reports.
final class Finding {
  const Finding({
    required this.ruleId,
    required this.severity,
    required this.message,
    required this.recommendation,
    required this.category,
    required this.heuristic,
    this.fingerprint = '',
    this.packageName,
    this.path,
    this.line,
    this.column,
    this.endLine,
    this.endColumn,
    this.enclosing,
    this.fixId,
    this.fixPayload,
    this.baselineStatus = BaselineStatus.unbaselined,
  });

  final String ruleId;
  final String fingerprint;
  final Severity severity;
  final String message;
  final String recommendation;
  final String category;
  final bool heuristic;
  final String? packageName;
  final String? path;
  final int? line;
  final int? column;
  final int? endLine;
  final int? endColumn;
  final String? enclosing;
  final String? fixId;
  final String? fixPayload;
  final BaselineStatus baselineStatus;

  Finding copyWith({
    String? fingerprint,
    Severity? severity,
    BaselineStatus? baselineStatus,
  }) {
    return Finding(
      ruleId: ruleId,
      fingerprint: fingerprint ?? this.fingerprint,
      severity: severity ?? this.severity,
      message: message,
      recommendation: recommendation,
      category: category,
      heuristic: heuristic,
      packageName: packageName,
      path: path,
      line: line,
      column: column,
      endLine: endLine,
      endColumn: endColumn,
      enclosing: enclosing,
      fixId: fixId,
      fixPayload: fixPayload,
      baselineStatus: baselineStatus ?? this.baselineStatus,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'fingerprint': fingerprint,
      'ruleId': ruleId,
      'severity': severity.name,
      'category': category,
      'heuristic': heuristic,
      'message': redactSecrets(message),
      'recommendation': redactSecrets(recommendation),
      'package': packageName,
      'path': path,
      'line': line,
      'column': column,
      'endLine': endLine,
      'endColumn': endColumn,
      'enclosing': enclosing,
      'baselineStatus': baselineStatus.name,
      'fixId': fixId,
    };
  }
}

enum BaselineStatus { unbaselined, newIssue, existing, resolved }

int compareFindings(Finding left, Finding right) {
  final byRule = left.ruleId.compareTo(right.ruleId);
  if (byRule != 0) {
    return byRule;
  }
  final byPath = (left.path ?? '').compareTo(right.path ?? '');
  if (byPath != 0) {
    return byPath;
  }
  final byLine = (left.line ?? 0).compareTo(right.line ?? 0);
  if (byLine != 0) {
    return byLine;
  }
  final byColumn = (left.column ?? 0).compareTo(right.column ?? 0);
  if (byColumn != 0) {
    return byColumn;
  }
  return left.message.compareTo(right.message);
}

/// Assigns deterministic fingerprints. Duplicate identities in one
/// declaration receive a stable numeric suffix based on source order.
List<Finding> assignFingerprints(List<Finding> findings) {
  final sorted = [...findings]..sort(compareFindings);
  final groups = <String, int>{};
  return [
    for (final finding in sorted)
      finding.copyWith(fingerprint: _fingerprintFor(finding, groups)),
  ];
}

String _fingerprintFor(Finding finding, Map<String, int> groups) {
  final key = [
    finding.ruleId,
    finding.path ?? '',
    finding.message.trim(),
    finding.enclosing ?? '',
  ].join('|');
  final index = groups.update(key, (value) => value + 1, ifAbsent: () => 0);
  return buildFingerprint(
    ruleId: finding.ruleId,
    path: finding.path,
    message: finding.message,
    enclosing: finding.enclosing,
    duplicateIndex: index,
  );
}
