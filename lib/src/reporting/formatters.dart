import 'dart:convert';

import '../baseline/baseline.dart';
import '../context/project_snapshot.dart';
import '../core/finding.dart';
import '../core/redaction.dart';
import '../core/severity.dart';
import '../core/version.dart';
import '../network/signals.dart';
import '../quality_gate/quality_gate.dart';
import '../suppression/suppression.dart';

/// Immutable result of one scan, ready for every report format.
final class ScanReport {
  /// Stores the scan clock, toolchain, projects, findings, and gate result.
  ///
  /// Every argument is retained as given. [flutterVersion] may be null when
  /// Flutter was not found.
  const ScanReport({
    required this.generatedAt,
    required this.dartVersion,
    required this.flutterVersion,
    required this.projects,
    required this.findings,
    required this.suppressed,
    required this.baseline,
    required this.gate,
    required this.signals,
    required this.warnings,
  });

  /// Time the report was produced. Renderers print it in UTC.
  final DateTime generatedAt;

  /// Dart SDK version string captured for this scan.
  final String dartVersion;

  /// Flutter framework version, or null when Flutter was not found.
  final String? flutterVersion;

  /// Projects included in the scan.
  final List<ProjectSnapshot> projects;

  /// Findings that remain after suppression.
  final List<Finding> findings;

  /// Findings removed by config or inline suppressions, with reasons.
  final List<SuppressedFinding> suppressed;

  /// Baseline split for this scan, including a disabled comparison.
  final BaselineComparison baseline;

  /// Quality-gate pass or fail result and its reasons.
  final QualityGateResult gate;

  /// Outdated-package and vulnerability status collected for this scan.
  final ExternalSignals signals;

  /// Non-finding warnings collected while scanning.
  final List<String> warnings;

  /// Count of [findings] for each severity name, including zeroes.
  ///
  /// Keys follow report severity order. A severity with no findings is 0.
  Map<String, int> get bySeverity {
    final counts = {
      for (final severity in Severity.reportOrder) severity.name: 0,
    };
    for (final finding in findings) {
      counts.update(
        finding.severity.name,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return counts;
  }

  /// Count of [findings] by category name, with keys sorted alphabetically.
  ///
  /// Categories that do not appear in [findings] are omitted.
  Map<String, int> get byCategory {
    final counts = <String, int>{};
    for (final finding in findings) {
      counts.update(finding.category, (value) => value + 1, ifAbsent: () => 1);
    }
    final keys = counts.keys.toList()..sort();
    return {for (final key in keys) key: counts[key]!};
  }
}

/// JSON report for [report], indented with two spaces and ending in a newline.
///
/// Includes tool identity, projects, severity and category counts, findings,
/// baseline, suppressions, the quality gate, network status, and warnings.
/// Secret-shaped text is redacted before the string is returned. The document
/// states that no project score is calculated.
String renderJson(ScanReport report) {
  final document = <String, Object?>{
    'schemaVersion': reportSchemaVersion,
    'tool': {
      'name': toolName,
      'package': packageName,
      'version': packageVersion,
    },
    'generatedAt': report.generatedAt.toUtc().toIso8601String(),
    'dartVersion': report.dartVersion,
    'flutterVersion': report.flutterVersion,
    'projects': [
      for (final project in report.projects)
        {
          'name': project.project.name,
          'path': project.project.relativePosix,
          'platforms': (project.platforms.toList()..sort()),
        },
    ],
    'summary': {
      'total': report.findings.length,
      'bySeverity': report.bySeverity,
      'byCategory': report.byCategory,
    },
    'findings': [for (final finding in report.findings) finding.toJson()],
    'baseline': report.baseline.toJson(),
    'suppressions': {
      'applied': report.suppressed.length,
      'entries': [for (final item in report.suppressed) item.toJson()],
    },
    'qualityGate': report.gate.toJson(),
    'network': {
      'outdatedChecks': report.signals.outdatedStatus,
      'vulnerabilityChecks': report.signals.vulnerabilityStatus,
    },
    'warnings': report.warnings,
    'scoring': 'FlutterGuard does not calculate a project score. Counts and severities are the result.',
  };
  return redactSecrets(
    '${const JsonEncoder.withIndent('  ').convert(document)}\n',
  );
}

/// Markdown report for [report].
///
/// Sections cover projects, severity counts, categories, a finding table with
/// recommendation and heuristic notes, baseline totals, suppressions, the
/// quality gate, and network status. Table cells escape `|` and newlines.
/// Secret-shaped text is redacted before the string is returned.
String renderMarkdown(ScanReport report) {
  final buffer = StringBuffer()
    ..writeln('# FlutterGuard report')
    ..writeln()
    ..writeln('Schema version: $reportSchemaVersion')
    ..writeln('Generated: ${report.generatedAt.toUtc().toIso8601String()}')
    ..writeln('Dart: ${report.dartVersion}')
    ..writeln('Flutter: ${report.flutterVersion ?? 'not available'}')
    ..writeln()
    ..writeln('## Projects')
    ..writeln();
  for (final project in report.projects) {
    final platforms = project.platforms.toList()..sort();
    buffer.writeln(
      '- ${project.project.name} (${project.project.relativePosix}) platforms: ${platforms.join(', ')}',
    );
  }
  buffer
    ..writeln()
    ..writeln('## Summary')
    ..writeln()
    ..writeln('Total findings: ${report.findings.length}')
    ..writeln();
  for (final entry in report.bySeverity.entries) {
    buffer.writeln('- ${entry.key}: ${entry.value}');
  }
  buffer
    ..writeln()
    ..writeln('## Categories')
    ..writeln();
  for (final entry in report.byCategory.entries) {
    buffer.writeln('- ${entry.key}: ${entry.value}');
  }
  buffer
    ..writeln()
    ..writeln('## Findings')
    ..writeln()
    ..writeln('| Severity | Rule | Location | Message |')
    ..writeln('| --- | --- | --- | --- |');
  for (final finding in report.findings) {
    buffer.writeln(
      '| ${finding.severity.name} | ${finding.ruleId} | ${_location(finding)} | ${_cell(finding.message)} |',
    );
    buffer.writeln();
    buffer.writeln('Recommendation: ${_cell(finding.recommendation)}');
    buffer.writeln();
    buffer.writeln(
      'Heuristic: ${finding.heuristic}. Baseline: ${finding.baselineStatus.name}.',
    );
    buffer.writeln();
  }
  buffer
    ..writeln('## Baseline')
    ..writeln()
    ..writeln('Enabled: ${report.baseline.enabled}')
    ..writeln('New: ${report.baseline.newFindings.length}')
    ..writeln('Existing: ${report.baseline.existing.length}')
    ..writeln('Resolved: ${report.baseline.resolved.length}')
    ..writeln()
    ..writeln('## Suppressions')
    ..writeln()
    ..writeln('Applied: ${report.suppressed.length}');
  for (final item in report.suppressed) {
    buffer.writeln(
      '- ${item.finding.ruleId} ${_location(item.finding)}: ${item.reason}',
    );
  }
  buffer
    ..writeln()
    ..writeln('## Quality gate')
    ..writeln()
    ..writeln(report.gate.passed ? 'Passed.' : 'Failed.');
  for (final reason in report.gate.reasons) {
    buffer.writeln('- $reason');
  }
  buffer
    ..writeln()
    ..writeln('## Network checks')
    ..writeln()
    ..writeln('Outdated: ${report.signals.outdatedStatus}')
    ..writeln('Vulnerabilities: ${report.signals.vulnerabilityStatus}')
    ..writeln()
    ..writeln(
      'Heuristic findings are review signals, not proof of a vulnerability. No project score is calculated.',
    );
  return redactSecrets(buffer.toString());
}

/// SARIF 2.1.0 document for [report].
///
/// One run lists each distinct rule id from [report], sorted by id, and one
/// result per finding. Result level comes from the finding severity. A
/// location is omitted when a finding has no path. Secret-shaped text is
/// redacted before the string is returned.
String renderSarif(ScanReport report) {
  final rules = <String, Finding>{};
  for (final finding in report.findings) {
    rules.putIfAbsent(finding.ruleId, () => finding);
  }
  final ruleList = rules.values.toList()
    ..sort((a, b) => a.ruleId.compareTo(b.ruleId));
  final document = <String, Object?>{
    '\$schema': 'https://json.schemastore.org/sarif-2.1.0.json',
    'version': '2.1.0',
    'runs': [
      {
        'tool': {
          'driver': {
            'name': toolName,
            'version': packageVersion,
            'informationUri': 'https://github.com/manjesh2024/flutterguard',
            'rules': [
              for (final finding in ruleList)
                {
                  'id': finding.ruleId,
                  'shortDescription': {'text': finding.ruleId},
                  'fullDescription': {'text': finding.recommendation},
                  'help': {'text': finding.recommendation},
                  'properties': {
                    'category': finding.category,
                    'heuristic': finding.heuristic,
                  },
                },
            ],
          },
        },
        'results': [
          for (final finding in report.findings)
            {
              'ruleId': finding.ruleId,
              'level': finding.severity.sarifLevel,
              'message': {'text': finding.message},
              'locations': [
                if (finding.path != null)
                  {
                    'physicalLocation': {
                      'artifactLocation': {'uri': finding.path},
                      if (finding.line != null)
                        'region': {
                          'startLine': finding.line,
                          'startColumn': finding.column ?? 1,
                        },
                    },
                  },
              ],
            },
        ],
      },
    ],
  };
  return redactSecrets(
    '${const JsonEncoder.withIndent('  ').convert(document)}\n',
  );
}

/// Short terminal summary for [report].
///
/// Prints tool and toolchain versions, project names, severity counts,
/// baseline totals when the baseline is enabled, the suppression count when
/// any were applied, the quality gate, and one line per finding. An empty
/// finding list prints `No findings.`. Secret-shaped text is redacted before
/// the string is returned.
String renderTerminal(ScanReport report) {
  final buffer = StringBuffer()
    ..writeln('$toolName $packageVersion')
    ..writeln(
      'Dart ${report.dartVersion} | Flutter ${report.flutterVersion ?? 'not available'}',
    )
    ..writeln(
      'Projects: ${report.projects.map((project) => project.project.name).join(', ')}',
    )
    ..writeln(
      'Findings: ${report.findings.length} '
      '(critical: ${report.bySeverity['critical']}, '
      'high: ${report.bySeverity['high']}, '
      'medium: ${report.bySeverity['medium']}, '
      'low: ${report.bySeverity['low']}, '
      'info: ${report.bySeverity['info']})',
    );
  if (report.baseline.enabled) {
    buffer.writeln(
      'Baseline: new ${report.baseline.newFindings.length}, '
      'existing ${report.baseline.existing.length}, '
      'resolved ${report.baseline.resolved.length}',
    );
  }
  if (report.suppressed.isNotEmpty) {
    buffer.writeln('Suppressed: ${report.suppressed.length}');
  }
  buffer.writeln(
    report.gate.passed ? 'Quality gate: passed' : 'Quality gate: failed',
  );
  for (final reason in report.gate.reasons) {
    buffer.writeln('  $reason');
  }
  for (final finding in report.findings) {
    buffer.writeln(
      '  [${finding.severity.name}] ${finding.ruleId} ${_location(finding)} ${finding.message}',
    );
  }
  if (report.findings.isEmpty) {
    buffer.writeln('No findings.');
  }
  buffer.writeln(
    'Heuristic findings are review signals, not proof of a vulnerability.',
  );
  return redactSecrets(buffer.toString());
}

String _location(Finding finding) {
  final path = finding.path ?? 'project';
  if (finding.line == null) {
    return path;
  }
  return '$path:${finding.line}:${finding.column ?? 1}';
}

String _cell(String value) =>
    value.replaceAll('|', '\\|').replaceAll('\n', ' ');
