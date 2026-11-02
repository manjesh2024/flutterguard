import '../core/finding.dart';
import '../core/redaction.dart';
import '../core/severity.dart';
import '../core/version.dart';
import 'formatters.dart';

/// HTML dashboard for [report].
///
/// The document is self-contained: styles and behavior are inline, and the
/// only links are the JSON, Markdown, and SARIF files written beside it.
/// Inserted text is HTML-escaped, and secret-shaped values are redacted.
/// No project score is included.
String renderHtml(ScanReport report) {
  final buffer = StringBuffer()
    ..writeln('<!DOCTYPE html>')
    ..writeln('<html lang="en">')
    ..writeln('<head>')
    ..writeln('<meta charset="utf-8">')
    ..writeln(
      '<meta name="viewport" content="width=device-width, initial-scale=1">',
    )
    ..writeln('<title>FlutterGuard report</title>')
    ..writeln('<style>')
    ..writeln(_css)
    ..writeln('</style>')
    ..writeln('</head>')
    ..writeln('<body>')
    ..writeln('<a class="skip" href="#findings">Skip to findings</a>')
    ..writeln('<header class="top">')
    ..writeln('<div>')
    ..writeln('<p class="eyebrow">FlutterGuard</p>')
    ..writeln('<h1>Audit report</h1>')
    ..writeln(
      '<p class="lede">$packageName $packageVersion · schema $reportSchemaVersion</p>',
    )
    ..writeln('</div>')
    ..writeln(
      '<button type="button" id="theme" aria-pressed="false">Theme</button>',
    )
    ..writeln('</header>')
    ..writeln('<main>');

  _metadata(buffer, report);
  _exports(buffer);
  _severity(buffer, report);
  _categories(buffer, report);
  _findings(buffer, report);
  _baseline(buffer, report);
  _gate(buffer, report);
  _network(buffer, report);

  buffer
    ..writeln('</main>')
    ..writeln('<script>')
    ..writeln(_script)
    ..writeln('</script>')
    ..writeln('</body></html>');
  return redactSecrets(buffer.toString());
}

void _metadata(StringBuffer buffer, ScanReport report) {
  buffer
    ..writeln('<section aria-labelledby="metadata-heading">')
    ..writeln('<h2 id="metadata-heading">Project metadata</h2>')
    ..writeln('<div class="meta-grid">');
  if (report.projects.isEmpty) {
    buffer.writeln('<p>No projects were included.</p>');
  }
  for (final project in report.projects) {
    final platforms = project.platforms.toList()..sort();
    buffer.writeln(
      '<article><h3>${_esc(project.project.name)}</h3>'
      '<p>${_esc(project.project.relativePosix)}</p>'
      '<p>Platforms: ${_esc(platforms.isEmpty ? 'none detected' : platforms.join(', '))}</p>'
      '</article>',
    );
  }
  buffer
    ..writeln('</div>')
    ..writeln('<h2>Scan metadata</h2>')
    ..writeln('<dl class="facts">')
    ..writeln(
      '<div><dt>Scan timestamp</dt><dd>${_esc(report.generatedAt.toUtc().toIso8601String())}</dd></div>',
    )
    ..writeln('<div><dt>Dart</dt><dd>${_esc(report.dartVersion)}</dd></div>')
    ..writeln(
      '<div><dt>Flutter</dt><dd>${_esc(report.flutterVersion ?? 'not available')}</dd></div>',
    )
    ..writeln(
      '<div><dt>Findings</dt><dd>${report.findings.length}. No project score is calculated.</dd></div>',
    )
    ..writeln('</dl></section>');
}

void _exports(StringBuffer buffer) {
  buffer
    ..writeln('<section aria-labelledby="export-heading">')
    ..writeln('<h2 id="export-heading">Exports</h2>')
    ..writeln('<ul class="exports">')
    ..writeln('<li><a href="report.json">JSON</a></li>')
    ..writeln('<li><a href="report.md">Markdown</a></li>')
    ..writeln('<li><a href="report.sarif">SARIF</a></li>')
    ..writeln('</ul></section>');
}

void _severity(StringBuffer buffer, ScanReport report) {
  buffer
    ..writeln('<section aria-labelledby="severity-heading">')
    ..writeln('<h2 id="severity-heading">Severity distribution</h2>')
    ..writeln('<div class="cards">');
  for (final severity in Severity.reportOrder) {
    final count = report.bySeverity[severity.name] ?? 0;
    buffer.writeln(
      '<article class="card ${severity.name}">'
      '<p class="count">$count</p>'
      '<h3>${severity.name}</h3>'
      '</article>',
    );
  }
  buffer.writeln('</div></section>');
}

void _categories(StringBuffer buffer, ScanReport report) {
  buffer
    ..writeln('<section aria-labelledby="category-heading">')
    ..writeln('<h2 id="category-heading">Category summaries</h2>');
  if (report.byCategory.isEmpty) {
    buffer.writeln('<p>None</p></section>');
    return;
  }
  final maxCount = report.byCategory.values.fold<int>(
    1,
    (max, count) => count > max ? count : max,
  );
  buffer.writeln('<ul class="bars">');
  for (final entry in report.byCategory.entries) {
    final width = (entry.value / maxCount * 100).round();
    buffer.writeln(
      '<li><span class="bar-label">${_esc(entry.key)}</span>'
      '<span class="bar" style="width:$width%"></span>'
      '<span class="bar-count">${entry.value}</span></li>',
    );
  }
  buffer.writeln('</ul></section>');
}

void _findings(StringBuffer buffer, ScanReport report) {
  final categories = report.byCategory.keys.toList();
  buffer
    ..writeln('<section id="findings" aria-labelledby="findings-heading">')
    ..writeln('<h2 id="findings-heading">Findings</h2>')
    ..writeln('<div class="filters">')
    ..writeln(
      '<label>Search <input id="search" type="search" placeholder="Rule, file, or message"></label>',
    )
    ..writeln('<label>Severity <select id="severity-filter">')
    ..writeln('<option value="">All</option>');
  for (final severity in Severity.reportOrder) {
    buffer.writeln(
      '<option value="${severity.name}">${severity.name}</option>',
    );
  }
  buffer
    ..writeln('</select></label>')
    ..writeln('<label>Category <select id="category-filter">')
    ..writeln('<option value="">All</option>');
  for (final category in categories) {
    buffer.writeln(
      '<option value="${_esc(category)}">${_esc(category)}</option>',
    );
  }
  buffer
    ..writeln('</select></label>')
    ..writeln('<p id="visible-count" aria-live="polite"></p>')
    ..writeln('</div>')
    ..writeln('<div class="table-wrap">')
    ..writeln('<table>')
    ..writeln('<caption>Audit findings</caption>')
    ..writeln('<thead><tr>')
    ..writeln(
      '<th><button type="button" data-sort="severity">Severity</button></th>',
    )
    ..writeln(
      '<th><button type="button" data-sort="rule">Rule ID</button></th>',
    )
    ..writeln('<th><button type="button" data-sort="file">File</button></th>')
    ..writeln('<th><button type="button" data-sort="line">Line</button></th>')
    ..writeln(
      '<th><button type="button" data-sort="finding">Finding</button></th>',
    )
    ..writeln(
      '<th><button type="button" data-sort="baseline">Baseline</button></th>',
    )
    ..writeln('</tr></thead><tbody>');
  if (report.findings.isEmpty) {
    buffer.writeln('<tr class="empty"><td colspan="6">No findings.</td></tr>');
  }
  for (final finding in report.findings) {
    final search = [
      finding.ruleId,
      finding.severity.name,
      finding.category,
      finding.path ?? '',
      finding.message,
      finding.recommendation,
      _baselineLabel(finding.baselineStatus),
    ].join(' ').toLowerCase();
    buffer.writeln(
      '<tr data-severity="${finding.severity.name}" '
      'data-category="${_esc(finding.category)}" '
      'data-rule="${_esc(finding.ruleId)}" '
      'data-file="${_esc(finding.path ?? '')}" '
      'data-line="${finding.line ?? 0}" '
      'data-finding="${_esc(finding.message)}" '
      'data-baseline="${_esc(_baselineLabel(finding.baselineStatus))}" '
      'data-search="${_esc(search)}">',
    );
    buffer.writeln(
      '<td><span class="pill ${finding.severity.name}">${finding.severity.name}</span></td>'
      '<td><code>${_esc(finding.ruleId)}</code></td>'
      '<td><code>${_esc(finding.path ?? '')}</code></td>'
      '<td>${finding.line ?? ''}</td>'
      '<td><details>'
      '<summary>${_esc(finding.message)}'
      '${finding.heuristic ? ' (heuristic)' : ''}</summary>'
      '<p><strong>Recommendation.</strong> ${_esc(finding.recommendation)}</p>'
      '<p>Category: ${_esc(finding.category)}. '
      'Baseline status: ${_esc(_baselineLabel(finding.baselineStatus))}.</p>'
      '</details></td>'
      '<td>${_esc(_baselineLabel(finding.baselineStatus))}</td>',
    );
    buffer.writeln('</tr>');
  }
  buffer.writeln('</tbody></table></div></section>');
}

void _baseline(StringBuffer buffer, ScanReport report) {
  buffer
    ..writeln('<section aria-labelledby="baseline-heading">')
    ..writeln(
      '<h2 id="baseline-heading">New, existing, and resolved issues</h2>',
    )
    ..writeln(
      '<p>Baseline status: ${report.baseline.enabled ? 'enabled' : 'not enabled'}. '
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
  buffer.writeln('</ul></section>');
}

void _gate(StringBuffer buffer, ScanReport report) {
  buffer
    ..writeln('<section aria-labelledby="gate-heading">')
    ..writeln('<h2 id="gate-heading">Quality gate</h2>')
    ..writeln(
      '<p class="${report.gate.passed ? 'pass' : 'fail'}">${report.gate.passed ? 'Passed' : 'Failed'}</p><ul>',
    );
  for (final reason in report.gate.reasons) {
    buffer.writeln('<li>${_esc(reason)}</li>');
  }
  buffer.writeln('</ul></section>');
}

void _network(StringBuffer buffer, ScanReport report) {
  buffer
    ..writeln('<section aria-labelledby="network-heading">')
    ..writeln('<h2 id="network-heading">Network checks</h2>')
    ..writeln('<p>Outdated: ${_esc(report.signals.outdatedStatus)}</p>')
    ..writeln(
      '<p>Vulnerabilities: ${_esc(report.signals.vulnerabilityStatus)}</p>',
    )
    ..writeln(
      '<p>Heuristic findings are signals for review, not proof of a vulnerability.</p>',
    )
    ..writeln('</section>');
}

String _baselineLabel(BaselineStatus status) {
  switch (status) {
    case BaselineStatus.newIssue:
      return 'new';
    case BaselineStatus.existing:
      return 'existing';
    case BaselineStatus.resolved:
      return 'resolved';
    case BaselineStatus.unbaselined:
      return 'unbaselined';
  }
}

String _esc(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

const _css = r'''
:root {
  color-scheme: light;
  --bg: #f4f6f8;
  --surface: #ffffff;
  --text: #142033;
  --muted: #3e4c63;
  --line: #d5dbe3;
  --accent: #1d4ed8;
  --focus: #1d4ed8;
  --critical: #7f1d1d;
  --critical-bg: #fee2e2;
  --high: #9a3412;
  --high-bg: #ffedd5;
  --medium: #854d0e;
  --medium-bg: #fef9c3;
  --low: #166534;
  --low-bg: #dcfce7;
  --info: #1e3a8a;
  --info-bg: #dbeafe;
  --pass: #166534;
  --fail: #991b1b;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    color-scheme: dark;
    --bg: #10151c;
    --surface: #1a222d;
    --text: #f4f7fb;
    --muted: #c5d0de;
    --line: #334155;
    --accent: #93c5fd;
    --focus: #93c5fd;
    --critical: #fecdd3;
    --critical-bg: #4c0519;
    --high: #fed7aa;
    --high-bg: #431407;
    --medium: #fde68a;
    --medium-bg: #422006;
    --low: #bbf7d0;
    --low-bg: #052e16;
    --info: #bfdbfe;
    --info-bg: #172554;
    --pass: #86efac;
    --fail: #fca5a5;
  }
}
:root[data-theme="dark"] {
  color-scheme: dark;
  --bg: #10151c;
  --surface: #1a222d;
  --text: #f4f7fb;
  --muted: #c5d0de;
  --line: #334155;
  --accent: #93c5fd;
  --focus: #93c5fd;
  --critical: #fecdd3;
  --critical-bg: #4c0519;
  --high: #fed7aa;
  --high-bg: #431407;
  --medium: #fde68a;
  --medium-bg: #422006;
  --low: #bbf7d0;
  --low-bg: #052e16;
  --info: #bfdbfe;
  --info-bg: #172554;
  --pass: #86efac;
  --fail: #fca5a5;
}
:root[data-theme="light"] { color-scheme: light; }
* { box-sizing: border-box; }
body {
  margin: 0;
  background: var(--bg);
  color: var(--text);
  font: 16px/1.5 "Segoe UI", system-ui, sans-serif;
}
.skip {
  position: absolute;
  left: 0.75rem;
  top: -3rem;
  background: var(--surface);
  color: var(--text);
  padding: 0.4rem 0.7rem;
}
.skip:focus { top: 0.75rem; z-index: 2; }
.top, main { max-width: 1100px; margin: 0 auto; padding: 1.25rem; }
.top { display: flex; justify-content: space-between; gap: 1rem; align-items: flex-end; }
.eyebrow { margin: 0; color: var(--muted); letter-spacing: 0.04em; text-transform: uppercase; font-size: 0.78rem; }
h1 { margin: 0.15rem 0; font-size: 2rem; }
h2 { margin: 0 0 0.75rem; font-size: 1.25rem; }
h3 { margin: 0 0 0.25rem; font-size: 1rem; }
.lede, p { color: var(--text); }
section {
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: 12px;
  padding: 1rem;
  margin: 0 0 1rem;
}
.meta-grid, .cards { display: grid; gap: 0.75rem; }
.meta-grid { grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); }
.cards { grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); }
article, .card {
  border: 1px solid var(--line);
  border-radius: 10px;
  padding: 0.75rem;
}
.count { margin: 0; font-size: 1.8rem; font-weight: 700; }
.card.critical { background: var(--critical-bg); color: var(--critical); }
.card.high { background: var(--high-bg); color: var(--high); }
.card.medium { background: var(--medium-bg); color: var(--medium); }
.card.low { background: var(--low-bg); color: var(--low); }
.card.info { background: var(--info-bg); color: var(--info); }
.facts { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 0.75rem; margin: 0; }
.facts div { border-top: 1px solid var(--line); padding-top: 0.4rem; }
dt { color: var(--muted); font-size: 0.85rem; }
dd { margin: 0.15rem 0 0; }
.exports { display: flex; flex-wrap: wrap; gap: 0.5rem; list-style: none; padding: 0; margin: 0; }
.exports a, button, select, input {
  font: inherit;
  color: var(--text);
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: 8px;
  padding: 0.4rem 0.7rem;
}
.exports a { text-decoration: none; }
.exports a:hover, button:hover { border-color: var(--accent); }
.filters { display: flex; flex-wrap: wrap; gap: 0.75rem; align-items: end; margin-bottom: 0.75rem; }
label { display: grid; gap: 0.25rem; color: var(--muted); font-size: 0.9rem; }
.table-wrap { overflow-x: auto; }
table { width: 100%; border-collapse: collapse; min-width: 720px; }
caption { text-align: left; color: var(--muted); margin-bottom: 0.4rem; }
th, td { border-bottom: 1px solid var(--line); padding: 0.55rem; text-align: left; vertical-align: top; }
th button { border: 0; background: transparent; padding: 0; font-weight: 700; cursor: pointer; }
.pill { display: inline-block; border-radius: 999px; padding: 0.1rem 0.5rem; background: var(--line); }
.pill.critical { background: var(--critical-bg); color: var(--critical); }
.pill.high { background: var(--high-bg); color: var(--high); }
.pill.medium { background: var(--medium-bg); color: var(--medium); }
.pill.low { background: var(--low-bg); color: var(--low); }
.pill.info { background: var(--info-bg); color: var(--info); }
code { font-family: ui-monospace, monospace; font-size: 0.9em; }
details summary { cursor: pointer; }
.bars { list-style: none; padding: 0; margin: 0; }
.bars li { display: grid; grid-template-columns: minmax(8rem, 12rem) 1fr auto; gap: 0.5rem; align-items: center; margin: 0.35rem 0; }
.bar { display: block; height: 0.7rem; background: var(--accent); border-radius: 999px; min-width: 0.4rem; }
.pass { color: var(--pass); font-weight: 700; }
.fail { color: var(--fail); font-weight: 700; }
:focus-visible { outline: 3px solid var(--focus); outline-offset: 2px; }
@media (max-width: 640px) {
  h1 { font-size: 1.5rem; }
  .top { flex-direction: column; align-items: flex-start; }
  .bars li { grid-template-columns: 1fr auto; }
  .bar { grid-column: 1 / -1; }
}
''';

const _script = r'''
(function () {
  var root = document.documentElement;
  var button = document.getElementById("theme");
  var stored = null;
  try { stored = localStorage.getItem("flutterguard-theme"); } catch (error) {}
  if (stored === "light" || stored === "dark") {
    root.setAttribute("data-theme", stored);
    button.setAttribute("aria-pressed", stored === "dark" ? "true" : "false");
  }
  button.addEventListener("click", function () {
    var current = root.getAttribute("data-theme");
    var dark = current === "dark" || (current !== "light" && window.matchMedia("(prefers-color-scheme: dark)").matches);
    var next = dark ? "light" : "dark";
    root.setAttribute("data-theme", next);
    button.setAttribute("aria-pressed", next === "dark" ? "true" : "false");
    try { localStorage.setItem("flutterguard-theme", next); } catch (error) {}
  });

  var rows = Array.prototype.slice.call(document.querySelectorAll("tbody tr"));
  var search = document.getElementById("search");
  var severity = document.getElementById("severity-filter");
  var category = document.getElementById("category-filter");
  var count = document.getElementById("visible-count");
  function applyFilters() {
    var query = (search.value || "").toLowerCase();
    var wantedSeverity = severity.value;
    var wantedCategory = category.value;
    var visible = 0;
    rows.forEach(function (row) {
      if (row.classList.contains("empty")) { return; }
      var text = row.getAttribute("data-search") || "";
      var show = text.indexOf(query) !== -1 &&
        (!wantedSeverity || row.getAttribute("data-severity") === wantedSeverity) &&
        (!wantedCategory || row.getAttribute("data-category") === wantedCategory);
      row.hidden = !show;
      if (show) { visible += 1; }
    });
    if (count) { count.textContent = visible + " shown"; }
  }
  search.addEventListener("input", applyFilters);
  severity.addEventListener("change", applyFilters);
  category.addEventListener("change", applyFilters);
  applyFilters();

  var direction = 1;
  var active = "";
  document.querySelectorAll("th button[data-sort]").forEach(function (header) {
    header.addEventListener("click", function () {
      var key = header.getAttribute("data-sort");
      direction = active === key ? direction * -1 : 1;
      active = key;
      var body = document.querySelector("tbody");
      var sortable = rows.filter(function (row) { return !row.classList.contains("empty"); });
      var rank = { critical: 5, high: 4, medium: 3, low: 2, info: 1 };
      sortable.sort(function (left, right) {
        var a = left.getAttribute("data-" + key) || "";
        var b = right.getAttribute("data-" + key) || "";
        if (key === "line") { return (Number(a) - Number(b)) * direction; }
        if (key === "severity") { return ((rank[a] || 0) - (rank[b] || 0)) * direction; }
        return a.localeCompare(b) * direction;
      });
      sortable.forEach(function (row) { body.appendChild(row); });
      document.querySelectorAll("th").forEach(function (cell) { cell.removeAttribute("aria-sort"); });
      header.parentElement.setAttribute("aria-sort", direction > 0 ? "ascending" : "descending");
    });
  });
})();
''';
