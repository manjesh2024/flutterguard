import '../core/redaction.dart';
import '../core/version.dart';
import 'formatters.dart';

/// HTML document for [report].
///
/// Includes project metadata, severity and category counts, a findings table,
/// new and resolved baseline items, suppressions, the quality gate, and
/// network status. Inserted text is HTML-escaped, and secret-shaped values
/// are redacted. No project score is included.
String renderHtml(ScanReport report) {
  final buffer = StringBuffer()
    ..writeln('<!DOCTYPE html>')
    ..writeln('<html lang="en">')
    ..writeln('<head>')
    ..writeln('<meta charset="utf-8">')
    ..writeln('<title>FlutterGuard report</title>')
    ..writeln('<style>')
    ..writeln(
      'body{font:16px/1.45 system-ui,sans-serif;margin:2rem;color:#1c1917;background:#faf7f2}'
      'h1,h2{margin:1.4rem 0 .4rem} table{border-collapse:collapse;width:100%;background:#fff}'
      'th,td{border:1px solid #d6d3d1;padding:.4rem .6rem;vertical-align:top;text-align:left}'
      'code{font-family:ui-monospace,monospace}.critical{color:#991b1b}.high{color:#9a3412}'
      '.medium{color:#a16207}.low{color:#365314}.info{color:#334155}.pass{color:#166534}.fail{color:#991b1b}',
    )
    ..writeln('</style>')
    ..writeln('</head><body>')
    ..writeln('<h1>FlutterGuard report</h1>')
    ..writeln(
      '<p>Package $packageName $packageVersion. Schema $reportSchemaVersion.</p>',
    )
    ..writeln('<h2>Project metadata</h2><ul>');
  for (final project in report.projects) {
    final platforms = project.platforms.toList()..sort();
    buffer.writeln(
      '<li>${_esc(project.project.name)} (${_esc(project.project.relativePosix)}) '
      'platforms: ${_esc(platforms.join(', '))}</li>',
    );
  }
  buffer
    ..writeln('</ul>')
    ..writeln(
      '<p>Scan timestamp: ${_esc(report.generatedAt.toUtc().toIso8601String())}</p>',
    )
    ..writeln('<p>Dart: ${_esc(report.dartVersion)}</p>')
    ..writeln(
      '<p>Flutter: ${_esc(report.flutterVersion ?? 'not available')}</p>',
    )
    ..writeln('<h2>Overall issue summary</h2>')
    ..writeln(
      '<p>Total findings: ${report.findings.length}. No project score is calculated.</p>',
    )
    ..writeln('<h2>Severity distribution</h2><ul>');
  for (final entry in report.bySeverity.entries) {
    buffer.writeln(
      '<li class="${entry.key}">${entry.key}: ${entry.value}</li>',
    );
  }
  buffer.writeln('</ul><h2>Category summaries</h2><ul>');
  if (report.byCategory.isEmpty) {
    buffer.writeln('<li>None</li>');
  }
  for (final entry in report.byCategory.entries) {
    buffer.writeln('<li>${_esc(entry.key)}: ${entry.value}</li>');
  }
  buffer
    ..writeln('</ul>')
    ..writeln('<h2>Findings</h2>')
    ..writeln(
      '<table><thead><tr><th>Severity</th><th>Rule ID</th><th>File</th><th>Line</th><th>Column</th><th>Finding</th><th>Recommendation</th><th>Baseline</th></tr></thead><tbody>',
    );
  for (final finding in report.findings) {
    buffer.writeln(
      '<tr><td class="${finding.severity.name}">${finding.severity.name}</td>'
      '<td><code>${_esc(finding.ruleId)}</code></td>'
      '<td><code>${_esc(finding.path ?? '')}</code></td>'
      '<td>${finding.line ?? ''}</td><td>${finding.column ?? ''}</td>'
      '<td>${_esc(finding.message)}'
      '${finding.heuristic ? ' <em>(heuristic)</em>' : ''}</td>'
      '<td>${_esc(finding.recommendation)}</td>'
      '<td>${finding.baselineStatus.name}</td></tr>',
    );
  }
  buffer
    ..writeln('</tbody></table>')
    ..writeln('<h2>New, existing, and resolved issues</h2>')
    ..writeln(
      '<p>Baseline enabled: ${report.baseline.enabled}. '
      'New: ${report.baseline.newFindings.length}. '
      'Existing: ${report.baseline.existing.length}. '
      'Resolved: ${report.baseline.resolved.length}.</p><ul>',
    );
  for (final finding in report.baseline.newFindings) {
    buffer.writeln(
      '<li>New ${_esc(finding.ruleId)} ${_esc(finding.path ?? '')}</li>',
    );
  }
  for (final entry in report.baseline.resolved) {
    buffer.writeln(
      '<li>Resolved ${_esc(entry.ruleId)} ${_esc(entry.path ?? '')}</li>',
    );
  }
  buffer.writeln('</ul><h2>Baseline and suppression details</h2>');
  buffer.writeln(
    '<p>Suppressions applied: ${report.suppressed.length}.</p><ul>',
  );
  for (final item in report.suppressed) {
    buffer.writeln(
      '<li>${_esc(item.finding.ruleId)} ${_esc(item.finding.path ?? '')}: ${_esc(item.reason)}</li>',
    );
  }
  buffer.writeln('</ul><h2>Quality gate</h2>');
  buffer.writeln(
    '<p class="${report.gate.passed ? 'pass' : 'fail'}">${report.gate.passed ? 'Passed' : 'Failed'}</p><ul>',
  );
  for (final reason in report.gate.reasons) {
    buffer.writeln('<li>${_esc(reason)}</li>');
  }
  buffer
    ..writeln('</ul>')
    ..writeln('<h2>Network checks</h2>')
    ..writeln('<p>Outdated: ${_esc(report.signals.outdatedStatus)}</p>')
    ..writeln(
      '<p>Vulnerabilities: ${_esc(report.signals.vulnerabilityStatus)}</p>',
    )
    ..writeln(
      '<p>Heuristic findings are signals for review, not proof of a vulnerability.</p>',
    )
    ..writeln('</body></html>');
  return redactSecrets(buffer.toString());
}

String _esc(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
