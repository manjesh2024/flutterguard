import 'exceptions.dart';
import 'glob.dart';
import 'severity.dart';

/// How Flutter projects are found when discovery roots are empty.
///
/// When discovery roots are set, those directories are the project list.
enum DiscoveryMode {
  /// Walks the scan tree up to maxDepth and adds Melos and pub workspace
  /// members.
  auto,

  /// Uses only the scan root, and fails when that directory is not a Flutter
  /// project.
  single,

  /// Walks the scan tree up to maxDepth, adds Melos and pub workspace
  /// members, and fails with a monorepo error when no project is found.
  monorepo,
}

/// Kind of report file a scan can write.
enum ReportFormat {
  /// HTML report written as `index.html`.
  html,

  /// JSON report written as `report.json`.
  json,

  /// Markdown report written as `report.md`.
  markdown,

  /// SARIF report written as `report.sarif`.
  sarif,
}

/// Group of audit rules that can be enabled or disabled together.
enum AuditModule {
  /// Application ids, display names, launcher icons, flavors, and assets.
  branding,

  /// Endpoints, environments, identifiers, debug flags, and build settings.
  configuration,

  /// Layer imports, cycles, UI logic, database access, and feature coupling.
  architecture,

  /// Complexity, size, debug leftovers, async patterns, and parse errors.
  codeQuality,

  /// Secrets, logging, HTTP, TLS, storage, permissions, and symlinks.
  security,

  /// ARB catalogs, placeholders, locales, and hardcoded user-facing strings.
  localization,

  /// Unused, outdated, deprecated, licensed, sourced, and advisory checks.
  dependencies,

  /// Android, iOS, web, Windows, macOS, and Linux project checks.
  platform,
}

/// One architecture layer and the other layers it may import.
final class LayerPolicy {
  /// Creates a layer named [name] whose files match [paths].
  ///
  /// [mayImport] lists other layer names this layer is allowed to import.
  /// Every parameter is required.
  const LayerPolicy({
    required this.name,
    required this.paths,
    required this.mayImport,
  });

  /// Name referenced by other layers' mayImport lists and by findings.
  final String name;

  /// Glob patterns that assign a file to this layer.
  final List<String> paths;

  /// Names of other layers this layer may import.
  ///
  /// Imports that stay inside this layer are allowed even when the list is
  /// empty.
  final List<String> mayImport;
}

/// Import-layer and feature-boundary settings for architecture rules.
final class ArchitecturePolicy {
  /// Creates a policy for [profile].
  ///
  /// [layers] is the layer list. [featureCoupling] turns cross-feature import
  /// checks on or off. [businessLogicComplexity] is the cyclomatic-complexity
  /// threshold for methods in UI files. Every parameter is required.
  const ArchitecturePolicy({
    required this.profile,
    required this.layers,
    required this.featureCoupling,
    required this.businessLogicComplexity,
  });

  /// Profile name: `none`, `clean`, `featureFirst`, or `custom`.
  final String profile;

  /// Layers whose import direction can be enforced.
  final List<LayerPolicy> layers;

  /// Whether imports across `lib/features` folders are checked.
  ///
  /// The check allows another feature's public barrel
  /// `lib/features/<name>/<name>.dart` and reports other cross-feature
  /// imports.
  final bool featureCoupling;

  /// Cyclomatic complexity at which a non-build method in a UI file is
  /// reported.
  ///
  /// A method is reported when its complexity is greater than or equal to
  /// this value.
  final int businessLogicComplexity;

  /// Whether layer import direction is enforced.
  ///
  /// Returns true when [profile] is not `none` and [layers] is not empty.
  bool get enforcesLayers => profile != 'none' && layers.isNotEmpty;
}

/// Size and complexity limits used by code-quality rules.
final class CodeQualityPolicy {
  /// Creates the thresholds that size and complexity rules compare against.
  ///
  /// A method is reported when its cyclomatic complexity is greater than
  /// [complexityThreshold], a class when its line count is greater than
  /// [classLineThreshold], and a method when its line count is greater than
  /// [methodLineThreshold]. Every parameter is required.
  const CodeQualityPolicy({
    required this.complexityThreshold,
    required this.classLineThreshold,
    required this.methodLineThreshold,
  });

  /// Cyclomatic complexity above which a method is reported.
  final int complexityThreshold;

  /// Class length, in lines, above which a class is reported.
  final int classLineThreshold;

  /// Method length, in lines, above which a method is reported.
  final int methodLineThreshold;
}

/// A configured match that moves a finding out of the active report.
final class SuppressionPolicy {
  /// Creates a suppression.
  ///
  /// [rule], [path], and [fingerprint] may be null; a null field matches any
  /// finding, and every non-null field must match. [reason] is required and
  /// is stored with the suppressed finding.
  const SuppressionPolicy({
    required this.rule,
    required this.path,
    required this.fingerprint,
    required this.reason,
  });

  /// Rule id that must match, or null to accept any rule.
  final String? rule;

  /// Glob matched against the finding path, or null to accept any path.
  final String? path;

  /// Fingerprint that must match, or null to accept any fingerprint.
  final String? fingerprint;

  /// Explanation recorded when this suppression matches a finding.
  final String reason;
}

/// A content rule that reports a literal substring in selected files.
final class CustomRulePolicy {
  /// Creates a custom content rule.
  ///
  /// [id], [severity], [category], [message], and [recommendation] are copied
  /// onto each finding. [fileGlobs] selects files, and [contains] is the
  /// literal substring those files are searched for. [heuristic] is copied
  /// onto the finding. Every parameter is required.
  const CustomRulePolicy({
    required this.id,
    required this.severity,
    required this.category,
    required this.message,
    required this.recommendation,
    required this.fileGlobs,
    required this.contains,
    required this.heuristic,
  });

  /// Rule id reported with each match.
  final String id;

  /// Severity used when the rule setting does not replace it.
  final Severity severity;

  /// Grouping label copied onto each finding.
  final String category;

  /// Text reported when [contains] occurs in a selected file.
  final String message;

  /// Remediation text copied onto each finding.
  final String recommendation;

  /// Glob patterns that select the files to search.
  final List<String> fileGlobs;

  /// Literal substring that triggers a finding.
  ///
  /// The scan searches file text for this exact value.
  final String contains;

  /// Whether each match is marked as a heuristic finding.
  final bool heuristic;
}

/// Enablement and optional severity for one rule id.
final class RuleSetting {
  /// Creates a per-rule setting.
  ///
  /// [enabled] is required. [severity] defaults to null, which leaves
  /// severity selection to severity overrides and the rule's own severity.
  const RuleSetting({required this.enabled, this.severity});

  /// Whether the rule runs.
  final bool enabled;

  /// Replacement severity, or null to leave the severity unchanged here.
  final Severity? severity;
}

/// Versioned, immutable project configuration.
///
/// ```dart
/// final config = FlutterGuardConfig.defaults();
/// final securityOn = config.moduleEnabled(AuditModule.security);
/// ```
final class FlutterGuardConfig {
  /// Creates a configuration that stores every required argument.
  ///
  /// Each named parameter is required and is kept as given. Call [defaults]
  /// for the built-in values.
  const FlutterGuardConfig({
    required this.discoveryMode,
    required this.discoveryRoots,
    required this.maxDepth,
    required this.include,
    required this.exclude,
    required this.modules,
    required this.architecture,
    required this.codeQuality,
    required this.allowedHosts,
    required this.severityOverrides,
    required this.minSeverity,
    required this.suppressions,
    required this.baselineEnabled,
    required this.baselinePath,
    required this.failOnNew,
    required this.reportDirectory,
    required this.reportFormats,
    required this.history,
    required this.openHtml,
    required this.failOn,
    required this.maxFindings,
    required this.maxNewFindings,
    required this.outdatedChecks,
    required this.vulnerabilityChecks,
    required this.customRules,
    required this.ruleSettings,
    required this.requiredLocales,
  });

  /// How projects are located when [discoveryRoots] is empty.
  final DiscoveryMode discoveryMode;

  /// Project-relative directories scanned instead of walking the tree.
  ///
  /// When this list is empty, [discoveryMode] chooses the search.
  final List<String> discoveryRoots;

  /// How many directory levels below the scan root a walk may descend.
  ///
  /// A value of 0 reads only the starting directory. [defaults] uses 4.
  /// Auto and monorepo discovery use this limit.
  final int maxDepth;

  /// Glob patterns of files the scan reads.
  ///
  /// [defaults] uses [defaultIncludes].
  final List<String> include;

  /// Glob patterns of files the scan skips.
  ///
  /// [defaults] uses [defaultExcludes].
  final List<String> exclude;

  /// Whether each audit module runs.
  ///
  /// [moduleEnabled] treats a missing entry as enabled. [defaults] enables
  /// every module.
  final Map<AuditModule, bool> modules;

  /// Layer, feature-coupling, and UI-complexity policy.
  final ArchitecturePolicy architecture;

  /// Thresholds used by complexity and size rules.
  final CodeQualityPolicy codeQuality;

  /// Hosts that cleartext-HTTP and hardcoded-endpoint checks ignore.
  ///
  /// Comparison is case-insensitive. Endpoint checks also ignore a subdomain
  /// of a listed host. [defaults] uses [defaultAllowedHosts].
  final List<String> allowedHosts;

  /// Per-rule severity replacements, keyed by rule id.
  ///
  /// [severityFor] uses an entry when the rule setting has no severity.
  /// [defaults] uses an empty map.
  final Map<String, Severity> severityOverrides;

  /// Lowest severity retained in the report.
  ///
  /// Findings with a lower rank are dropped. [defaults] uses info, which
  /// keeps every rank.
  final Severity minSeverity;

  /// Configured matches that move findings out of the active report.
  ///
  /// [defaults] uses an empty list.
  final List<SuppressionPolicy> suppressions;

  /// Whether findings are compared with a saved baseline.
  ///
  /// When false, the scan skips baseline reading and reports the current
  /// active findings. [defaults] uses false.
  final bool baselineEnabled;

  /// Project-relative path of the baseline file.
  ///
  /// [defaults] uses `.flutterguard-baseline.json`.
  final String baselinePath;

  /// Whether new baseline findings can fail the quality gate.
  ///
  /// Applied only when [baselineEnabled] is true. If [maxNewFindings] is
  /// null, new findings whose severity is in [failOn] fail the gate.
  /// [defaults] uses true.
  final bool failOnNew;

  /// Directory, relative to the scan root, where reports are written.
  ///
  /// [defaults] uses `build/flutterguard`.
  final String reportDirectory;

  /// Formats named by the reports configuration.
  ///
  /// [defaults] lists html, json, markdown, and sarif.
  final List<ReportFormat> reportFormats;

  /// Whether a timestamped copy of the reports is written under `history/`.
  ///
  /// [defaults] uses false.
  final bool history;

  /// Whether the HTML report is opened after it is written.
  ///
  /// A failure to open the file is recorded as a scan warning. [defaults]
  /// uses false.
  final bool openHtml;

  /// Severities that fail the quality gate when a finding has one of them.
  ///
  /// [defaults] uses high and critical.
  final Set<Severity> failOn;

  /// Maximum reported findings before the quality gate fails.
  ///
  /// Null skips this limit. [defaults] uses null.
  final int? maxFindings;

  /// Maximum new baseline findings before the quality gate fails.
  ///
  /// Null uses the [failOn] check described on [failOnNew] instead of a
  /// count. The count is applied only when baseline comparison is enabled
  /// and [failOnNew] is true. [defaults] uses null.
  final int? maxNewFindings;

  /// Whether the scan may run `dart pub outdated`.
  ///
  /// An offline run leaves the check disabled. [defaults] uses false.
  final bool outdatedChecks;

  /// Whether the scan may query vulnerability advisories for locked packages.
  ///
  /// An offline run leaves the check disabled. [defaults] uses false.
  final bool vulnerabilityChecks;

  /// User-defined content rules evaluated with the built-in rules.
  ///
  /// [defaults] uses an empty list.
  final List<CustomRulePolicy> customRules;

  /// Per-rule enablement and optional severity, keyed by rule id.
  ///
  /// [ruleEnabled] treats a missing entry as enabled. [defaults] uses an
  /// empty map.
  final Map<String, RuleSetting> ruleSettings;

  /// Locale identifiers that must have a localization catalog.
  ///
  /// An empty list adds no required locales. [defaults] uses an empty list.
  final List<String> requiredLocales;

  /// Whether [module] runs.
  ///
  /// Returns the entry in [modules], or true when [module] is absent.
  bool moduleEnabled(AuditModule module) => modules[module] ?? true;

  /// Whether the rule identified by [ruleId] runs.
  ///
  /// Returns that rule's enabled flag, or true when [ruleId] has no
  /// [RuleSetting].
  bool ruleEnabled(String ruleId) => ruleSettings[ruleId]?.enabled ?? true;

  /// Severity to report for [ruleId].
  ///
  /// Returns the rule setting's severity when it is non-null, otherwise the
  /// [severityOverrides] entry for [ruleId], otherwise [fallback].
  Severity severityFor(String ruleId, Severity fallback) {
    return ruleSettings[ruleId]?.severity ??
        severityOverrides[ruleId] ??
        fallback;
  }

  /// Returns the built-in configuration.
  ///
  /// Discovery mode is auto, max depth is 4, and every module is enabled.
  /// Architecture profile is `none`, with feature coupling on and a UI
  /// complexity threshold of 12. Code-quality thresholds are 15, 300, and 80.
  /// Minimum severity is info. The baseline is disabled, its path is
  /// `.flutterguard-baseline.json`, and fail-on-new is true. Reports go to
  /// `build/flutterguard` in every [ReportFormat], with history and opening
  /// the HTML report left off. The gate fails on high and critical, with no
  /// finding caps. Outdated and vulnerability checks are off. Include,
  /// exclude, and allowed-host lists are [defaultIncludes], [defaultExcludes],
  /// and [defaultAllowedHosts]. Custom rules, rule settings, suppressions,
  /// and required locales are empty.
  static FlutterGuardConfig defaults() {
    return FlutterGuardConfig(
      discoveryMode: DiscoveryMode.auto,
      discoveryRoots: const [],
      maxDepth: 4,
      include: defaultIncludes,
      exclude: defaultExcludes,
      modules: {for (final module in AuditModule.values) module: true},
      architecture: ArchitecturePolicy(
        profile: 'none',
        layers: const [],
        featureCoupling: true,
        businessLogicComplexity: 12,
      ),
      codeQuality: const CodeQualityPolicy(
        complexityThreshold: 15,
        classLineThreshold: 300,
        methodLineThreshold: 80,
      ),
      allowedHosts: defaultAllowedHosts,
      severityOverrides: const {},
      minSeverity: Severity.info,
      suppressions: const [],
      baselineEnabled: false,
      baselinePath: '.flutterguard-baseline.json',
      failOnNew: true,
      reportDirectory: 'build/flutterguard',
      reportFormats: const [
        ReportFormat.html,
        ReportFormat.json,
        ReportFormat.markdown,
        ReportFormat.sarif,
      ],
      history: false,
      openHtml: false,
      failOn: const {Severity.high, Severity.critical},
      maxFindings: null,
      maxNewFindings: null,
      outdatedChecks: false,
      vulnerabilityChecks: false,
      customRules: const [],
      ruleSettings: const {},
      requiredLocales: const [],
    );
  }
}

/// Glob patterns included when a project does not set its own include list.
///
/// Covers Dart and YAML sources, lockfiles, platform project files, ARB
/// catalogs, HTML and JSON, images, and env files.
const List<String> defaultIncludes = [
  '**/*.dart',
  '**/*.yaml',
  '**/*.yml',
  '**/pubspec.lock',
  '**/*.xml',
  '**/*.plist',
  '**/*.gradle',
  '**/*.kts',
  '**/*.arb',
  '**/*.html',
  '**/*.json',
  '**/*.png',
  '**/*.jpg',
  '**/*.webp',
  '**/*.svg',
  '**/*.xcconfig',
  '**/*.pbxproj',
  '**/*.cmake',
  '**/CMakeLists.txt',
  '**/*.rc',
  '**/*.cc',
  '**/*.entitlements',
  '**/*.properties',
  '**/.env',
  '**/.env.*',
];

/// Glob patterns excluded when a project does not set its own exclude list.
///
/// Skips Dart tool output, build directories, VCS metadata, CocoaPods,
/// Gradle caches, symlinks, ephemeral files, and the `.flutterguard`
/// directory.
const List<String> defaultExcludes = [
  '**/.dart_tool/**',
  '**/build/**',
  '**/.git/**',
  '**/ios/Pods/**',
  '**/android/.gradle/**',
  '**/.symlinks/**',
  '**/ephemeral/**',
  '**/.flutterguard/**',
];

/// Hosts the default cleartext and endpoint checks treat as acceptable.
///
/// Includes loopback and emulator addresses, documentation hosts, and common
/// schema and package hosts.
const List<String> defaultAllowedHosts = [
  'localhost',
  '127.0.0.1',
  '0.0.0.0',
  '10.0.2.2',
  '::1',
  'example.com',
  'schemas.android.com',
  'www.w3.org',
  'www.apple.com',
  'flutter.dev',
  'pub.dev',
  'github.com',
  'xmlns',
];

/// Directory names that discovery and file indexing do not descend into.
const Set<String> skippedDirectoryNames = {
  '.git',
  '.dart_tool',
  'build',
  '.gradle',
  'Pods',
  'ephemeral',
  '.symlinks',
  'node_modules',
  '.idea',
  '.flutterguard',
};

/// Returns the built-in layer policy for [profile].
///
/// `none` returns an empty layer list, feature coupling enabled, and a
/// business-logic complexity of 12. `clean` uses [cleanLayers].
/// `featureFirst` uses [featureFirstLayers]. Those two profiles also enable
/// feature coupling and use complexity 12. `custom` throws ConfigException
/// because the caller must supply the layers. Any other value throws
/// ConfigException.
ArchitecturePolicy architectureProfile(String profile) {
  switch (profile) {
    case 'none':
      return const ArchitecturePolicy(
        profile: 'none',
        layers: [],
        featureCoupling: true,
        businessLogicComplexity: 12,
      );
    case 'clean':
      return ArchitecturePolicy(
        profile: 'clean',
        layers: cleanLayers,
        featureCoupling: true,
        businessLogicComplexity: 12,
      );
    case 'featureFirst':
      return ArchitecturePolicy(
        profile: 'featureFirst',
        layers: featureFirstLayers,
        featureCoupling: true,
        businessLogicComplexity: 12,
      );
    case 'custom':
      throw ConfigException(
        'architecture.profile "custom" requires architecture.layers.',
      );
    default:
      throw ConfigException(
        'architecture.profile must be none, clean, featureFirst, or custom.',
      );
  }
}

/// Built-in layers for the `clean` architecture profile.
///
/// `presentation` may import `domain` and `application`. `application` and
/// `data` may import `domain`. `domain` lists no imports. Paths cover
/// top-level `lib/<layer>` trees and `lib/features/*/` trees.
final List<LayerPolicy> cleanLayers = [
  const LayerPolicy(
    name: 'presentation',
    paths: [
      'lib/presentation/**',
      'lib/ui/**',
      'lib/features/*/presentation/**',
      'lib/features/*/ui/**',
    ],
    mayImport: ['domain', 'application'],
  ),
  const LayerPolicy(
    name: 'application',
    paths: ['lib/application/**', 'lib/features/*/application/**'],
    mayImport: ['domain'],
  ),
  const LayerPolicy(
    name: 'domain',
    paths: ['lib/domain/**', 'lib/features/*/domain/**'],
    mayImport: [],
  ),
  const LayerPolicy(
    name: 'data',
    paths: ['lib/data/**', 'lib/features/*/data/**'],
    mayImport: ['domain'],
  ),
];

/// Built-in layers for the `featureFirst` architecture profile.
///
/// `shared` covers `lib/shared` and `lib/core` and lists no imports.
/// `featureApi` covers `lib/features/*/*.dart` and may import `shared`.
/// `featureInternal` covers `lib/features` and may import `shared` and
/// `featureApi`.
final List<LayerPolicy> featureFirstLayers = [
  const LayerPolicy(
    name: 'shared',
    paths: ['lib/shared/**', 'lib/core/**'],
    mayImport: [],
  ),
  const LayerPolicy(
    name: 'featureApi',
    paths: ['lib/features/*/*.dart'],
    mayImport: ['shared'],
  ),
  const LayerPolicy(
    name: 'featureInternal',
    paths: ['lib/features/**'],
    mayImport: ['shared', 'featureApi'],
  ),
];

/// Rejects a glob that leaves the project or uses unsupported syntax.
///
/// Throws ConfigException when [pattern] contains `..`, and when [pattern]
/// contains brackets or braces. Supported syntax is `*`, `?`, and `**`.
/// [path] is the configuration label included in the exception message.
void validateGlob(String pattern, String path) {
  if (pattern.contains('..')) {
    throw ConfigException(
      '$path contains ".." and was refused. Use a pattern inside the project.',
    );
  }
  if (GlobMatcher.hasUnsupportedSyntax(pattern)) {
    throw ConfigException(
      '$path uses unsupported glob syntax. Use only *, ?, and **.',
    );
  }
}
