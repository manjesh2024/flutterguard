import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'config.dart';
import 'exceptions.dart';
import 'severity.dart';
import 'version.dart';

const String configFileName = '.flutterguard.yaml';

FlutterGuardConfig loadConfig({required String rootPath, String? configPath}) {
  final file = configPath == null
      ? File(p.join(rootPath, configFileName))
      : File(configPath);
  if (!file.existsSync()) {
    if (configPath != null) {
      throw ConfigException(
        'Configuration file was not found: ${file.path}\n'
        'Pass an existing --config file, or run `flutterguard init`.',
      );
    }
    return FlutterGuardConfig.defaults();
  }
  try {
    return parseConfig(file.readAsStringSync(), source: file.path);
  } on ConfigException {
    rethrow;
  } on FileSystemException catch (error) {
    throw ConfigException('Could not read ${file.path}: ${error.message}');
  }
}

FlutterGuardConfig parseConfig(String yaml, {String source = configFileName}) {
  final Object? loaded;
  try {
    loaded = loadYaml(yaml);
  } on YamlException catch (error) {
    throw ConfigException(
      'Malformed YAML in $source at line ${error.span?.start.line ?? '?'}, '
      'column ${error.span?.start.column ?? '?'}: ${error.message}\n'
      'Fix the file. FlutterGuard will not fall back to defaults for a '
      'broken configuration.',
    );
  }
  if (loaded == null) {
    throw ConfigException(
      '$source is empty. Add `version: $configSchemaVersion` or remove the file.',
    );
  }
  if (loaded is! YamlMap) {
    throw ConfigException('$source must be a YAML mapping.');
  }
  return _parseMap(loaded, source);
}

FlutterGuardConfig _parseMap(YamlMap map, String source) {
  _rejectUnknown(map, _rootKeys, source);
  final version = map['version'];
  if (version is! int || version != configSchemaVersion) {
    throw ConfigException(
      '$source: version must be the integer $configSchemaVersion. '
      'Found ${version ?? 'nothing'}.',
    );
  }
  final defaults = FlutterGuardConfig.defaults();
  final discovery = _discovery(map['discovery'], defaults, source);
  final includes = _stringList(
    map['include'],
    defaults.include,
    '$source include',
  );
  final excludes = _stringList(
    map['exclude'],
    defaults.exclude,
    '$source exclude',
  );
  for (var i = 0; i < includes.length; i++) {
    validateGlob(includes[i], '$source include[$i]');
  }
  for (var i = 0; i < excludes.length; i++) {
    validateGlob(excludes[i], '$source exclude[$i]');
  }
  final modules = _modules(map['modules'], defaults, source);
  final architecture = _architecture(map['architecture'], defaults, source);
  final codeQuality = _codeQuality(map['codeQuality'], defaults, source);
  final allowedHosts = _stringList(
    map['allowedHosts'],
    defaults.allowedHosts,
    '$source allowedHosts',
  );
  final severity = _severity(map['severity'], defaults, source);
  final suppressions = _suppressions(map['suppressions'], source);
  final baseline = _baseline(map['baseline'], defaults, source);
  final reports = _reports(map['reports'], defaults, source);
  final gate = _gate(map['qualityGate'], defaults, source);
  final network = _network(map['network'], defaults, source);
  final customRules = _customRules(map['customRules'], source);
  final ruleSettings = _ruleSettings(map['rules'], customRules, source);
  final localization = _localization(map['localization'], source);
  _validateRuleReferences(
    severity.overrides.keys,
    ruleSettings.keys,
    suppressions,
    customRules,
    source,
  );
  return FlutterGuardConfig(
    discoveryMode: discovery.mode,
    discoveryRoots: discovery.roots,
    maxDepth: discovery.maxDepth,
    include: includes,
    exclude: excludes,
    modules: modules,
    architecture: architecture,
    codeQuality: codeQuality,
    allowedHosts: allowedHosts,
    severityOverrides: severity.overrides,
    minSeverity: severity.minSeverity,
    suppressions: suppressions,
    baselineEnabled: baseline.enabled,
    baselinePath: baseline.path,
    failOnNew: baseline.failOnNew,
    reportDirectory: reports.directory,
    reportFormats: reports.formats,
    history: reports.history,
    openHtml: reports.openHtml,
    failOn: gate.failOn,
    maxFindings: gate.maxFindings,
    maxNewFindings: gate.maxNewFindings,
    outdatedChecks: network.outdated,
    vulnerabilityChecks: network.vulnerabilities,
    customRules: customRules,
    ruleSettings: ruleSettings,
    requiredLocales: localization,
  );
}

const Set<String> _rootKeys = {
  'version',
  'discovery',
  'include',
  'exclude',
  'modules',
  'architecture',
  'codeQuality',
  'allowedHosts',
  'severity',
  'suppressions',
  'baseline',
  'reports',
  'qualityGate',
  'network',
  'customRules',
  'rules',
  'localization',
};

final class _Discovery {
  const _Discovery(this.mode, this.roots, this.maxDepth);
  final DiscoveryMode mode;
  final List<String> roots;
  final int maxDepth;
}

_Discovery _discovery(
  Object? value,
  FlutterGuardConfig defaults,
  String source,
) {
  if (value == null) {
    return _Discovery(
      defaults.discoveryMode,
      defaults.discoveryRoots,
      defaults.maxDepth,
    );
  }
  final map = _asMap(value, '$source discovery');
  _rejectUnknown(map, const {'mode', 'roots', 'maxDepth'}, '$source discovery');
  final modeName = map['mode'] ?? 'auto';
  if (modeName is! String) {
    throw ConfigException('$source discovery.mode must be a string.');
  }
  final mode = DiscoveryMode.values.where((item) => item.name == modeName);
  if (mode.isEmpty) {
    throw ConfigException(
      '$source discovery.mode must be auto, single, or monorepo.',
    );
  }
  final roots = _stringList(map['roots'], const [], '$source discovery.roots');
  for (final root in roots) {
    if (root.contains('..') || p.isAbsolute(root)) {
      throw ConfigException(
        '$source discovery.roots entry "$root" must be a relative path inside the project.',
      );
    }
  }
  final depth = map['maxDepth'] ?? defaults.maxDepth;
  if (depth is! int || depth < 0 || depth > 12) {
    throw ConfigException(
      '$source discovery.maxDepth must be an integer from 0 to 12.',
    );
  }
  return _Discovery(mode.single, roots, depth);
}

Map<AuditModule, bool> _modules(
  Object? value,
  FlutterGuardConfig defaults,
  String source,
) {
  final modules = Map<AuditModule, bool>.of(defaults.modules);
  if (value == null) {
    return modules;
  }
  final map = _asMap(value, '$source modules');
  final allowed = {for (final module in AuditModule.values) module.name};
  _rejectUnknown(map, allowed, '$source modules');
  for (final key in map.keys) {
    final name = key.toString();
    final module = AuditModule.values.firstWhere((item) => item.name == name);
    final enabled = map[key];
    if (enabled is! bool) {
      throw ConfigException('$source modules.$name must be true or false.');
    }
    modules[module] = enabled;
  }
  return modules;
}

ArchitecturePolicy _architecture(
  Object? value,
  FlutterGuardConfig defaults,
  String source,
) {
  if (value == null) {
    return defaults.architecture;
  }
  final map = _asMap(value, '$source architecture');
  _rejectUnknown(map, const {
    'profile',
    'layers',
    'featureCoupling',
    'businessLogicComplexity',
  }, '$source architecture');
  final profile = map['profile'] ?? defaults.architecture.profile;
  if (profile is! String) {
    throw ConfigException('$source architecture.profile must be a string.');
  }
  final coupling =
      map['featureCoupling'] ?? defaults.architecture.featureCoupling;
  if (coupling is! bool) {
    throw ConfigException(
      '$source architecture.featureCoupling must be true or false.',
    );
  }
  final threshold =
      map['businessLogicComplexity'] ??
      defaults.architecture.businessLogicComplexity;
  if (threshold is! int || threshold < 1) {
    throw ConfigException(
      '$source architecture.businessLogicComplexity must be a positive integer.',
    );
  }
  if (profile == 'custom' || map.containsKey('layers')) {
    final rawLayers = map['layers'];
    if (profile == 'custom' && rawLayers == null) {
      throw ConfigException(
        '$source architecture.profile "custom" requires architecture.layers.',
      );
    }
    if (rawLayers != null) {
      return ArchitecturePolicy(
        profile: profile == 'custom' ? 'custom' : profile,
        layers: _layers(rawLayers, source),
        featureCoupling: coupling,
        businessLogicComplexity: threshold,
      );
    }
  }
  if (profile != 'none' &&
      profile != 'clean' &&
      profile != 'featureFirst' &&
      profile != 'custom') {
    throw ConfigException(
      '$source architecture.profile must be none, clean, featureFirst, or custom.',
    );
  }
  final builtIn = architectureProfile(profile);
  return ArchitecturePolicy(
    profile: builtIn.profile,
    layers: builtIn.layers,
    featureCoupling: coupling,
    businessLogicComplexity: threshold,
  );
}

List<LayerPolicy> _layers(Object? value, String source) {
  final list = _asList(value, '$source architecture.layers');
  if (list.isEmpty) {
    throw ConfigException('$source architecture.layers must not be empty.');
  }
  final names = <String>{};
  final layers = <LayerPolicy>[];
  for (var i = 0; i < list.length; i++) {
    final item = list[i];
    final map = _asMap(item, '$source architecture.layers[$i]');
    _rejectUnknown(map, const {
      'name',
      'paths',
      'mayImport',
    }, '$source architecture.layers[$i]');
    final name = map['name'];
    if (name is! String || name.trim().isEmpty) {
      throw ConfigException(
        '$source architecture.layers[$i].name must be a non-empty string.',
      );
    }
    if (!names.add(name)) {
      throw ConfigException(
        '$source architecture.layers contains duplicate name "$name".',
      );
    }
    final paths = _stringList(
      map['paths'],
      const [],
      '$source architecture.layers[$i].paths',
    );
    if (paths.isEmpty) {
      throw ConfigException(
        '$source architecture.layers[$i].paths must not be empty.',
      );
    }
    for (var pIndex = 0; pIndex < paths.length; pIndex++) {
      validateGlob(
        paths[pIndex],
        '$source architecture.layers[$i].paths[$pIndex]',
      );
    }
    final mayImport = _stringList(
      map['mayImport'],
      const [],
      '$source architecture.layers[$i].mayImport',
    );
    layers.add(LayerPolicy(name: name, paths: paths, mayImport: mayImport));
  }
  final known = layers.map((layer) => layer.name).toSet();
  for (final layer in layers) {
    for (final imported in layer.mayImport) {
      if (!known.contains(imported)) {
        throw ConfigException(
          '$source architecture.layers.${layer.name}.mayImport references unknown layer "$imported".',
        );
      }
    }
  }
  return layers;
}

CodeQualityPolicy _codeQuality(
  Object? value,
  FlutterGuardConfig defaults,
  String source,
) {
  if (value == null) {
    return defaults.codeQuality;
  }
  final map = _asMap(value, '$source codeQuality');
  _rejectUnknown(map, const {
    'complexityThreshold',
    'classLineThreshold',
    'methodLineThreshold',
  }, '$source codeQuality');
  int read(String key, int fallback) {
    final raw = map[key] ?? fallback;
    if (raw is! int || raw < 1) {
      throw ConfigException(
        '$source codeQuality.$key must be a positive integer.',
      );
    }
    return raw;
  }

  return CodeQualityPolicy(
    complexityThreshold: read(
      'complexityThreshold',
      defaults.codeQuality.complexityThreshold,
    ),
    classLineThreshold: read(
      'classLineThreshold',
      defaults.codeQuality.classLineThreshold,
    ),
    methodLineThreshold: read(
      'methodLineThreshold',
      defaults.codeQuality.methodLineThreshold,
    ),
  );
}

final class _SeverityConfig {
  const _SeverityConfig(this.minSeverity, this.overrides);
  final Severity minSeverity;
  final Map<String, Severity> overrides;
}

_SeverityConfig _severity(
  Object? value,
  FlutterGuardConfig defaults,
  String source,
) {
  if (value == null) {
    return _SeverityConfig(defaults.minSeverity, defaults.severityOverrides);
  }
  final map = _asMap(value, '$source severity');
  _rejectUnknown(map, const {'minReport', 'overrides'}, '$source severity');
  final minRaw = map['minReport'] ?? defaults.minSeverity.name;
  if (minRaw is! String) {
    throw ConfigException('$source severity.minReport must be a string.');
  }
  final Severity minSeverity;
  try {
    minSeverity = Severity.parse(minRaw, path: '$source severity.minReport');
  } on FormatException catch (error) {
    throw ConfigException(error.message);
  }
  final overrides = <String, Severity>{};
  final rawOverrides = map['overrides'];
  if (rawOverrides != null) {
    final overrideMap = _asMap(rawOverrides, '$source severity.overrides');
    for (final key in overrideMap.keys) {
      final ruleId = key.toString();
      _validateRuleId(ruleId, '$source severity.overrides');
      final raw = overrideMap[key];
      if (raw is! String) {
        throw ConfigException(
          '$source severity.overrides.$ruleId must be a severity name.',
        );
      }
      try {
        overrides[ruleId] = Severity.parse(
          raw,
          path: '$source severity.overrides.$ruleId',
        );
      } on FormatException catch (error) {
        throw ConfigException(error.message);
      }
    }
  }
  return _SeverityConfig(minSeverity, overrides);
}

List<SuppressionPolicy> _suppressions(Object? value, String source) {
  if (value == null) {
    return const [];
  }
  final list = _asList(value, '$source suppressions');
  final suppressions = <SuppressionPolicy>[];
  for (var i = 0; i < list.length; i++) {
    final map = _asMap(list[i], '$source suppressions[$i]');
    _rejectUnknown(map, const {
      'rule',
      'path',
      'fingerprint',
      'reason',
    }, '$source suppressions[$i]');
    final rule = map['rule'];
    final path = map['path'];
    final fingerprint = map['fingerprint'];
    final reason = map['reason'];
    if (rule != null && rule is! String) {
      throw ConfigException('$source suppressions[$i].rule must be a string.');
    }
    if (path != null && path is! String) {
      throw ConfigException('$source suppressions[$i].path must be a string.');
    }
    if (fingerprint != null && fingerprint is! String) {
      throw ConfigException(
        '$source suppressions[$i].fingerprint must be a string.',
      );
    }
    if (reason is! String || reason.trim().isEmpty) {
      throw ConfigException(
        '$source suppressions[$i].reason is required. '
        'Suppressions without a reason are refused.',
      );
    }
    if (rule == null && fingerprint == null) {
      throw ConfigException(
        '$source suppressions[$i] must set rule or fingerprint.',
      );
    }
    if (rule is String) {
      _validateRuleId(rule, '$source suppressions[$i].rule');
    }
    if (path is String) {
      validateGlob(path, '$source suppressions[$i].path');
    }
    suppressions.add(
      SuppressionPolicy(
        rule: rule as String?,
        path: path as String?,
        fingerprint: fingerprint as String?,
        reason: reason.trim(),
      ),
    );
  }
  return suppressions;
}

final class _Baseline {
  const _Baseline(this.enabled, this.path, this.failOnNew);
  final bool enabled;
  final String path;
  final bool failOnNew;
}

_Baseline _baseline(Object? value, FlutterGuardConfig defaults, String source) {
  if (value == null) {
    return _Baseline(
      defaults.baselineEnabled,
      defaults.baselinePath,
      defaults.failOnNew,
    );
  }
  final map = _asMap(value, '$source baseline');
  _rejectUnknown(map, const {
    'enabled',
    'path',
    'failOnNew',
  }, '$source baseline');
  final enabled = map['enabled'] ?? defaults.baselineEnabled;
  final baselinePath = map['path'] ?? defaults.baselinePath;
  final failOnNew = map['failOnNew'] ?? defaults.failOnNew;
  if (enabled is! bool || baselinePath is! String || failOnNew is! bool) {
    throw ConfigException(
      '$source baseline.enabled and failOnNew must be booleans and path must be a string.',
    );
  }
  if (baselinePath.contains('..') || p.isAbsolute(baselinePath)) {
    throw ConfigException(
      '$source baseline.path must be a relative path inside the project.',
    );
  }
  return _Baseline(enabled, baselinePath, failOnNew);
}

final class _Reports {
  const _Reports(this.directory, this.formats, this.history, this.openHtml);
  final String directory;
  final List<ReportFormat> formats;
  final bool history;
  final bool openHtml;
}

_Reports _reports(Object? value, FlutterGuardConfig defaults, String source) {
  if (value == null) {
    return _Reports(
      defaults.reportDirectory,
      defaults.reportFormats,
      defaults.history,
      defaults.openHtml,
    );
  }
  final map = _asMap(value, '$source reports');
  _rejectUnknown(map, const {
    'directory',
    'formats',
    'history',
    'openHtml',
  }, '$source reports');
  final directory = map['directory'] ?? defaults.reportDirectory;
  final history = map['history'] ?? defaults.history;
  final openHtml = map['openHtml'] ?? defaults.openHtml;
  if (directory is! String || directory.trim().isEmpty) {
    throw ConfigException(
      '$source reports.directory must be a non-empty string.',
    );
  }
  if (directory.contains('..') || p.isAbsolute(directory)) {
    throw ConfigException(
      '$source reports.directory must stay inside the project. Absolute paths and ".." are refused.',
    );
  }
  if (history is! bool || openHtml is! bool) {
    throw ConfigException(
      '$source reports.history and reports.openHtml must be true or false.',
    );
  }
  final formats = <ReportFormat>[];
  final rawFormats = map['formats'];
  if (rawFormats == null) {
    formats.addAll(defaults.reportFormats);
  } else {
    final list = _asList(rawFormats, '$source reports.formats');
    if (list.isEmpty) {
      throw ConfigException('$source reports.formats must not be empty.');
    }
    for (var i = 0; i < list.length; i++) {
      final name = list[i];
      if (name is! String) {
        throw ConfigException('$source reports.formats[$i] must be a string.');
      }
      final matches = ReportFormat.values.where((item) => item.name == name);
      if (matches.isEmpty) {
        throw ConfigException(
          '$source reports.formats[$i] must be html, json, markdown, or sarif.',
        );
      }
      formats.add(matches.single);
    }
  }
  return _Reports(directory, formats, history, openHtml);
}

final class _Gate {
  const _Gate(this.failOn, this.maxFindings, this.maxNewFindings);
  final Set<Severity> failOn;
  final int? maxFindings;
  final int? maxNewFindings;
}

_Gate _gate(Object? value, FlutterGuardConfig defaults, String source) {
  if (value == null) {
    return _Gate(
      defaults.failOn,
      defaults.maxFindings,
      defaults.maxNewFindings,
    );
  }
  final map = _asMap(value, '$source qualityGate');
  _rejectUnknown(map, const {
    'failOn',
    'maxFindings',
    'maxNewFindings',
  }, '$source qualityGate');
  final failOn = <Severity>{};
  final rawFail = map['failOn'];
  if (rawFail == null) {
    failOn.addAll(defaults.failOn);
  } else {
    final list = _asList(rawFail, '$source qualityGate.failOn');
    for (var i = 0; i < list.length; i++) {
      final name = list[i];
      if (name is! String) {
        throw ConfigException(
          '$source qualityGate.failOn[$i] must be a string.',
        );
      }
      try {
        failOn.add(
          Severity.parse(name, path: '$source qualityGate.failOn[$i]'),
        );
      } on FormatException catch (error) {
        throw ConfigException(error.message);
      }
    }
  }
  int? optional(String key) {
    if (!map.containsKey(key) || map[key] == null) {
      return null;
    }
    final raw = map[key];
    if (raw is! int || raw < 0) {
      throw ConfigException(
        '$source qualityGate.$key must be a non-negative integer or null.',
      );
    }
    return raw;
  }

  return _Gate(failOn, optional('maxFindings'), optional('maxNewFindings'));
}

final class _Network {
  const _Network(this.outdated, this.vulnerabilities);
  final bool outdated;
  final bool vulnerabilities;
}

_Network _network(Object? value, FlutterGuardConfig defaults, String source) {
  if (value == null) {
    return _Network(defaults.outdatedChecks, defaults.vulnerabilityChecks);
  }
  final map = _asMap(value, '$source network');
  _rejectUnknown(map, const {
    'outdatedChecks',
    'vulnerabilityChecks',
  }, '$source network');
  final outdated = map['outdatedChecks'] ?? defaults.outdatedChecks;
  final vulnerabilities =
      map['vulnerabilityChecks'] ?? defaults.vulnerabilityChecks;
  if (outdated is! bool || vulnerabilities is! bool) {
    throw ConfigException(
      '$source network.outdatedChecks and vulnerabilityChecks must be true or false.',
    );
  }
  return _Network(outdated, vulnerabilities);
}

List<CustomRulePolicy> _customRules(Object? value, String source) {
  if (value == null) {
    return const [];
  }
  final list = _asList(value, '$source customRules');
  final rules = <CustomRulePolicy>[];
  final ids = <String>{};
  for (var i = 0; i < list.length; i++) {
    final map = _asMap(list[i], '$source customRules[$i]');
    _rejectUnknown(map, const {
      'id',
      'severity',
      'category',
      'message',
      'recommendation',
      'fileGlobs',
      'contains',
      'heuristic',
    }, '$source customRules[$i]');
    final id = map['id'];
    final severityRaw = map['severity'];
    final category = map['category'];
    final message = map['message'];
    final recommendation = map['recommendation'];
    final contains = map['contains'];
    final heuristic = map['heuristic'] ?? true;
    if (id is! String ||
        severityRaw is! String ||
        category is! String ||
        message is! String ||
        recommendation is! String ||
        contains is! String ||
        heuristic is! bool) {
      throw ConfigException(
        '$source customRules[$i] requires id, severity, category, message, recommendation, and contains.',
      );
    }
    _validateRuleId(id, '$source customRules[$i].id');
    if (!id.startsWith('FG-CUSTOM-')) {
      throw ConfigException(
        '$source customRules[$i].id must start with FG-CUSTOM-.',
      );
    }
    if (!ids.add(id)) {
      throw ConfigException('$source customRules contains duplicate id "$id".');
    }
    if (contains.isEmpty || contains.length > 200) {
      throw ConfigException(
        '$source customRules[$i].contains must be 1 to 200 characters. Regular expressions are not accepted.',
      );
    }
    final globs = _stringList(map['fileGlobs'], const [
      '**/*',
    ], '$source customRules[$i].fileGlobs');
    for (var g = 0; g < globs.length; g++) {
      validateGlob(globs[g], '$source customRules[$i].fileGlobs[$g]');
    }
    final Severity severity;
    try {
      severity = Severity.parse(
        severityRaw,
        path: '$source customRules[$i].severity',
      );
    } on FormatException catch (error) {
      throw ConfigException(error.message);
    }
    rules.add(
      CustomRulePolicy(
        id: id,
        severity: severity,
        category: category,
        message: message,
        recommendation: recommendation,
        fileGlobs: globs,
        contains: contains,
        heuristic: heuristic,
      ),
    );
  }
  return rules;
}

Map<String, RuleSetting> _ruleSettings(
  Object? value,
  List<CustomRulePolicy> customRules,
  String source,
) {
  if (value == null) {
    return const {};
  }
  final map = _asMap(value, '$source rules');
  final settings = <String, RuleSetting>{};
  for (final key in map.keys) {
    final id = key.toString();
    _validateRuleId(id, '$source rules');
    final raw = map[key];
    if (raw is bool) {
      settings[id] = RuleSetting(enabled: raw);
      continue;
    }
    final ruleMap = _asMap(raw, '$source rules.$id');
    _rejectUnknown(ruleMap, const {'enabled', 'severity'}, '$source rules.$id');
    final enabled = ruleMap['enabled'] ?? true;
    if (enabled is! bool) {
      throw ConfigException('$source rules.$id.enabled must be true or false.');
    }
    Severity? severity;
    if (ruleMap['severity'] != null) {
      if (ruleMap['severity'] is! String) {
        throw ConfigException('$source rules.$id.severity must be a string.');
      }
      try {
        severity = Severity.parse(
          ruleMap['severity'] as String,
          path: '$source rules.$id.severity',
        );
      } on FormatException catch (error) {
        throw ConfigException(error.message);
      }
    }
    settings[id] = RuleSetting(enabled: enabled, severity: severity);
  }
  return settings;
}

List<String> _localization(Object? value, String source) {
  if (value == null) {
    return const [];
  }
  final map = _asMap(value, '$source localization');
  _rejectUnknown(map, const {'requiredLocales'}, '$source localization');
  return _stringList(
    map['requiredLocales'],
    const [],
    '$source localization.requiredLocales',
  );
}

void _validateRuleReferences(
  Iterable<String> overrideIds,
  Iterable<String> settingIds,
  List<SuppressionPolicy> suppressions,
  List<CustomRulePolicy> customRules,
  String source,
) {
  final customIds = customRules.map((rule) => rule.id).toSet();
  // Built-in ids are checked later against the registry so the loader does
  // not depend on rule implementations. Custom ids are known here.
  // Unknown built-ins are validated by [validateKnownRules].
  for (final id in settingIds) {
    if (id.startsWith('FG-CUSTOM-') && !customIds.contains(id)) {
      throw ConfigException(
        '$source rules.$id does not match a customRules entry.',
      );
    }
  }
  for (final id in overrideIds) {
    if (id.startsWith('FG-CUSTOM-') && !customIds.contains(id)) {
      throw ConfigException(
        '$source severity.overrides.$id does not match a customRules entry.',
      );
    }
  }
  for (final suppression in suppressions) {
    final rule = suppression.rule;
    if (rule != null &&
        rule.startsWith('FG-CUSTOM-') &&
        !customIds.contains(rule)) {
      throw ConfigException(
        '$source suppressions reference unknown custom rule "$rule".',
      );
    }
  }
}

void validateKnownRules(FlutterGuardConfig config, Set<String> knownIds) {
  void check(String id, String path) {
    if (!knownIds.contains(id)) {
      throw ConfigException(
        '$path references unknown rule "$id". Run `flutterguard rules list`.',
      );
    }
  }

  for (final id in config.severityOverrides.keys) {
    check(id, 'severity.overrides');
  }
  for (final id in config.ruleSettings.keys) {
    check(id, 'rules');
  }
  for (final suppression in config.suppressions) {
    final rule = suppression.rule;
    if (rule != null) {
      check(rule, 'suppressions');
    }
  }
}

void _validateRuleId(String id, String path) {
  final ok = RegExp(r'^FG-[A-Z0-9]+(?:-[A-Z0-9]+)*$').hasMatch(id);
  if (!ok) {
    throw ConfigException('$path rule id "$id" must look like FG-ARCH-001.');
  }
}

void _rejectUnknown(YamlMap map, Set<String> allowed, String path) {
  for (final key in map.keys) {
    final name = key.toString();
    if (!allowed.contains(name)) {
      final expected = (allowed.toList()..sort()).join(', ');
      throw ConfigException(
        '$path: unknown key "$name". Expected one of: $expected.',
      );
    }
  }
}

YamlMap _asMap(Object? value, String path) {
  if (value is! YamlMap) {
    throw ConfigException('$path must be a mapping.');
  }
  return value;
}

List<Object?> _asList(Object? value, String path) {
  if (value is! YamlList) {
    throw ConfigException('$path must be a list.');
  }
  return value.toList(growable: false);
}

List<String> _stringList(Object? value, List<String> fallback, String path) {
  if (value == null) {
    return List<String>.of(fallback);
  }
  final list = _asList(value, path);
  final result = <String>[];
  for (var i = 0; i < list.length; i++) {
    final item = list[i];
    if (item is! String || item.trim().isEmpty) {
      throw ConfigException('$path[$i] must be a non-empty string.');
    }
    result.add(item);
  }
  return result;
}

/// Template written by `flutterguard init`.
const String configTemplate = '''
version: 1

discovery:
  mode: auto
  roots: []
  maxDepth: 4

include:
  - "**/*.dart"
  - "**/*.yaml"
  - "**/*.yml"
  - "**/pubspec.lock"
  - "**/*.xml"
  - "**/*.plist"
  - "**/*.gradle"
  - "**/*.kts"
  - "**/*.arb"
  - "**/*.html"
  - "**/*.json"
  - "**/*.png"
  - "**/*.jpg"
  - "**/*.webp"
  - "**/*.svg"
  - "**/*.xcconfig"
  - "**/*.pbxproj"
  - "**/CMakeLists.txt"
  - "**/.env"

exclude:
  - "**/.dart_tool/**"
  - "**/build/**"
  - "**/.git/**"
  - "**/ios/Pods/**"
  - "**/android/.gradle/**"
  - "**/.symlinks/**"
  - "**/ephemeral/**"

modules:
  branding: true
  configuration: true
  architecture: true
  codeQuality: true
  security: true
  localization: true
  dependencies: true
  platform: true

architecture:
  # none, clean, featureFirst, or custom.
  # none does not assume Clean Architecture, BLoC, Riverpod, or Provider.
  profile: none
  featureCoupling: true
  businessLogicComplexity: 12

codeQuality:
  complexityThreshold: 15
  classLineThreshold: 300
  methodLineThreshold: 80

allowedHosts:
  - localhost
  - 127.0.0.1
  - 10.0.2.2
  - example.com

severity:
  minReport: info
  overrides: {}

suppressions: []

baseline:
  enabled: false
  path: .flutterguard-baseline.json
  failOnNew: true

reports:
  directory: build/flutterguard
  formats:
    - html
    - json
    - markdown
    - sarif
  history: false
  openHtml: false

qualityGate:
  failOn:
    - high
    - critical
  maxFindings: null
  maxNewFindings: null

network:
  outdatedChecks: false
  vulnerabilityChecks: false

localization:
  requiredLocales: []

customRules: []
rules: {}
''';
