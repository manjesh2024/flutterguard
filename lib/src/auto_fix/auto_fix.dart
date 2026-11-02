import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/finding.dart';
import '../core/safe_path.dart';

final class FixPreview {
  const FixPreview({
    required this.path,
    required this.line,
    required this.description,
  });

  final String path;
  final int line;
  final String description;
}

final class FixResult {
  const FixResult({
    required this.previews,
    required this.applied,
    required this.skipped,
    required this.backupDirectory,
  });

  final List<FixPreview> previews;
  final int applied;
  final List<String> skipped;
  final String? backupDirectory;
}

final class AutoFixer {
  const AutoFixer();

  FixResult apply({
    required String rootPath,
    required List<Finding> findings,
    required bool dryRun,
  }) {
    final safe = SafePath(rootPath);
    final grouped = <String, List<Finding>>{};
    final skipped = <String>[];
    for (final finding in findings) {
      if (finding.fixId != 'remove-unused-import') {
        continue;
      }
      final path = finding.path;
      final line = finding.line;
      final payload = finding.fixPayload;
      if (path == null || line == null || payload == null) {
        skipped.add('${finding.ruleId} is missing a safe edit location.');
        continue;
      }
      if (!path.endsWith('.dart') || path.contains('..')) {
        skipped.add('$path is not a safe Dart path.');
        continue;
      }
      grouped.putIfAbsent(path, () => []).add(finding);
    }
    final previews = <FixPreview>[];
    final originals = <String, String>{};
    final pending = <String, String>{};
    for (final entry in grouped.entries) {
      final absolute = safe.joinInside(entry.key);
      if (absolute == null) {
        skipped.add('${entry.key} escapes the project.');
        continue;
      }
      final type = FileSystemEntity.typeSync(absolute, followLinks: false);
      if (type == FileSystemEntityType.link ||
          type != FileSystemEntityType.file) {
        skipped.add('${entry.key} is not a regular file.');
        continue;
      }
      final file = File(absolute);
      final original = file.readAsStringSync();
      final lines = original.split('\n');
      final removals =
          entry.value.map((finding) => finding.line!).toSet().toList()
            ..sort((a, b) => b.compareTo(a));
      var next = original;
      var changed = false;
      for (final lineNumber in removals) {
        if (lineNumber < 1 || lineNumber > lines.length) {
          skipped.add('${entry.key}:$lineNumber is outside the file.');
          continue;
        }
        final finding = entry.value.firstWhere(
          (item) => item.line == lineNumber,
        );
        if (lines[lineNumber - 1].trim() != finding.fixPayload) {
          skipped.add('${entry.key}:$lineNumber no longer matches the import.');
          continue;
        }
        previews.add(
          FixPreview(
            path: entry.key,
            line: lineNumber,
            description: 'remove unused import',
          ),
        );
        lines.removeAt(lineNumber - 1);
        changed = true;
      }
      if (!changed) {
        continue;
      }
      next = lines.join('\n');
      if (!dryRun) {
        originals[entry.key] = original;
        pending[entry.key] = next;
      }
    }
    String? backup;
    if (!dryRun && originals.isNotEmpty) {
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
        ':',
        '',
      );
      final relativeBackup = p.join('.flutterguard', 'backups', stamp);
      final backupRoot = safe.joinInside(relativeBackup);
      if (backupRoot == null) {
        throw StateError('Backup directory escaped the project.');
      }
      Directory(backupRoot).createSync(recursive: true);
      for (final entry in originals.entries) {
        final destination = File(p.join(backupRoot, entry.key));
        destination.parent.createSync(recursive: true);
        destination.writeAsStringSync(entry.value);
      }
      File(p.join(backupRoot, 'manifest.json')).writeAsStringSync(
        '${jsonEncode({'files': originals.keys.toList()..sort()})}\n',
      );
      for (final entry in pending.entries) {
        final absolute = safe.joinInside(entry.key);
        if (absolute == null) {
          throw StateError('Fix target escaped the project.');
        }
        File(absolute).writeAsStringSync(entry.value);
      }
      backup = relativeBackup;
    }
    return FixResult(
      previews: previews,
      applied: dryRun ? 0 : originals.length,
      skipped: skipped,
      backupDirectory: backup,
    );
  }

  int revert(String rootPath) {
    final safe = SafePath(rootPath);
    final backupRoot = safe.joinInside(p.join('.flutterguard', 'backups'));
    if (backupRoot == null || !Directory(backupRoot).existsSync()) {
      return 0;
    }
    final stamps =
        Directory(backupRoot).listSync().whereType<Directory>().toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    if (stamps.isEmpty) {
      return 0;
    }
    final latest = stamps.first;
    final manifest = File(p.join(latest.path, 'manifest.json'));
    if (!manifest.existsSync()) {
      return 0;
    }
    final decoded = jsonDecode(manifest.readAsStringSync());
    if (decoded is! Map || decoded['files'] is! List) {
      return 0;
    }
    var restored = 0;
    for (final item in decoded['files'] as List) {
      if (item is! String) {
        continue;
      }
      final source = File(p.join(latest.path, item));
      final target = safe.joinInside(item);
      if (!source.existsSync() || target == null) {
        continue;
      }
      File(target).writeAsStringSync(source.readAsStringSync());
      restored += 1;
    }
    return restored;
  }
}
