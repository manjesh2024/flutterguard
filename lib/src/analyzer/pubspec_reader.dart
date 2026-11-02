import 'package:yaml/yaml.dart';

final class DependencyInfo {
  const DependencyInfo({
    required this.name,
    required this.source,
    required this.constraint,
  });

  /// `hosted`, `sdk`, `path`, or `git`.
  final String name;
  final String source;
  final String? constraint;
}

final class PubspecInfo {
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

  final String name;
  final List<DependencyInfo> dependencies;
  final List<DependencyInfo> devDependencies;
  final List<String> assets;
  final String? license;
  final String? publishTo;
  final bool flutterSection;
  final String? error;

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

final class LockedPackage {
  const LockedPackage({
    required this.name,
    required this.version,
    required this.direct,
  });

  final String name;
  final String version;
  final bool direct;
}

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
