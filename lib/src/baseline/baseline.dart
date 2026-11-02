import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/exceptions.dart';
import '../core/finding.dart';
import '../core/severity.dart';
import '../core/version.dart';

/// One accepted finding stored in a baseline file.
///
/// Identity for later comparisons is [fingerprint]. [path] may be null when
/// the finding is not tied to a file. [severity] stores the severity name.
final class BaselineEntry {
  /// Creates an entry from an already computed fingerprint and message.
  ///
  /// [path] may be null. [severity] is the severity name to persist.
  const BaselineEntry({
    required this.fingerprint,
    required this.ruleId,
    required this.path,
    required this.message,
    required this.severity,
  });

  /// Stable finding identity used to match later scans against this entry.
  final String fingerprint;

  /// Rule that produced the finding.
  final String ruleId;

  /// Project-relative path, or null when the finding has no file.
  final String? path;

  /// Finding message captured when the baseline was written.
  final String message;

  /// Severity name captured when the baseline was written.
  final String severity;

  /// JSON object written into the baseline `findings` list.
  ///
  /// Keys are `fingerprint`, `ruleId`, `path`, `message`, and `severity`.
  Map<String, Object?> toJson() => {
    'fingerprint': fingerprint,
    'ruleId': ruleId,
    'path': path,
    'message': message,
    'severity': severity,
  };

  /// Copies the fingerprint, rule id, path, message, and severity name from [finding].
  static BaselineEntry fromFinding(Finding finding) {
    return BaselineEntry(
      fingerprint: finding.fingerprint,
      ruleId: finding.ruleId,
      path: finding.path,
      message: finding.message,
      severity: finding.severity.name,
    );
  }
}

/// On-disk baseline: a generation time and the accepted findings.
///
/// [toJson] adds the baseline schema version, tool name, and tool version
/// around [generatedAt] and [entries].
final class BaselineFile {
  /// Creates a baseline captured at [generatedAt] with [entries].
  ///
  /// [entries] is stored in the given order. [generatedAt] is not reformatted.
  const BaselineFile({required this.generatedAt, required this.entries});

  /// Timestamp string stored with the file, normally UTC ISO-8601.
  final String generatedAt;

  /// Accepted findings, in the order supplied to this constructor.
  final List<BaselineEntry> entries;

  /// JSON object for the baseline file, including schema and tool metadata.
  ///
  /// The `findings` array is one [BaselineEntry.toJson] object per entry.
  Map<String, Object?> toJson() => {
    'schemaVersion': baselineSchemaVersion,
    'tool': toolName,
    'toolVersion': packageVersion,
    'generatedAt': generatedAt,
    'findings': [for (final entry in entries) entry.toJson()],
  };
}

/// Result of matching a scan against a baseline file.
///
/// ```dart
/// final comparison = compareBaseline(
///   active: findings,
///   suppressedFingerprints: suppressedFingerprints,
///   baseline: readBaseline('flutterguard-baseline.json'),
/// );
/// ```
///
/// [newFindings] were not in the baseline. [existing] were already accepted.
/// [resolved] are baseline entries that are neither still active nor
/// suppressed. [compareBaseline] sets [enabled] to true; [disabled] is the
/// value used when baseline checking is off.
final class BaselineComparison {
  /// Creates a comparison without recomputing the lists.
  ///
  /// [enabled], [newFindings], [existing], and [resolved] are stored as given.
  const BaselineComparison({
    required this.enabled,
    required this.newFindings,
    required this.existing,
    required this.resolved,
  });

  /// Whether a baseline file was applied to this scan.
  final bool enabled;

  /// Active findings whose fingerprints were absent from the baseline.
  final List<Finding> newFindings;

  /// Active findings whose fingerprints were already in the baseline.
  final List<Finding> existing;

  /// Baseline entries no longer active and not currently suppressed.
  final List<BaselineEntry> resolved;

  /// Comparison used when baseline checking is turned off.
  ///
  /// [enabled] is false and [newFindings], [existing], and [resolved] are
  /// empty.
  static const disabled = BaselineComparison(
    enabled: false,
    newFindings: [],
    existing: [],
    resolved: [],
  );

  /// JSON object with `enabled`, `new`, `existing`, and `resolved` lists.
  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'new': [for (final finding in newFindings) finding.toJson()],
    'existing': [for (final finding in existing) finding.toJson()],
    'resolved': [for (final entry in resolved) entry.toJson()],
  };
}

/// Builds a [BaselineFile] from [findings], sorted by fingerprint.
///
/// [now] is converted to UTC and stored as an ISO-8601
/// [BaselineFile.generatedAt]. Entries are sorted by fingerprint. [findings]
/// itself is not modified.
BaselineFile baselineFromFindings(List<Finding> findings, DateTime now) {
  final entries = [
    for (final finding in findings) BaselineEntry.fromFinding(finding),
  ];
  entries.sort((a, b) => a.fingerprint.compareTo(b.fingerprint));
  return BaselineFile(
    generatedAt: now.toUtc().toIso8601String(),
    entries: entries,
  );
}

/// Writes [baseline] as one JSON object plus a trailing newline.
///
/// Creates missing parent directories of [path] and overwrites an existing
/// file. Does not check that [path] stays inside a project.
void writeBaseline(String path, BaselineFile baseline) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('${jsonEncode(baseline.toJson())}\n');
}

/// Reads a baseline file from [path].
///
/// Throws a configuration exception when the file is missing, is not valid
/// JSON, is not a JSON object, has a `schemaVersion` other than the supported
/// baseline schema, or has a `findings` value that is not a list. An entry
/// that is not an object, or that lacks a string `fingerprint` or `ruleId`,
/// throws and includes its index. `path` is read as a string or null, so
/// another JSON type fails that cast. A non-string `message` becomes `''`,
/// a non-string `severity` becomes the info severity name, and a non-string
/// `generatedAt` becomes `''`.
BaselineFile readBaseline(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw ConfigException(
      'Baseline file was not found: ${p.basename(path)}. '
      'Run `flutterguard baseline create` or set baseline.enabled to false.',
    );
  }
  Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    throw ConfigException('Baseline file is not valid JSON: ${error.message}');
  }
  if (decoded is! Map) {
    throw ConfigException('Baseline file must be a JSON object.');
  }
  final version = decoded['schemaVersion'];
  if (version != baselineSchemaVersion) {
    throw ConfigException(
      'Baseline schemaVersion must be $baselineSchemaVersion.',
    );
  }
  final rawFindings = decoded['findings'];
  if (rawFindings is! List) {
    throw ConfigException('Baseline findings must be a list.');
  }
  final entries = <BaselineEntry>[];
  for (var i = 0; i < rawFindings.length; i++) {
    final item = rawFindings[i];
    if (item is! Map ||
        item['fingerprint'] is! String ||
        item['ruleId'] is! String) {
      throw ConfigException(
        'Baseline findings[$i] is missing fingerprint or ruleId.',
      );
    }
    entries.add(
      BaselineEntry(
        fingerprint: item['fingerprint'] as String,
        ruleId: item['ruleId'] as String,
        path: item['path'] as String?,
        message: item['message'] is String ? item['message'] as String : '',
        severity: item['severity'] is String
            ? item['severity'] as String
            : Severity.info.name,
      ),
    );
  }
  final generatedAt = decoded['generatedAt'];
  return BaselineFile(
    generatedAt: generatedAt is String ? generatedAt : '',
    entries: entries,
  );
}

/// Splits [active] findings into new and existing issues against [baseline].
///
/// A finding whose fingerprint is in [baseline] is copied with an existing
/// baseline status into [BaselineComparison.existing]. Every other finding in
/// [active] is copied with a new-issue status into
/// [BaselineComparison.newFindings]. A baseline entry is
/// [BaselineComparison.resolved] when its fingerprint is absent from [active]
/// and from [suppressedFingerprints]. The returned comparison has enabled
/// set to true. [active] and [baseline] are not modified.
BaselineComparison compareBaseline({
  required List<Finding> active,
  required Set<String> suppressedFingerprints,
  required BaselineFile baseline,
}) {
  final activeById = {
    for (final finding in active) finding.fingerprint: finding,
  };
  final suppressedIds = suppressedFingerprints;
  final baselineIds = baseline.entries
      .map((entry) => entry.fingerprint)
      .toSet();
  final newFindings = <Finding>[];
  final existing = <Finding>[];
  for (final finding in active) {
    if (baselineIds.contains(finding.fingerprint)) {
      existing.add(finding.copyWith(baselineStatus: BaselineStatus.existing));
    } else {
      newFindings.add(
        finding.copyWith(baselineStatus: BaselineStatus.newIssue),
      );
    }
  }
  final resolved = <BaselineEntry>[
    for (final entry in baseline.entries)
      if (!activeById.containsKey(entry.fingerprint) &&
          !suppressedIds.contains(entry.fingerprint))
        entry,
  ];
  return BaselineComparison(
    enabled: true,
    newFindings: newFindings,
    existing: existing,
    resolved: resolved,
  );
}
