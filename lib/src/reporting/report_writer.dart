import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/config.dart';
import '../core/exceptions.dart';
import '../core/safe_path.dart';
import 'formatters.dart';
import 'html_reporter.dart';

final class WrittenReports {
  const WrittenReports({
    required this.directory,
    required this.indexHtml,
    required this.reportJson,
    required this.reportMarkdown,
    required this.reportSarif,
  });

  final String directory;
  final String indexHtml;
  final String reportJson;
  final String reportMarkdown;
  final String reportSarif;
}

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
