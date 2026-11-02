import 'dart:io';

import 'package:path/path.dart' as p;

import 'exceptions.dart';

/// Path helpers that refuse to leave a project root through `..` or symlinks.
///
/// The lexical root and the symlink-resolved root are both kept. On macOS a
/// temp directory under `/var` resolves to `/private/var`, and treating that
/// as an escape would skip every real file.
final class SafePath {
  SafePath(String root)
    : rootPath = p.normalize(Directory(root).absolute.path),
      realRoot = _resolve(root);

  final String rootPath;
  final String realRoot;

  bool isInside(String candidate) {
    final normalized = p.normalize(p.absolute(candidate));
    return normalized == rootPath || p.isWithin(rootPath, normalized);
  }

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

String toPosix(String value) => value.replaceAll('\\', '/');

String relativePosix(String root, String file) {
  final relative = p.relative(p.normalize(file), from: p.normalize(root));
  return toPosix(relative);
}
