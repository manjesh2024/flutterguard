import 'dart:io';

import 'package:flutterguard_audit/src/rules/registry.dart';
import 'package:test/test.dart';

void main() {
  test('rule catalogue documents every built-in rule', () {
    final file = File('docs/rule-catalogue.md');
    if (!file.existsSync()) {
      markTestSkipped(
        'docs/ is the repository guide set and is omitted from the pub package layout.',
      );
      return;
    }
    final text = file.readAsStringSync();
    final rules = RuleRegistry.builtIn.rules;
    expect(rules, isNotEmpty);
    for (final rule in rules) {
      expect(text, contains('## ${rule.id}'), reason: rule.id);
      expect(text, contains(rule.title));
    }
  });

  test('readme documents the one-command workflow', () {
    final text = File('README.md').readAsStringSync();
    expect(text, contains('flutterguard'));
    expect(text, contains('flutterguard_audit'));
    expect(text, contains('build/flutterguard'));
  });
}
