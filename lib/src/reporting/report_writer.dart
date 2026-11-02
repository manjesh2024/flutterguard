import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/config.dart';
import '../core/exceptions.dart';
import '../core/safe_path.dart';
import 'formatters.dart';
import 'html_reporter.dart';

/// Paths of the reports written for one scan, relative to the project.
final class WrittenReports {
  /// Stores the report directory and the four standard report paths.
  const WrittenReports({
    required this.directory,
    required this.indexHtml,
    required this.reportJson,
    required this.reportMarkdown,
    required this.reportSarif,
  });

  /// Configured report directory, not an absolute path.
  final String directory;

  /// Relative path of `index.html` inside [directory].
  final String indexHtml;

  /// Relative path of `report.json` inside [directory].
  final String reportJson;

  /// Relative path of `report.md` inside [directory].
  final String reportMarkdown;

  /// Relative path of `report.sarif` inside [directory].
  final String reportSarif;
}

/// Writes HTML, JSON, Markdown, and SARIF reports under the configured directory.
///
/// [rootPath] is the project root. The directory comes from [config] and is
/// refused when it escapes the project, which throws a configuration
/// exception. Creates the directory and overwrites `index.html`,
/// `report.json`, `report.md`, and `report.sarif`. When [config] enables
/// history, the same four files are also copied under
/// `history/<utc-timestamp>`. Returned paths stay relative to the project.
WrittenReports writeReports({
  required String rootPath,
  required FlutterGuardConfig config,
  required ScanReport report,
}) {
  final safe = SafePath(rootPath);
  final directory = safe.joinInside(config.reportDirectory);
  if (directory == null) {
    throw ConfigException(
      'reports.directory escapes the project and was refused.',
    );
  }
  final dir = Directory(directory);
  dir.createSync(recursive: true);
  final html = renderHtml(report);
  final json = renderJson(report);
  final markdown = renderMarkdown(report);
  final sarif = renderSarif(report);
  final htmlPath = p.join(directory, 'index.html');
  final jsonPath = p.join(directory, 'report.json');
  final markdownPath = p.join(directory, 'report.md');
  final sarifPath = p.join(directory, 'report.sarif');
  File(htmlPath).writeAsStringSync(html);
  File(jsonPath).writeAsStringSync(json);
  File(markdownPath).writeAsStringSync(markdown);
  File(sarifPath).writeAsStringSync(sarif);
  if (config.history) {
    final stamp = report.generatedAt.toUtc().toIso8601String().replaceAll(
      ':',
      '',
    );
    final history = Directory(p.join(directory, 'history', stamp));
    history.createSync(recursive: true);
    File(p.join(history.path, 'index.html')).writeAsStringSync(html);
    File(p.join(history.path, 'report.json')).writeAsStringSync(json);
    File(p.join(history.path, 'report.md')).writeAsStringSync(markdown);
    File(p.join(history.path, 'report.sarif')).writeAsStringSync(sarif);
  }
  return WrittenReports(
    directory: config.reportDirectory,
    indexHtml: p.join(config.reportDirectory, 'index.html'),
    reportJson: p.join(config.reportDirectory, 'report.json'),
    reportMarkdown: p.join(config.reportDirectory, 'report.md'),
    reportSarif: p.join(config.reportDirectory, 'report.sarif'),
  );
}

/// Opens [relativeHtml] under [rootPath] with the platform file opener.
///
/// macOS runs `open`, Windows runs `cmd /c start`, and other platforms run
/// `xdg-open`. The returned future completes when that process exits. The
/// file is not checked for existence before the opener is started.
Future<void> openHtmlReport(String rootPath, String relativeHtml) async {
  final full = p.join(rootPath, relativeHtml);
  if (Platform.isMacOS) {
    await Process.run('open', [full]);
  } else if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', full]);
  } else {
    await Process.run('xdg-open', [full]);
  }
}
