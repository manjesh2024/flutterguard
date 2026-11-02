import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/finding.dart';
import '../core/safe_path.dart';

/// One unused-import line that [AutoFixer] can remove.
final class FixPreview {
  /// Records the project-relative [path], 1-based [line], and [description].
  const FixPreview({
    required this.path,
    required this.line,
    required this.description,
  });

  /// Project-relative Dart file that contains the import.
  final String path;

  /// 1-based line of the unused import.
  final int line;

  /// Short edit description. Import removal uses `remove unused import`.
  final String description;
}

/// Outcome of previewing or applying safe import removals.
final class FixResult {
  /// Captures the edits, the write count, skip reasons, and backup location.
  ///
  /// [backupDirectory] is null when no backup was written.
  const FixResult({
    required this.previews,
    required this.applied,
    required this.skipped,
    required this.backupDirectory,
  });

  /// Import lines that matched and were removed, or would be removed.
  final List<FixPreview> previews;

  /// Number of files written. Zero when the run is a dry run.
  final int applied;

  /// Reasons a finding or line was left unchanged.
  final List<String> skipped;

  /// Project-relative backup directory, or null when nothing was written.
  final String? backupDirectory;
}

/// Removes unused-import lines that a scan marked as safe to edit.
///
/// Only findings whose fix id is `remove-unused-import` are considered. The
/// target must be a regular `.dart` file inside the project, the path must
/// not contain `..`, and the current line must still equal the fix payload.
/// A real write copies originals under `.flutterguard/backups/<stamp>` and
/// writes `manifest.json` before replacing the files.
final class AutoFixer {
  /// Creates a fixer with no retained state.
  const AutoFixer();

  /// Removes matching import lines from [findings], or only previews them.
  ///
  /// [rootPath] is the project root used to reject paths that escape it.
  /// Findings with another fix id are ignored. A finding missing a path,
  /// line, or payload, a path that is not a safe Dart file, a path that
  /// escapes [rootPath], a non-regular file, a line outside the file, or a
  /// line that no longer equals the fix payload is recorded in
  /// [FixResult.skipped]. When [dryRun] is true, no files or backups are
  /// written and [FixResult.applied] is 0. When [dryRun] is false and at
  /// least one file changes, originals are backed up and the new text is
  /// written. Throws [StateError] if the backup directory or a write target
  /// escapes the project. Returns the previews, applied file count, skip
  /// reasons, and backup directory.
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

  /// Restores files from the newest backup under `.flutterguard/backups`.
  ///
  /// [rootPath] is the project root. Returns the number of files copied back.
  /// Returns 0 when the backup directory, the latest stamp, or `manifest.json`
  /// is missing, or when the manifest is not an object with a `files` list.
  /// A listed path that is missing from the backup, or that escapes the
  /// project, is skipped. The backup directory is left in place.
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
