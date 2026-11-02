import 'dart:io';

import 'package:path/path.dart' as p;

import 'exceptions.dart';

/// Path helpers that refuse to leave a project root through `..` or symlinks.
///
/// The lexical root and the symlink-resolved root are both kept. On macOS a
/// temp directory under `/var` resolves to `/private/var`, and treating that
/// as an escape would skip every real file.
final class SafePath {
  /// Normalizes [root] to an absolute lexical path and a resolved root.
  ///
  /// [realRoot] uses the symlink-resolved directory when [root] exists.
  /// Otherwise, or when resolution fails, [realRoot] is the absolute lexical
  /// path.
  SafePath(String root)
    : rootPath = p.normalize(Directory(root).absolute.path),
      realRoot = _resolve(root);

  /// Absolute lexical project root, with `.` and `..` normalized.
  final String rootPath;

  /// Symlink-resolved project root, or [rootPath] when resolution fails.
  final String realRoot;

  /// Whether [candidate] is [rootPath] or a lexical descendant of it.
  ///
  /// [candidate] is normalized to an absolute path. Symlinks are not resolved.
  bool isInside(String candidate) {
    final normalized = p.normalize(p.absolute(candidate));
    return normalized == rootPath || p.isWithin(rootPath, normalized);
  }

  /// Whether [candidate] is [realRoot] or a descendant of the resolved root.
  ///
  /// [candidate] is normalized to an absolute path. Symlinks inside
  /// [candidate] are not resolved here.
  bool isRealInside(String candidate) {
    final normalized = p.normalize(p.absolute(candidate));
    return normalized == realRoot || p.isWithin(realRoot, normalized);
  }

  /// Resolves [relativePath] against the root. Returns null when the
  /// candidate escapes the root. Does not follow the final symlink.
  String? joinInside(String relativePath) {
    if (p.isAbsolute(relativePath)) {
      return isInside(relativePath) ? p.normalize(relativePath) : null;
    }
    final joined = p.normalize(p.join(rootPath, relativePath));
    if (!isInside(joined)) {
      return null;
    }
    return joined;
  }

  /// Real path of [candidate] when it exists and stays inside the root.
  /// Returns null for a symlink so callers do not follow it implicitly.
  String? realInside(String candidate) {
    final normalized = p.normalize(p.absolute(candidate));
    if (!isInside(normalized)) {
      return null;
    }
    final type = FileSystemEntity.typeSync(normalized, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      return normalized;
    }
    if (type == FileSystemEntityType.link) {
      return null;
    }
    try {
      final real = p.normalize(
        type == FileSystemEntityType.directory
            ? Directory(normalized).resolveSymbolicLinksSync()
            : File(normalized).resolveSymbolicLinksSync(),
      );
      if (!isRealInside(real)) {
        return null;
      }
      return real;
    } on FileSystemException {
      return null;
    }
  }

  /// Resolves [relativeOrAbsolute] and throws when it leaves the project.
  ///
  /// An absolute path must already be inside [rootPath]. A relative path is
  /// joined with [joinInside]. [description] is included in the configuration
  /// exception. Returns the normalized absolute path on success.
  String requireInside(
    String relativeOrAbsolute, {
    required String description,
  }) {
    final resolved = p.isAbsolute(relativeOrAbsolute)
        ? (isInside(relativeOrAbsolute)
              ? p.normalize(relativeOrAbsolute)
              : null)
        : joinInside(relativeOrAbsolute);
    if (resolved == null) {
      throw ConfigException(
        '$description resolves outside the project root and was refused.',
      );
    }
    return resolved;
  }

  static String _resolve(String root) {
    final directory = Directory(root);
    try {
      if (directory.existsSync()) {
        return p.normalize(directory.resolveSymbolicLinksSync());
      }
    } on FileSystemException {
      // Use the lexical path when the root cannot be resolved.
    }
    return p.normalize(directory.absolute.path);
  }
}

/// Converts `\` to `/` in [value].
///
/// Does not normalize `.` or `..` and does not check the filesystem.
String toPosix(String value) => value.replaceAll('\\', '/');

/// Path of [file] relative to [root], with `/` separators.
///
/// Both paths are normalized before the relative path is computed.
String relativePosix(String root, String file) {
  final relative = p.relative(p.normalize(file), from: p.normalize(root));
  return toPosix(relative);
}
