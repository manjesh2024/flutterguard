import 'dart:io';

import 'package:flutterguard_audit/src/rules/registry.dart';

void main() {
  final buffer = StringBuffer()
    ..writeln('# Rule catalogue')
    ..writeln()
    ..writeln(
      'Stable IDs shipped with FlutterGuard 0.1.0. '
      'Heuristic rules are review signals, not proof of a defect or vulnerability.',
    )
    ..writeln();
  for (final rule in RuleRegistry.builtIn.rules) {
    buffer
      ..writeln('## ${rule.id}')
      ..writeln()
      ..writeln('- Title: ${rule.title}')
      ..writeln('- Category: ${rule.category}')
      ..writeln('- Default severity: ${rule.defaultSeverity.name}')
      ..writeln('- Heuristic: ${rule.heuristic}')
      ..writeln()
      ..writeln(rule.description)
      ..writeln()
      ..writeln('Recommendation: ${rule.recommendation}')
      ..writeln();
  }
  final file = File('docs/rule-catalogue.md');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(buffer.toString());
  stdout.writeln(
    'Wrote ${file.path} (${RuleRegistry.builtIn.rules.length} rules)',
  );
}
