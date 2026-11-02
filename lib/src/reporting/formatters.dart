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

final class ScanReport {
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

  final DateTime generatedAt;
  final String dartVersion;
  final String? flutterVersion;
  final List<ProjectSnapshot> projects;
  final List<Finding> findings;
  final List<SuppressedFinding> suppressed;
  final BaselineComparison baseline;
  final QualityGateResult gate;
  final ExternalSignals signals;
  final List<String> warnings;

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

  Map<String, int> get byCategory {
    final counts = <String, int>{};
    for (final finding in findings) {
      counts.update(finding.category, (value) => value + 1, ifAbsent: () => 1);
    }
    final keys = counts.keys.toList()..sort();
    return {for (final key in keys) key: counts[key]!};
  }
}

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
