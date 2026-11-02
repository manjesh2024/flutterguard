import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/config.dart';
import '../core/glob.dart';
import '../core/safe_path.dart';

final class IndexedFile {
  const IndexedFile({
    required this.relativePosix,
    required this.size,
    required this.text,
    required this.tooLarge,
  });

  final String relativePosix;
  final int size;
  final String? text;
  final bool tooLarge;

  bool get isText => text != null;
}

final class FileIndex {
  const FileIndex({required this.files, required this.escapedSymlinks});

  final List<IndexedFile> files;
  final List<String> escapedSymlinks;

  IndexedFile? firstEnding(String suffix) {
    for (final file in files) {
      if (file.relativePosix.endsWith(suffix)) {
        return file;
      }
    }
    return null;
  }

  List<IndexedFile> ending(String suffix) {
    return [
      for (final file in files)
        if (file.relativePosix.endsWith(suffix)) file,
    ];
  }
}

final class FileIndexer {
  const FileIndexer();

  static const int maxTextBytes = 1500000;

  FileIndex index({
    required String projectRoot,
    required FlutterGuardConfig config,
  }) {
    final safe = SafePath(projectRoot);
    final include = [
      for (final pattern in config.include) GlobMatcher(pattern),
    ];
    final exclude = [
      for (final pattern in config.exclude) GlobMatcher(pattern),
    ];
    final files = <IndexedFile>[];
    final escaped = <String>[];
    _walk(
      directory: Directory(projectRoot),
      safe: safe,
      include: include,
      exclude: exclude,
      files: files,
      escaped: escaped,
    );
    files.sort((a, b) => a.relativePosix.compareTo(b.relativePosix));
    escaped.sort();
    return FileIndex(files: files, escapedSymlinks: escaped);
  }

  void _walk({
    required Directory directory,
    required SafePath safe,
    required List<GlobMatcher> include,
    required List<GlobMatcher> exclude,
    required List<IndexedFile> files,
    required List<String> escaped,
  }) {
    final children = directory.listSync(followLinks: false);
    for (final entity in children) {
      final name = p.basename(entity.path);
      if (entity is Link) {
        _recordLink(entity, safe, escaped);
        continue;
      }
      if (entity is Directory) {
        if (skippedDirectoryNames.contains(name)) {
          continue;
        }
        final relative = relativePosix(safe.rootPath, entity.path);
        if (anyGlobMatches(exclude, relative) ||
            anyGlobMatches(exclude, '$relative/')) {
          continue;
        }
        _walk(
          directory: entity,
          safe: safe,
          include: include,
          exclude: exclude,
          files: files,
          escaped: escaped,
        );
        continue;
      }
      if (entity is! File) {
        continue;
      }
      final relative = relativePosix(safe.rootPath, entity.path);
      if (relative.startsWith('..')) {
        continue;
      }
      if (anyGlobMatches(exclude, relative) ||
          !anyGlobMatches(include, relative)) {
        continue;
      }
      final real = safe.realInside(entity.path);
      if (real == null) {
        escaped.add(relative);
        continue;
      }
      final size = entity.lengthSync();
      if (_isBinary(relative) || _looksBinary(entity)) {
        files.add(
          IndexedFile(
            relativePosix: relative,
            size: size,
            text: null,
            tooLarge: false,
          ),
        );
        continue;
      }
      if (size > maxTextBytes) {
        files.add(
          IndexedFile(
            relativePosix: relative,
            size: size,
            text: null,
            tooLarge: true,
          ),
        );
        continue;
      }
      final bytes = entity.readAsBytesSync();
      files.add(
        IndexedFile(
          relativePosix: relative,
          size: size,
          text: utf8.decode(bytes, allowMalformed: true),
          tooLarge: false,
        ),
      );
    }
  }

  void _recordLink(Link link, SafePath safe, List<String> escaped) {
    final relative = relativePosix(safe.rootPath, link.path);
    try {
      final target = p.normalize(link.resolveSymbolicLinksSync());
      if (!safe.isRealInside(target)) {
        escaped.add(relative);
      }
    } on FileSystemException {
      escaped.add(relative);
    }
  }

  bool _isBinary(String relative) {
    const extensions = {
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.webp',
      '.ico',
      '.ttf',
      '.otf',
      '.zip',
      '.jar',
      '.so',
      '.a',
      '.dylib',
      '.pdf',
      '.wav',
      '.mp3',
      '.mp4',
    };
    final lower = relative.toLowerCase();
    for (final extension in extensions) {
      if (lower.endsWith(extension)) {
        return true;
      }
    }
    return false;
  }

  bool _looksBinary(File file) {
    final opened = file.openSync();
    try {
      final length = opened.lengthSync();
      final sample = opened.readSync(length < 8000 ? length : 8000);
      return sample.contains(0);
    } finally {
      opened.closeSync();
    }
  }
}
