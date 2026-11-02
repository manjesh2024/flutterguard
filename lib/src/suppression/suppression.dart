import '../analyzer/dart_index.dart';
import '../context/project_snapshot.dart';
import '../core/config.dart';
import '../core/finding.dart';
import '../core/glob.dart';

/// A finding removed from the active set, with the reason that matched.
final class SuppressedFinding {
  /// Pairs [finding] with the suppression [reason] that hid it.
  const SuppressedFinding({required this.finding, required this.reason});

  /// Finding that will not appear in the active report.
  final Finding finding;

  /// Reason from the matching config entry or inline ignore comment.
  final String reason;

  /// JSON object with `reason` and the nested finding document.
  Map<String, Object?> toJson() => {
    'reason': reason,
    'finding': finding.toJson(),
  };
}

/// Active findings and the findings removed by suppression.
final class SuppressionResult {
  /// Stores [active] findings and the [suppressed] ones with reasons.
  const SuppressionResult({required this.active, required this.suppressed});

  /// Findings that no config entry or inline ignore matched.
  final List<Finding> active;

  /// Findings matched by a config suppression or a valid inline ignore.
  final List<SuppressedFinding> suppressed;
}

/// Splits [findings] into active and suppressed using config and inline ignores.
///
/// Config suppressions are checked first. A policy matches when its rule and
/// fingerprint are either unset or equal to the finding, and when its path
/// glob is unset or matches the finding path. Inline ignores apply only when
/// the finding has a line, the ignore names the same rule and path, and the
/// ignore sits on that line or the line above. [projects] supplies the inline
/// comments. Both returned lists keep input order. [findings] is not modified.
SuppressionResult applySuppressions({
  required List<Finding> findings,
  required FlutterGuardConfig config,
  required List<ProjectSnapshot> projects,
}) {
  final inline = <InlineIgnore>[];
  final inlinePaths = <InlineIgnore, String>{};
  for (final project in projects) {
    for (final file in project.dartIndex.files) {
      for (final ignore in file.ignores.where((item) => item.valid)) {
        inline.add(ignore);
        final root = project.project.relativePosix;
        final path = root == '.' ? file.path : '$root/${file.path}';
        inlinePaths[ignore] = path;
      }
    }
  }
  final active = <Finding>[];
  final suppressed = <SuppressedFinding>[];
  for (final finding in findings) {
    final reason = _reason(finding, config, inline, inlinePaths);
    if (reason == null) {
      active.add(finding);
    } else {
      suppressed.add(SuppressedFinding(finding: finding, reason: reason));
    }
  }
  return SuppressionResult(active: active, suppressed: suppressed);
}

String? _reason(
  Finding finding,
  FlutterGuardConfig config,
  List<InlineIgnore> inline,
  Map<InlineIgnore, String> inlinePaths,
) {
  for (final policy in config.suppressions) {
    if (policy.rule != null && policy.rule != finding.ruleId) {
      continue;
    }
    if (policy.fingerprint != null &&
        policy.fingerprint != finding.fingerprint) {
      continue;
    }
    if (policy.path != null) {
      final path = finding.path;
      if (path == null || !GlobMatcher(policy.path!).matches(path)) {
        continue;
      }
    }
    return policy.reason;
  }
  final line = finding.line;
  if (line == null) {
    return null;
  }
  for (final ignore in inline) {
    if (ignore.ruleId != finding.ruleId ||
        inlinePaths[ignore] != finding.path) {
      continue;
    }
    if (ignore.line == line || ignore.line == line - 1) {
      return ignore.reason;
    }
  }
  return null;
}
