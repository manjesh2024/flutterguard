import 'package:yaml/yaml.dart';

/// One package declared under `dependencies` or `dev_dependencies`.
final class DependencyInfo {
  /// Creates a dependency. Every argument is required.
  ///
  /// constraint is the version string when one was written, and null when
  /// the entry has no version.
  const DependencyInfo({
    required this.name,
    required this.source,
    required this.constraint,
  });

  /// `hosted`, `sdk`, `path`, or `git`.
  final String name;

  /// Where the package is fetched from.
  ///
  /// A string entry is `hosted`. A map is `sdk` when `sdk` is set, otherwise
  /// `path` when `path` is set, otherwise `git` when `git` is set, and
  /// otherwise `hosted`.
  final String source;

  /// Version constraint. A string dependency uses that string. A map
  /// dependency uses its `version` string, or null when `version` is missing
  /// or not a string.
  final String? constraint;
}

/// Package name, dependencies, Flutter assets, and publish fields from a
/// pubspec.yaml document.
final class PubspecInfo {
  /// Creates pubspec data. Every argument is required.
  ///
  /// error is null when the document was read as a mapping.
  const PubspecInfo({
    required this.name,
    required this.dependencies,
    required this.devDependencies,
    required this.assets,
    required this.license,
    required this.publishTo,
    required this.flutterSection,
    required this.error,
  });

  /// Package `name`, or `unknown` when that field is missing or not a string.
  final String name;

  /// Packages under `dependencies`, sorted by name.
  final List<DependencyInfo> dependencies;

  /// Packages under `dev_dependencies`, sorted by name.
  final List<DependencyInfo> devDependencies;

  /// String paths under `flutter: assets:`. Non-string entries are skipped.
  final List<String> assets;

  /// `license` when it is a string; otherwise null.
  final String? license;

  /// `publish_to` when it is a string; otherwise null.
  final String? publishTo;

  /// True when the top-level `flutter` value is not null.
  final bool flutterSection;

  /// Why the document could not be read, or null when it was a mapping.
  final String? error;

  /// Placeholder for a project that has no pubspec.yaml.
  ///
  /// name is `unknown`, the lists are empty, flutterSection is false, and
  /// error is `pubspec.yaml is missing.`.
  static const empty = PubspecInfo(
    name: 'unknown',
    dependencies: [],
    devDependencies: [],
    assets: [],
    license: null,
    publishTo: null,
    flutterSection: false,
    error: 'pubspec.yaml is missing.',
  );
}

/// Reads a pubspec.yaml document from text.
///
/// Returns a result whose error is `pubspec.yaml must be a mapping.` when
/// the document is not a YAML map. YamlException is caught and its message
/// is stored in error. Both failures use the name `unknown` and empty lists.
/// Dependency lists from a successful read are sorted by package name.
PubspecInfo readPubspec(String text) {
  try {
    final loaded = loadYaml(text);
    if (loaded is! YamlMap) {
      return const PubspecInfo(
        name: 'unknown',
        dependencies: [],
        devDependencies: [],
        assets: [],
        license: null,
        publishTo: null,
        flutterSection: false,
        error: 'pubspec.yaml must be a mapping.',
      );
    }
    final flutter = loaded['flutter'];
    final assets = <String>[];
    if (flutter is YamlMap && flutter['assets'] is YamlList) {
      for (final asset in flutter['assets'] as YamlList) {
        if (asset is String) {
          assets.add(asset);
        }
      }
    }
    return PubspecInfo(
      name: loaded['name'] is String ? loaded['name'] as String : 'unknown',
      dependencies: _deps(loaded['dependencies']),
      devDependencies: _deps(loaded['dev_dependencies']),
      assets: assets,
      license: loaded['license'] is String ? loaded['license'] as String : null,
      publishTo: loaded['publish_to'] is String
          ? loaded['publish_to'] as String
          : null,
      flutterSection: flutter != null,
      error: null,
    );
  } on YamlException catch (error) {
    return PubspecInfo(
      name: 'unknown',
      dependencies: const [],
      devDependencies: const [],
      assets: const [],
      license: null,
      publishTo: null,
      flutterSection: false,
      error: error.message,
    );
  }
}

List<DependencyInfo> _deps(Object? value) {
  if (value is! YamlMap) {
    return const [];
  }
  final dependencies = <DependencyInfo>[];
  for (final key in value.keys) {
    final name = key.toString();
    final raw = value[key];
    if (raw is String) {
      dependencies.add(
        DependencyInfo(name: name, source: 'hosted', constraint: raw),
      );
      continue;
    }
    if (raw is YamlMap) {
      final source = raw['sdk'] != null
          ? 'sdk'
          : raw['path'] != null
          ? 'path'
          : raw['git'] != null
          ? 'git'
          : 'hosted';
      final constraint = raw['version'] is String
          ? raw['version'] as String
          : null;
      dependencies.add(
        DependencyInfo(name: name, source: source, constraint: constraint),
      );
    }
  }
  dependencies.sort((a, b) => a.name.compareTo(b.name));
  return dependencies;
}

/// One package pinned under `packages` in a pubspec.lock file.
final class LockedPackage {
  /// Creates a locked package. Every argument is required.
  ///
  /// direct is true when the lockfile marks the package `direct main` or
  /// `direct dev`.
  const LockedPackage({
    required this.name,
    required this.version,
    required this.direct,
  });

  /// Package name from the lockfile `packages` map.
  final String name;

  /// Version string pinned for name.
  final String version;

  /// True when the lockfile `dependency` field is `direct main` or
  /// `direct dev`.
  final bool direct;
}

/// Reads pinned packages from a pubspec.lock document.
///
/// Returns an empty list when text is not a YAML map or `packages` is not a
/// map. Entries that are not maps, or that have no string `version`, are
/// skipped. The returned list is sorted by package name. Invalid YAML throws
/// YamlException, which is a FormatException.
List<LockedPackage> readLockFile(String text) {
  final loaded = loadYaml(text);
  if (loaded is! YamlMap || loaded['packages'] is! YamlMap) {
    return const [];
  }
  final packages = loaded['packages'] as YamlMap;
  final locked = <LockedPackage>[];
  for (final key in packages.keys) {
    final value = packages[key];
    if (value is! YamlMap || value['version'] is! String) {
      continue;
    }
    final dependency = value['dependency'];
    locked.add(
      LockedPackage(
        name: key.toString(),
        version: value['version'] as String,
        direct: dependency == 'direct main' || dependency == 'direct dev',
      ),
    );
  }
  locked.sort((a, b) => a.name.compareTo(b.name));
  return locked;
}
