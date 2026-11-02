import '../analyzer/arb_parser.dart';
import '../analyzer/dart_index.dart';
import '../analyzer/gradle_parser.dart';
import '../analyzer/manifest_parser.dart';
import '../analyzer/plist_parser.dart';
import '../analyzer/pubspec_reader.dart';
import '../core/config.dart';
import '../discovery/discovery.dart';
import 'file_index.dart';

/// A display name read from a platform, plist, or web file.
final class BrandName {
  /// Creates a brand name. source and value are required.
  ///
  /// flavor defaults to null and is set when value comes from an Android
  /// product flavor.
  const BrandName({required this.source, required this.value, this.flavor});

  /// Project-relative file that contained the name.
  final String source;

  /// Display string as read from source.
  final String value;

  /// Android flavor name when value came from a flavor `app_name`.
  ///
  /// Null for manifest, plist, and web names. Defaults to null.
  final String? flavor;
}

/// Localization paths from l10n.yaml, or a marker that the file is absent.
final class L10nConfig {
  /// Creates a localization config. Every argument is required.
  const L10nConfig({
    required this.present,
    required this.arbDir,
    required this.templateArbFile,
  });

  /// True when l10n.yaml was found in the file index.
  final bool present;

  /// Trimmed `arb-dir` value, or null when that key was not matched.
  final String? arbDir;

  /// Trimmed `template-arb-file` value, or null when that key was not matched.
  final String? templateArbFile;

  /// Config used when l10n.yaml is not in the file index.
  ///
  /// present is false and both path fields are null.
  static const absent = L10nConfig(
    present: false,
    arbDir: null,
    templateArbFile: null,
  );
}

/// Immutable facts collected from one discovered Flutter project.
///
/// ```dart
/// final snapshot = const SnapshotBuilder().build(
///   project: project,
///   config: config,
/// );
/// snapshot.hasPathPrefix('android');
/// ```
final class ProjectSnapshot {
  /// Creates a snapshot. Every argument is required and is stored unchanged.
  const ProjectSnapshot({
    required this.project,
    required this.files,
    required this.dartIndex,
    required this.pubspec,
    required this.gradleFiles,
    required this.manifests,
    required this.bundleIdentifiers,
    required this.names,
    required this.arbCatalogs,
    required this.l10n,
    required this.lockedPackages,
    required this.arbitraryLoads,
    required this.emptyPrivacyKeys,
    required this.platforms,
    required this.plistErrors,
  });

  /// Discovered project this snapshot describes, including its root path.
  final DiscoveredProject project;

  /// Files indexed under the project root.
  final FileIndex files;

  /// Parsed Dart files and import cycles for the package.
  final DartIndex dartIndex;

  /// Parsed pubspec.yaml, or PubspecInfo.empty when that file was missing.
  final PubspecInfo pubspec;

  /// Gradle and Kotlin DSL files parsed from paths under `android/`.
  final List<GradleModel> gradleFiles;

  /// Parsed `AndroidManifest.xml` files.
  final List<ManifestInfo> manifests;

  /// Bundle ids from plists, pbxproj files, and xcconfig files.
  ///
  /// The builder omits values that contain `$(` and sorts the rest.
  final List<String> bundleIdentifiers;

  /// Display names from Gradle flavors, manifests, plists, and web files.
  final List<BrandName> names;

  /// Catalogs parsed from `.arb` files.
  final List<ArbCatalog> arbCatalogs;

  /// l10n.yaml settings, or L10nConfig.absent when that file was missing.
  final L10nConfig l10n;

  /// Packages pinned in pubspec.lock.
  ///
  /// The builder uses an empty list when the lockfile is missing or reading
  /// it throws FormatException.
  final List<LockedPackage> lockedPackages;

  /// True when a plist sets `NSAllowsArbitraryLoads` inside
  /// `NSAppTransportSecurity`.
  final bool arbitraryLoads;

  /// Plist keys that start with `NS`, end with `UsageDescription`, and hold
  /// a string that is empty after trimming.
  final List<String> emptyPrivacyKeys;

  /// Platform roots that contain indexed files.
  ///
  /// The builder adds `android`, `ios`, `web`, `windows`, `macos`, and
  /// `linux` when those directories are present.
  final Set<String> platforms;

  /// Plist failures formatted as `path: message`.
  final List<String> plistErrors;

  /// Whether an indexed path equals prefix or lies under that directory.
  ///
  /// When prefix does not already end with `/`, a slash is appended before
  /// the prefix test. Returns true on the first match and false when no
  /// indexed path matches.
  bool hasPathPrefix(String prefix) {
    final normalized = prefix.endsWith('/') ? prefix : '$prefix/';
    return files.files.any(
      (file) =>
          file.relativePosix == prefix ||
          file.relativePosix.startsWith(normalized),
    );
  }

  /// Whether an indexed relative path is exactly relative.
  ///
  /// Returns false when no file has that path. The comparison is exact and
  /// does not add a trailing slash.
  bool containsRelative(String relative) {
    return files.files.any((file) => file.relativePosix == relative);
  }
}

/// Builds a ProjectSnapshot by indexing a project and parsing known files.
final class SnapshotBuilder {
  /// Creates a builder that keeps no configuration of its own.
  const SnapshotBuilder();

  /// Indexes project.rootPath with config and returns the parsed snapshot.
  ///
  /// Missing pubspec.yaml becomes PubspecInfo.empty. Paths containing
  /// `android/` that end in `.gradle` or `.gradle.kts` are parsed, and each
  /// flavor `app_name` is recorded with that flavor name. Main-manifest
  /// labels, including `@string/` values resolved from `src/main/res/values`,
  /// are recorded. Debug and profile overlays are not display names. Plist
  /// files contribute `CFBundleIdentifier`, `CFBundleDisplayName` or
  /// `CFBundleName` after Xcode variables such as `PRODUCT_NAME` are resolved
  /// from `.xcconfig` and `.pbxproj`. `AppFrameworkInfo.plist` is ignored.
  /// Unresolved variables are dropped. The arbitrary-loads flag, empty
  /// `NS*UsageDescription` strings, and parse errors are still recorded.
  /// `PRODUCT_BUNDLE_IDENTIFIER` values are read from `.pbxproj` and
  /// `.xcconfig` files. Bundle ids containing `$(` are dropped and the rest
  /// are sorted. `.arb` files become catalogs. `web/manifest.json` `name`
  /// and a non-empty `web/index.html` title become brand names. l10n.yaml
  /// supplies arb-dir and template-arb-file when present. A missing
  /// pubspec.lock, or a FormatException while reading it, yields an empty
  /// package list. Walking the tree reads the filesystem and can throw
  /// FileSystemException.
  ProjectSnapshot build({
    required DiscoveredProject project,
    required FlutterGuardConfig config,
  }) {
    final files = const FileIndexer().index(
      projectRoot: project.rootPath,
      config: config,
    );
    final pubspecText = _text(files, 'pubspec.yaml');
    final pubspec = pubspecText == null
        ? PubspecInfo.empty
        : readPubspec(pubspecText);
    final dartIndex = buildDartIndex(
      files: files.files,
      packageName: pubspec.name,
    );
    final gradleFiles = <GradleModel>[];
    final manifests = <ManifestInfo>[];
    final catalogs = <ArbCatalog>[];
    final bundleIds = <String>{};
    final names = <BrandName>[];
    final buildSettings = _buildSettings(files);
    var arbitraryLoads = false;
    final emptyPrivacy = <String>[];
    final plistErrors = <String>[];
    for (final file in files.files) {
      final text = file.text;
      if (text == null) {
        continue;
      }
      final path = file.relativePosix;
      if (path.contains('android/') &&
          (path.endsWith('.gradle') || path.endsWith('.gradle.kts'))) {
        final model = parseGradle(path, text);
        gradleFiles.add(model);
        for (final flavor in model.flavors) {
          final appName = flavor.appName;
          if (appName != null) {
            names.add(
              BrandName(source: path, value: appName, flavor: flavor.name),
            );
          }
        }
      } else if (path.endsWith('AndroidManifest.xml')) {
        final manifest = parseManifest(path, text);
        manifests.add(manifest);
        if (isMainAndroidManifest(path)) {
          final label = _androidDisplayName(manifest.label, files);
          if (label != null) {
            names.add(BrandName(source: path, value: label));
          }
        }
      } else if (path.endsWith('.plist')) {
        final plist = parsePlist(text);
        if (plist.error != null) {
          plistErrors.add('$path: ${plist.error}');
        }
        final bundle = plist.string('CFBundleIdentifier');
        if (bundle != null && !bundle.contains(r'$(')) {
          bundleIds.add(bundle);
        }
        if (!isEngineFrameworkPlist(path)) {
          final display =
              plist.string('CFBundleDisplayName') ??
              plist.string('CFBundleName');
          final resolved = display == null
              ? null
              : resolveBuildVariables(
                  display,
                  buildSettings[_platformOf(path)],
                );
          if (resolved != null && resolved.isNotEmpty) {
            names.add(BrandName(source: path, value: resolved));
          }
        }
        final ats = plist.values['NSAppTransportSecurity'];
        if (ats is Map && ats['NSAllowsArbitraryLoads'] == true) {
          arbitraryLoads = true;
        }
        for (final entry in plist.values.entries) {
          if (entry.key.startsWith('NS') &&
              entry.key.endsWith('UsageDescription') &&
              entry.value is String &&
              (entry.value as String).trim().isEmpty) {
            emptyPrivacy.add(entry.key);
          }
        }
      } else if (path.endsWith('.pbxproj') || path.endsWith('.xcconfig')) {
        for (final match in RegExp(
          r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;\n]+)',
        ).allMatches(text)) {
          final value = match.group(1)!.trim().replaceAll('"', '');
          if (value.isNotEmpty && !value.contains(r'$(')) {
            bundleIds.add(value);
          }
        }
      } else if (path.endsWith('.arb')) {
        catalogs.add(parseArb(path, text));
      } else if (path == 'web/manifest.json') {
        final name = RegExp(r'"name"\s*:\s*"([^"]+)"')
            .firstMatch(text)
            ?.group(1);
        if (name != null) {
          names.add(BrandName(source: path, value: name));
        }
      } else if (path == 'web/index.html') {
        final title = RegExp(
          r'<title>([^<]+)</title>',
          caseSensitive: false,
        ).firstMatch(text)?.group(1)?.trim();
        if (title != null && title.isNotEmpty) {
          names.add(BrandName(source: path, value: title));
        }
      }
    }
    final platforms = <String>{};
    if (hasPrefix(files, 'android')) {
      platforms.add('android');
    }
    if (hasPrefix(files, 'ios')) {
      platforms.add('ios');
    }
    if (hasPrefix(files, 'web')) {
      platforms.add('web');
    }
    if (hasPrefix(files, 'windows')) {
      platforms.add('windows');
    }
    if (hasPrefix(files, 'macos')) {
      platforms.add('macos');
    }
    if (hasPrefix(files, 'linux')) {
      platforms.add('linux');
    }
    return ProjectSnapshot(
      project: project,
      files: files,
      dartIndex: dartIndex,
      pubspec: pubspec,
      gradleFiles: gradleFiles,
      manifests: manifests,
      bundleIdentifiers: bundleIds.toList()..sort(),
      names: names,
      arbCatalogs: catalogs,
      l10n: _l10n(files),
      lockedPackages: _lock(files),
      arbitraryLoads: arbitraryLoads,
      emptyPrivacyKeys: emptyPrivacy,
      platforms: platforms,
      plistErrors: plistErrors,
    );
  }

  L10nConfig _l10n(FileIndex files) {
    final text = _text(files, 'l10n.yaml');
    if (text == null) {
      return L10nConfig.absent;
    }
    String? value(String key) {
      return RegExp('$key\\s*:\\s*([^\\n#]+)')
          .firstMatch(text)
          ?.group(1)
          ?.trim();
    }

    return L10nConfig(
      present: true,
      arbDir: value('arb-dir'),
      templateArbFile: value('template-arb-file'),
    );
  }

  List<LockedPackage> _lock(FileIndex files) {
    final text = _text(files, 'pubspec.lock');
    if (text == null) {
      return const [];
    }
    try {
      return readLockFile(text);
    } on FormatException {
      return const [];
    }
  }
}

String? _text(FileIndex files, String relative) {
  for (final file in files.files) {
    if (file.relativePosix == relative) {
      return file.text;
    }
  }
  return null;
}

/// Whether files contains prefix itself or a path under that directory.
///
/// A match is a relative path equal to prefix or starting with `prefix/`
/// with the slash always appended, including when prefix already ends in
/// `/`. Returns false when nothing matches.
bool hasPrefix(FileIndex files, String prefix) {
  final normalized = '$prefix/';
  return files.files.any(
    (file) =>
        file.relativePosix == prefix ||
        file.relativePosix.startsWith(normalized),
  );
}

/// Whether [path] is the Flutter engine plist, not the app's Info.plist.
///
/// `ios/Flutter/AppFrameworkInfo.plist` sets `CFBundleName` to `App` for the
/// engine. That string is not the customer-facing display name.
bool isEngineFrameworkPlist(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.endsWith('/Flutter/AppFrameworkInfo.plist') ||
      normalized.endsWith('/AppFrameworkInfo.plist');
}

/// Replaces `$(NAME)` and `${NAME}` using [settings].
///
/// Returns null when a variable has no literal value. A value with no
/// variable is returned trimmed. Resolution stops after six substitutions.
String? resolveBuildVariables(String raw, Map<String, String>? settings) {
  var value = raw.trim();
  if (value.isEmpty) {
    return null;
  }
  final pattern = RegExp(r'\$\{([A-Za-z0-9_]+)\}|\$\(([A-Za-z0-9_]+)\)');
  for (var attempt = 0; attempt < 6; attempt++) {
    final match = pattern.firstMatch(value);
    if (match == null) {
      return value;
    }
    final key = match.group(1) ?? match.group(2)!;
    final replacement = settings?[key];
    if (replacement == null || replacement.contains(r'$')) {
      return null;
    }
    value = value.replaceRange(match.start, match.end, replacement).trim();
  }
  return pattern.hasMatch(value) ? null : value;
}

/// Customer-facing form of [value] for display-name comparison.
///
/// Lowercases and removes spaces, underscores, and hyphens so `Smoke App`
/// and `smoke_app` compare as the same name.
String canonicalDisplayName(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');
}

Map<String, Map<String, String>> _buildSettings(FileIndex files) {
  final assignment = RegExp(
    r'^\s*([A-Za-z0-9_]+)\s*=\s*([^;\n]+)',
    multiLine: true,
  );
  final collected = <String, Map<String, List<String>>>{};
  for (final file in files.files) {
    final text = file.text;
    if (text == null) {
      continue;
    }
    final path = file.relativePosix;
    if (!path.endsWith('.xcconfig') && !path.endsWith('.pbxproj')) {
      continue;
    }
    final platform = _platformOf(path);
    if (platform == null) {
      continue;
    }
    final bucket = collected.putIfAbsent(platform, () => {});
    for (final match in assignment.allMatches(text)) {
      final key = match.group(1)!;
      var setting = match.group(2)!.trim();
      if (setting.endsWith(';')) {
        setting = setting.substring(0, setting.length - 1).trim();
      }
      setting = setting.replaceAll('"', '');
      if (setting.isEmpty) {
        continue;
      }
      bucket.putIfAbsent(key, () => []).add(setting);
    }
  }
  return {
    for (final entry in collected.entries)
      entry.key: {
        for (final setting in entry.value.entries)
          setting.key: _preferLiteral(setting.value),
      },
  };
}

String _preferLiteral(List<String> values) {
  for (final value in values) {
    if (!value.contains(r'$')) {
      return value;
    }
  }
  return values.first;
}

String? _platformOf(String path) {
  final normalized = path.replaceAll('\\', '/');
  final slash = normalized.indexOf('/');
  if (slash <= 0) {
    return null;
  }
  return normalized.substring(0, slash);
}

String? _androidDisplayName(String? label, FileIndex files) {
  if (label == null) {
    return null;
  }
  final trimmed = label.trim();
  if (trimmed.isEmpty ||
      trimmed.startsWith('@') && !trimmed.startsWith('@string/')) {
    return null;
  }
  if (!trimmed.startsWith('@string/')) {
    return trimmed;
  }
  final key = trimmed.substring('@string/'.length);
  for (final file in files.files) {
    final path = file.relativePosix.replaceAll('\\', '/');
    final text = file.text;
    if (text == null || !path.endsWith('/src/main/res/values/strings.xml')) {
      continue;
    }
    final match = RegExp('<string\\s+name="$key">([^<]*)</string>')
        .firstMatch(text);
    final value = match?.group(1)?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}
