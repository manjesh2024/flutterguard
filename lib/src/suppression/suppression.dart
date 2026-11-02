import '../analyzer/dart_index.dart';
import '../context/project_snapshot.dart';
import '../core/config.dart';
import '../core/finding.dart';
import '../core/glob.dart';

final class SuppressedFinding {
  const SuppressedFinding({required this.finding, required this.reason});

  final Finding finding;
  final String reason;

  Map<String, Object?> toJson() => {
    'reason': reason,
    'finding': finding.toJson(),
  };
}

final class SuppressionResult {
  const SuppressionResult({required this.active, required this.suppressed});

  final List<Finding> active;
  final List<SuppressedFinding> suppressed;
}

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
