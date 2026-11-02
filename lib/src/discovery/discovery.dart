import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../core/config.dart';
import '../core/exceptions.dart';
import '../core/safe_path.dart';

/// One Flutter package found under a scan root.
final class DiscoveredProject {
  /// Creates a project named [name] at [rootPath].
  ///
  /// [relativePosix] is the path from the scan root, using `/` separators.
  /// [usesFlutterSdk] is true when `flutter: sdk: flutter` appears in
  /// dependencies or dev_dependencies.
  const DiscoveredProject({
    required this.name,
    required this.rootPath,
    required this.relativePosix,
    required this.usesFlutterSdk,
  });

  /// Package name from pubspec.yaml, or the directory name when it is absent.
  final String name;

  /// Absolute normalized directory that contains pubspec.yaml.
  final String rootPath;

  /// Path relative to the scan root, using `/` separators. `.` at the root.
  final String relativePosix;

  /// Whether pubspec declares a Flutter SDK dependency.
  ///
  /// A project can still be discovered from a top-level `flutter:` section
  /// when this is false.
  final bool usesFlutterSdk;
}

/// Finds Flutter projects under a scan root.
///
/// ```dart
/// final projects = const ProjectDiscovery().discover(
///   rootPath: rootPath,
///   config: config,
/// );
/// ```
///
/// A Flutter project has pubspec.yaml that depends on the Flutter SDK or has
/// a top-level `flutter:` section. Configured discovery roots are used when
/// present. Otherwise single mode reads only the scan root, and other modes
/// walk the tree, then add Melos package globs and pub workspace entries.
/// Symlinks are not followed. Results are sorted by relative path.
final class ProjectDiscovery {
  /// Creates a discovery helper with no retained state.
  const ProjectDiscovery();

  /// Returns Flutter projects under [rootPath] using [config].
  ///
  /// Throws a discovery exception when [rootPath] does not exist, a configured
  /// discovery root escapes the scan path or is not a Flutter project, single
  /// mode finds nothing, monorepo mode finds nothing, or no project remains.
  /// [config] selects the mode, explicit roots, and walk depth. The filesystem
  /// is only read.
  List<DiscoveredProject> discover({
    required String rootPath,
    required FlutterGuardConfig config,
  }) {
    final root = p.normalize(Directory(rootPath).absolute.path);
    if (!Directory(root).existsSync()) {
      throw DiscoveryException('Scan path does not exist: $root');
    }
    final found = <String, DiscoveredProject>{};
    if (config.discoveryRoots.isNotEmpty) {
      for (final relative in config.discoveryRoots) {
        final candidate = p.normalize(p.join(root, relative));
        if (!p.isWithin(root, candidate) && candidate != root) {
          throw DiscoveryException(
            'Discovery root "$relative" escapes the scan path.',
          );
        }
        final project = _readProject(candidate, root);
        if (project == null) {
          throw DiscoveryException(
            'Discovery root "$relative" is not a Flutter project '
            '(no pubspec.yaml with a Flutter SDK dependency or flutter: section).',
          );
        }
        found[project.rootPath] = project;
      }
    } else if (config.discoveryMode == DiscoveryMode.single) {
      final project = _readProject(root, root);
      if (project == null) {
        throw DiscoveryException(
          'No Flutter project was found in ${p.basename(root)}. '
          'Run flutterguard from a Flutter app or pass --path.',
        );
      }
      found[project.rootPath] = project;
    } else {
      _walk(Directory(root), root, 0, config.maxDepth, found);
      _addMelosAndWorkspace(root, found);
      if (config.discoveryMode == DiscoveryMode.monorepo && found.isEmpty) {
        throw DiscoveryException(
          'Monorepo discovery found no Flutter projects under ${p.basename(root)}.',
        );
      }
    }
    if (found.isEmpty) {
      throw DiscoveryException(
        'No Flutter project was found in ${p.basename(root)}. '
        'A Flutter project needs pubspec.yaml with a flutter SDK dependency '
        'or a top-level flutter: section. Run flutterguard from an app, '
        'pass --path, or set discovery.roots.',
      );
    }
    final projects = found.values.toList()
      ..sort((a, b) => a.relativePosix.compareTo(b.relativePosix));
    return projects;
  }

  void _walk(
    Directory directory,
    String scanRoot,
    int depth,
    int maxDepth,
    Map<String, DiscoveredProject> found,
  ) {
    final project = _readProject(directory.path, scanRoot);
    if (project != null) {
      found[project.rootPath] = project;
    }
    if (depth >= maxDepth) {
      return;
    }
    final children = directory.listSync(followLinks: false);
    for (final entity in children) {
      if (entity is Link) {
        continue;
      }
      if (entity is! Directory) {
        continue;
      }
      final name = p.basename(entity.path);
      if (skippedDirectoryNames.contains(name)) {
        continue;
      }
      _walk(entity, scanRoot, depth + 1, maxDepth, found);
    }
  }

  void _addMelosAndWorkspace(
    String root,
    Map<String, DiscoveredProject> found,
  ) {
    final melos = File(p.join(root, 'melos.yaml'));
    if (melos.existsSync()) {
      final loaded = _loadYaml(melos);
      final packages = loaded is YamlMap ? loaded['packages'] : null;
      if (packages is YamlList) {
        for (final pattern in packages) {
          if (pattern is! String || pattern.contains('..')) {
            continue;
          }
          _expandPackageGlob(root, pattern, found);
        }
      }
    }
    final pubspec = File(p.join(root, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      return;
    }
    final loaded = _loadYaml(pubspec);
    if (loaded is! YamlMap) {
      return;
    }
    final workspace = loaded['workspace'];
    if (workspace is! YamlList) {
      return;
    }
    for (final entry in workspace) {
      if (entry is! String || entry.contains('..') || p.isAbsolute(entry)) {
        continue;
      }
      final candidate = p.normalize(p.join(root, entry));
      final project = _readProject(candidate, root);
      if (project != null) {
        found[project.rootPath] = project;
      }
    }
  }

  void _expandPackageGlob(
    String root,
    String pattern,
    Map<String, DiscoveredProject> found,
  ) {
    final normalized = pattern.replaceAll('\\', '/').replaceAll('**', '*');
    final star = normalized.indexOf('*');
    final prefix = star == -1 ? normalized : normalized.substring(0, star);
    final base = p.normalize(p.join(root, prefix));
    if (!p.isWithin(root, base) && base != root) {
      return;
    }
    if (!Directory(base).existsSync()) {
      return;
    }
    void consider(String directory) {
      final project = _readProject(directory, root);
      if (project != null) {
        found[project.rootPath] = project;
      }
    }

    consider(base);
    for (final entity in Directory(base).listSync(followLinks: false)) {
      if (entity is Directory) {
        consider(entity.path);
        if (normalized.contains('**') || normalized.endsWith('/*')) {
          for (final nested in entity.listSync(followLinks: false)) {
            if (nested is Directory) {
              consider(nested.path);
            }
          }
        }
      }
    }
  }

  DiscoveredProject? _readProject(String directory, String scanRoot) {
    final pubspecFile = File(p.join(directory, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      return null;
    }
    final loaded = _loadYaml(pubspecFile);
    if (loaded is! YamlMap || !_isFlutter(loaded)) {
      return null;
    }
    final name = loaded['name'];
    final safe = SafePath(scanRoot);
    if (!safe.isInside(directory)) {
      return null;
    }
    return DiscoveredProject(
      name: name is String && name.isNotEmpty ? name : p.basename(directory),
      rootPath: p.normalize(directory),
      relativePosix: directory == scanRoot
          ? '.'
          : relativePosix(scanRoot, directory),
      usesFlutterSdk:
          _hasFlutterSdk(loaded['dependencies']) ||
          _hasFlutterSdk(loaded['dev_dependencies']),
    );
  }

  bool _isFlutter(YamlMap map) {
    return _hasFlutterSdk(map['dependencies']) ||
        _hasFlutterSdk(map['dev_dependencies']) ||
        map['flutter'] != null;
  }

  bool _hasFlutterSdk(Object? dependencies) {
    if (dependencies is! YamlMap) {
      return false;
    }
    final flutter = dependencies['flutter'];
    return flutter is YamlMap && flutter['sdk'] == 'flutter';
  }

  Object? _loadYaml(File file) {
    try {
      return loadYaml(file.readAsStringSync());
    } on YamlException {
      return null;
    } on FileSystemException {
      return null;
    }
  }
}
