import '../core/config.dart';
import 'architecture/architecture_rules.dart';
import 'branding/branding_rules.dart';
import 'code_quality/code_quality_rules.dart';
import 'configuration/configuration_rules.dart';
import 'custom/custom_rules.dart';
import 'dependencies/dependency_rules.dart';
import 'localization/localization_rules.dart';
import 'platform/platform_rules.dart';
import 'rule.dart';
import 'security/security_rules.dart';

/// Collection of audit rules that a scan or the CLI can query.
///
/// ```dart
/// final registry = RuleRegistry.builtIn.withConfig(config);
/// final active = registry.enabled(config);
/// ```
final class RuleRegistry {
  /// Stores [rules] in the order they should run.
  RuleRegistry(this.rules);

  /// Rules held by this registry, including custom rules when present.
  final List<AuditRule> rules;

  /// Built-in rules for all eight modules, without custom rules.
  static final RuleRegistry builtIn = RuleRegistry([
    ...brandingRules(),
    ...configurationRules(),
    ...architectureRules(),
    ...codeQualityRules(),
    ...securityRules(),
    ...localizationRules(),
    ...dependencyRules(),
    ...platformRules(),
  ]);

  /// Returns a registry that appends the custom rules declared in [config].
  ///
  /// Built-in [rules] are kept in their original order. Custom rules follow
  /// them. [config] is not modified.
  RuleRegistry withConfig(FlutterGuardConfig config) {
    return RuleRegistry([...rules, ...customRulesFrom(config)]);
  }

  /// Rule ids in this registry.
  Set<String> get ids => {for (final rule in rules) rule.id};

  /// The rule whose [AuditRule.id] is [id], or null when it is absent.
  AuditRule? byId(String id) {
    for (final rule in rules) {
      if (rule.id == id) {
        return rule;
      }
    }
    return null;
  }

  /// Rules whose module and per-rule switch are both enabled in [config].
  ///
  /// Disabled modules and `rules.<id>.enabled: false` are omitted. The
  /// relative order from [rules] is preserved.
  List<AuditRule> enabled(FlutterGuardConfig config) {
    return [
      for (final rule in rules)
        if (config.moduleEnabled(rule.module) && config.ruleEnabled(rule.id))
          rule,
    ];
  }
}
