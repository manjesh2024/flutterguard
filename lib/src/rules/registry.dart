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

final class RuleRegistry {
  RuleRegistry(this.rules);

  final List<AuditRule> rules;

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

  RuleRegistry withConfig(FlutterGuardConfig config) {
    return RuleRegistry([...rules, ...customRulesFrom(config)]);
  }

  Set<String> get ids => {for (final rule in rules) rule.id};

  AuditRule? byId(String id) {
    for (final rule in rules) {
      if (rule.id == id) {
        return rule;
      }
    }
    return null;
  }

  List<AuditRule> enabled(FlutterGuardConfig config) {
    return [
      for (final rule in rules)
        if (config.moduleEnabled(rule.module) && config.ruleEnabled(rule.id))
          rule,
    ];
  }
}
