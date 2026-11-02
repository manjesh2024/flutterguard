import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/config.dart';
import '../core/glob.dart';
import '../core/safe_path.dart';

/// One file recorded under the project root.
final class IndexedFile {
  /// Creates an index entry. Every argument is required.
  ///
  /// text is null for a binary file or a text file over the size limit.
  /// tooLarge is true only in that oversized text case.
  const IndexedFile({
    required this.relativePosix,
    required this.size,
    required this.text,
    required this.tooLarge,
  });

  /// Path relative to the project root, using `/` separators.
  final String relativePosix;

  /// File length in bytes at the time it was indexed.
  final int size;

  /// UTF-8 contents, with malformed sequences allowed.
  ///
  /// Null when the file was treated as binary or was larger than the text
  /// limit.
  final String? text;

  /// True when text was omitted because the file exceeds the text limit.
  ///
  /// Binary files stay false even when they are large.
  final bool tooLarge;

  /// True when text was loaded.
  bool get isText => text != null;
}

/// Files accepted by the include and exclude globs, plus paths refused for
/// leaving the project root.
final class FileIndex {
  /// Creates an index. Both arguments are required and are stored as given.
  ///
  /// This constructor does not sort either list.
  const FileIndex({required this.files, required this.escapedSymlinks});

  /// Indexed files. FileIndexer sorts these by relative path.
  final List<IndexedFile> files;

  /// Relative paths left out of files because they escaped the root.
  ///
  /// Includes symlinks whose target is outside the root or could not be
  /// resolved, and files whose resolved path is outside the root. FileIndexer
  /// sorts this list.
  final List<String> escapedSymlinks;

  /// First file whose relative path ends with suffix, or null when none do.
  IndexedFile? firstEnding(String suffix) {
    for (final file in files) {
      if (file.relativePosix.endsWith(suffix)) {
        return file;
      }
    }
    return null;
  }

  /// Every file whose relative path ends with suffix, in list order.
  ///
  /// Returns an empty list when nothing matches.
  List<IndexedFile> ending(String suffix) {
    return [
      for (final file in files)
        if (file.relativePosix.endsWith(suffix)) file,
    ];
  }
}

/// Walks a project tree and builds a FileIndex.
final class FileIndexer {
  /// Creates an indexer. The filesystem is read only when index is called.
  const FileIndexer();

  /// Largest file size, in bytes, that is decoded as text.
  ///
  /// A non-binary file whose size is greater than 1500000 is stored with
  /// text null and tooLarge true. A file of exactly this size is still read.
  static const int maxTextBytes = 1500000;

  /// Indexes projectRoot using the include and exclude globs in config.
  ///
  /// Symlinks are not followed. Directory names in skippedDirectoryNames are
  /// skipped, as are directories whose relative path matches an exclude glob.
  /// A file is kept when its relative path matches an include glob and no
  /// exclude glob. Paths that start with `..` are ignored. A symlink or
  /// resolved path outside the root is recorded in escapedSymlinks and not
  /// read. Known binary extensions, and files whose first 8000 bytes contain
  /// a NUL, are stored without text. Other files at or under maxTextBytes are
  /// decoded as UTF-8 with malformed bytes allowed. Both result lists are
  /// sorted. Listing or reading a file can throw FileSystemException; a
  /// symlink that fails to resolve is recorded instead of thrown.
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
