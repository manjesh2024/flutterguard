import 'fingerprint.dart';
import 'redaction.dart';
import 'severity.dart';

/// One audit result. Models are immutable and safe to put in reports.
///
/// ```dart
/// final finding = Finding(
///   ruleId: 'FG-SEC-001',
///   severity: Severity.high,
///   message: 'Possible secret was redacted.',
///   recommendation: 'Move the value out of source.',
///   category: 'security',
///   heuristic: true,
///   path: 'lib/keys.dart',
///   line: 12,
/// );
/// ```
final class Finding {
  /// Creates a finding for [ruleId] at [severity].
  ///
  /// [message] and [recommendation] are stored as given. Callers that go
  /// through `emit` have already redacted secret-shaped text. [category]
  /// groups the hit in reports. [heuristic] is true when the hit is a review
  /// signal rather than a confirmed defect.
  ///
  /// [fingerprint] is empty until [assignFingerprints] runs. [packageName]
  /// is the Flutter package that contained the hit. [path] is relative to
  /// the scan root. [line], [column], [endLine], and [endColumn] are 1-based
  /// source positions and are null when the hit has no span. [enclosing] is
  /// the declaration used to keep fingerprints stable. [fixId] and
  /// [fixPayload] are set only for hits auto-fix knows how to edit.
  /// [baselineStatus] defaults to [BaselineStatus.unbaselined].
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

  /// Stable rule id, such as `FG-SEC-001`.
  final String ruleId;

  /// Identity used by baselines and suppressions.
  ///
  /// Empty until [assignFingerprints] fills it. The value is a hash of the
  /// rule, path, message, enclosing declaration, and a duplicate index.
  final String fingerprint;

  /// Severity after configuration overrides.
  final Severity severity;

  /// What was found. Secret-shaped substrings are already redacted in reports.
  final String message;

  /// Suggested next step for the reader of the report.
  final String recommendation;

  /// Report grouping, such as `security` or `platform`.
  final String category;

  /// Whether this hit is a heuristic review signal.
  final bool heuristic;

  /// Flutter package name that produced the hit, when discovery knew one.
  final String? packageName;

  /// Path relative to the scan root, using `/` separators.
  final String? path;

  /// 1-based line of the hit, or null when the hit is not tied to a line.
  final int? line;

  /// 1-based column of the hit, or null when the hit has no column.
  final int? column;

  /// 1-based end line of the hit, or null when the span is unknown.
  final int? endLine;

  /// 1-based end column of the hit, or null when the span is unknown.
  final int? endColumn;

  /// Declaration or member name included in the fingerprint.
  final String? enclosing;

  /// Auto-fix identifier, or null when this hit cannot be edited.
  final String? fixId;

  /// Auto-fix payload understood by the fixer for [fixId].
  final String? fixPayload;

  /// Relationship to the baseline. Unset findings use
  /// [BaselineStatus.unbaselined].
  final BaselineStatus baselineStatus;

  /// Returns a copy with a new fingerprint, severity, or baseline status.
  ///
  /// Omitted arguments keep the current value. No other field changes.
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

  /// JSON object for `report.json`.
  ///
  /// `message` and `recommendation` are redacted again. `fixPayload` is not
  /// included. Null location fields are encoded as JSON null.
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

/// How a finding relates to the accepted baseline.
enum BaselineStatus {
  /// No baseline comparison was applied.
  unbaselined,

  /// The fingerprint was not in the baseline.
  newIssue,

  /// The fingerprint was already accepted in the baseline.
  existing,

  /// A baseline entry no longer appears in the active results.
  resolved,
}

/// Orders findings for stable reports and fingerprints.
///
/// Compares [left] and [right] by rule id, path, line, column, then message.
/// Null paths sort before non-null paths. Null lines and columns sort as 0.
/// Returns a negative number when [left] comes first.
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
