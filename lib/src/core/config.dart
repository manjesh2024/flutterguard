import 'exceptions.dart';
import 'glob.dart';
import 'severity.dart';

enum DiscoveryMode { auto, single, monorepo }

enum ReportFormat { html, json, markdown, sarif }

enum AuditModule {
  branding,
  configuration,
  architecture,
  codeQuality,
  security,
  localization,
  dependencies,
  platform,
}

final class LayerPolicy {
  const LayerPolicy({
    required this.name,
    required this.paths,
    required this.mayImport,
  });

  final String name;
  final List<String> paths;
  final List<String> mayImport;
}

final class ArchitecturePolicy {
  const ArchitecturePolicy({
    required this.profile,
    required this.layers,
    required this.featureCoupling,
    required this.businessLogicComplexity,
  });

  final String profile;
  final List<LayerPolicy> layers;
  final bool featureCoupling;
  final int businessLogicComplexity;

  bool get enforcesLayers => profile != 'none' && layers.isNotEmpty;
}

final class CodeQualityPolicy {
  const CodeQualityPolicy({
    required this.complexityThreshold,
    required this.classLineThreshold,
    required this.methodLineThreshold,
  });

  final int complexityThreshold;
  final int classLineThreshold;
  final int methodLineThreshold;
}

final class SuppressionPolicy {
  const SuppressionPolicy({
    required this.rule,
    required this.path,
    required this.fingerprint,
    required this.reason,
  });

  final String? rule;
  final String? path;
  final String? fingerprint;
  final String reason;
}

final class CustomRulePolicy {
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

  final String id;
  final Severity severity;
  final String category;
  final String message;
  final String recommendation;
  final List<String> fileGlobs;
  final String contains;
  final bool heuristic;
}

final class RuleSetting {
  const RuleSetting({required this.enabled, this.severity});

  final bool enabled;
  final Severity? severity;
}

/// Versioned, immutable project configuration.
final class FlutterGuardConfig {
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

  final DiscoveryMode discoveryMode;
  final List<String> discoveryRoots;
  final int maxDepth;
  final List<String> include;
  final List<String> exclude;
  final Map<AuditModule, bool> modules;
  final ArchitecturePolicy architecture;
  final CodeQualityPolicy codeQuality;
  final List<String> allowedHosts;
  final Map<String, Severity> severityOverrides;
  final Severity minSeverity;
  final List<SuppressionPolicy> suppressions;
  final bool baselineEnabled;
  final String baselinePath;
  final bool failOnNew;
  final String reportDirectory;
  final List<ReportFormat> reportFormats;
  final bool history;
  final bool openHtml;
  final Set<Severity> failOn;
  final int? maxFindings;
  final int? maxNewFindings;
  final bool outdatedChecks;
  final bool vulnerabilityChecks;
  final List<CustomRulePolicy> customRules;
  final Map<String, RuleSetting> ruleSettings;
  final List<String> requiredLocales;

  bool moduleEnabled(AuditModule module) => modules[module] ?? true;

  bool ruleEnabled(String ruleId) => ruleSettings[ruleId]?.enabled ?? true;

  Severity severityFor(String ruleId, Severity fallback) {
    return ruleSettings[ruleId]?.severity ??
        severityOverrides[ruleId] ??
        fallback;
  }

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
