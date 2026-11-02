import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/exceptions.dart';
import '../core/finding.dart';
import '../core/severity.dart';
import '../core/version.dart';

final class BaselineEntry {
  const BaselineEntry({
    required this.fingerprint,
    required this.ruleId,
    required this.path,
    required this.message,
    required this.severity,
  });

  final String fingerprint;
  final String ruleId;
  final String? path;
  final String message;
  final String severity;

  Map<String, Object?> toJson() => {
    'fingerprint': fingerprint,
    'ruleId': ruleId,
    'path': path,
    'message': message,
    'severity': severity,
  };

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

final class BaselineFile {
  const BaselineFile({required this.generatedAt, required this.entries});

  final String generatedAt;
  final List<BaselineEntry> entries;

  Map<String, Object?> toJson() => {
    'schemaVersion': baselineSchemaVersion,
    'tool': toolName,
    'toolVersion': packageVersion,
    'generatedAt': generatedAt,
    'findings': [for (final entry in entries) entry.toJson()],
  };
}

final class BaselineComparison {
  const BaselineComparison({
    required this.enabled,
    required this.newFindings,
    required this.existing,
    required this.resolved,
  });

  final bool enabled;
  final List<Finding> newFindings;
  final List<Finding> existing;
  final List<BaselineEntry> resolved;

  static const disabled = BaselineComparison(
    enabled: false,
    newFindings: [],
    existing: [],
    resolved: [],
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'new': [for (final finding in newFindings) finding.toJson()],
    'existing': [for (final finding in existing) finding.toJson()],
    'resolved': [for (final entry in resolved) entry.toJson()],
  };
}

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

void writeBaseline(String path, BaselineFile baseline) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('${jsonEncode(baseline.toJson())}\n');
}

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
