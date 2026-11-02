import '../analyzer/arb_parser.dart';
import '../analyzer/dart_index.dart';
import '../analyzer/gradle_parser.dart';
import '../analyzer/manifest_parser.dart';
import '../analyzer/plist_parser.dart';
import '../analyzer/pubspec_reader.dart';
import '../core/config.dart';
import '../discovery/discovery.dart';
import 'file_index.dart';

final class BrandName {
  const BrandName({required this.source, required this.value, this.flavor});

  final String source;
  final String value;
  final String? flavor;
}

final class L10nConfig {
  const L10nConfig({
    required this.present,
    required this.arbDir,
    required this.templateArbFile,
  });

  final bool present;
  final String? arbDir;
  final String? templateArbFile;

  static const absent = L10nConfig(
    present: false,
    arbDir: null,
    templateArbFile: null,
  );
}

final class ProjectSnapshot {
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

  final DiscoveredProject project;
  final FileIndex files;
  final DartIndex dartIndex;
  final PubspecInfo pubspec;
  final List<GradleModel> gradleFiles;
  final List<ManifestInfo> manifests;
  final List<String> bundleIdentifiers;
  final List<BrandName> names;
  final List<ArbCatalog> arbCatalogs;
  final L10nConfig l10n;
  final List<LockedPackage> lockedPackages;
  final bool arbitraryLoads;
  final List<String> emptyPrivacyKeys;
  final Set<String> platforms;
  final List<String> plistErrors;

  bool hasPathPrefix(String prefix) {
    final normalized = prefix.endsWith('/') ? prefix : '$prefix/';
    return files.files.any(
      (file) =>
          file.relativePosix == prefix ||
          file.relativePosix.startsWith(normalized),
    );
  }

  bool containsRelative(String relative) {
    return files.files.any((file) => file.relativePosix == relative);
  }
}

final class SnapshotBuilder {
  const SnapshotBuilder();

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
        if (manifest.label != null && !manifest.label!.startsWith('@')) {
          names.add(BrandName(source: path, value: manifest.label!));
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
        final display =
            plist.string('CFBundleDisplayName') ?? plist.string('CFBundleName');
        if (display != null) {
          names.add(BrandName(source: path, value: display));
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

bool hasPrefix(FileIndex files, String prefix) {
  final normalized = '$prefix/';
  return files.files.any(
    (file) =>
        file.relativePosix == prefix ||
        file.relativePosix.startsWith(normalized),
  );
}
