import '../../analyzer/arb_parser.dart';
import '../../core/config.dart';
import '../../core/finding.dart';
import '../../core/severity.dart';
import '../rule.dart';

/// Reports message keys that are absent from one or more ARB locales.
///
/// Catalogs that failed to parse are ignored. Fewer than two valid catalogs
/// produces no findings. Each missing key is reported once, naming the
/// locales that lack it.
final class MissingArbKeyRule implements AuditRule {
  @override
  String get id => 'FG-L10N-001';
  @override
  String get title => 'Missing ARB key';
  @override
  String get category => 'localization';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.localization;
  @override
  String get description =>
      'Compares message keys across ARB catalogs in the project.';
  @override
  String get recommendation => 'Add the missing key to every locale catalog.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final catalogs = _valid(scope);
    if (catalogs.length < 2) {
      return const [];
    }
    final findings = <Finding>[];
    final allKeys = <String>{
      for (final catalog in catalogs) ...catalog.messages.keys,
    };
    for (final key in allKeys) {
      final missing = [
        for (final catalog in catalogs)
          if (!catalog.messages.containsKey(key)) catalog.locale,
      ];
      if (missing.isEmpty) {
        continue;
      }
      findings.add(
        emit(
          this,
          scope,
          message: 'Key "$key" is missing from ${missing.join(', ')}.',
          path: catalogs.first.path,
        ),
      );
    }
    return findings;
  }
}

/// Compares ICU placeholder names for the same key across locales.
///
/// The first valid catalog is the base. Each later catalog whose placeholder
/// set differs for a shared key is reported. Fewer than two valid catalogs
/// produces no findings. Keys missing from the later catalog are skipped.
final class PlaceholderMismatchRule implements AuditRule {
  @override
  String get id => 'FG-L10N-002';
  @override
  String get title => 'Placeholder mismatch';
  @override
  String get category => 'localization';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.localization;
  @override
  String get description =>
      'Compares ICU placeholder names for the same key across locales.';
  @override
  String get recommendation =>
      'Use the same placeholder names in every translation of the key.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    return _compare(
      this,
      scope,
      (left, right) => _sameSet(left.placeholders, right.placeholders),
      (key, left, right) =>
          'Key "$key" placeholders differ between ${left.locale} and ${right.locale}.',
    );
  }
}

/// Reports repeated top-level keys in an ARB file.
///
/// Every catalog on the project is visited, including catalogs that failed
/// to parse, and each duplicate key recorded by the parser becomes a finding.
final class DuplicateArbKeyRule implements AuditRule {
  @override
  String get id => 'FG-L10N-003';
  @override
  String get title => 'Duplicate ARB key';
  @override
  String get category => 'localization';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.localization;
  @override
  String get description => 'Reports repeated top-level keys in an ARB file.';
  @override
  String get recommendation =>
      'Keep one entry per key. JSON parsers keep only one of the duplicates.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final catalog in scope.project.arbCatalogs) {
      for (final key in catalog.duplicateKeys) {
        findings.add(
          emit(
            this,
            scope,
            message: 'Duplicate ARB key "$key".',
            path: catalog.path,
          ),
        );
      }
    }
    return findings;
  }
}

/// Checks `l10n.yaml` and the configured required locales for missing catalogs.
///
/// When l10n config is present, a missing template ARB and an `arb-dir` with
/// no ARB files are reported. Each locale in `requiredLocales` that has no
/// catalog is reported, whether or not `l10n.yaml` exists.
final class MissingLocaleFileRule implements AuditRule {
  @override
  String get id => 'FG-L10N-004';
  @override
  String get title => 'Missing locale file';
  @override
  String get category => 'localization';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.localization;
  @override
  String get description =>
      'Checks l10n.yaml and localization.requiredLocales for missing catalogs.';
  @override
  String get recommendation =>
      'Add the ARB file or remove the locale from the required list.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    final l10n = scope.project.l10n;
    if (l10n.present && l10n.templateArbFile != null) {
      final dir = l10n.arbDir ?? 'lib/l10n';
      final expected = '$dir/${l10n.templateArbFile}';
      final exists = scope.project.files.files.any(
        (file) => file.relativePosix == expected,
      );
      if (!exists) {
        findings.add(
          emit(
            this,
            scope,
            message: 'Template ARB $expected from l10n.yaml was not found.',
            path: 'l10n.yaml',
          ),
        );
      }
    }
    if (l10n.present && l10n.arbDir != null) {
      final dir = l10n.arbDir!;
      final exists = scope.project.files.files.any(
        (file) => file.relativePosix.startsWith('$dir/'),
      );
      if (!exists) {
        findings.add(
          emit(
            this,
            scope,
            message: 'l10n.yaml arb-dir "$dir" has no ARB files.',
            path: 'l10n.yaml',
          ),
        );
      }
    }
    final locales = scope.project.arbCatalogs
        .map((catalog) => catalog.locale)
        .toSet();
    for (final required in scope.config.requiredLocales) {
      if (locales.contains(required)) {
        continue;
      }
      findings.add(
        emit(
          this,
          scope,
          message: 'Required locale "$required" has no ARB catalog.',
          path: 'l10n.yaml',
        ),
      );
    }
    return findings;
  }
}

/// Compares plural and select kinds and cases for the same key across locales.
///
/// A shared key is reported when the message kind differs or the case sets
/// differ. Fewer than two valid catalogs produces no findings. The first
/// valid catalog is the base.
final class PluralSelectRule implements AuditRule {
  @override
  String get id => 'FG-L10N-005';
  @override
  String get title => 'Plural and select consistency';
  @override
  String get category => 'localization';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.localization;
  @override
  String get description =>
      'Compares plural/select kinds and cases for the same key across locales.';
  @override
  String get recommendation =>
      'Give every locale the same plural or select cases, including other.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    return _compare(
      this,
      scope,
      (left, right) =>
          left.kind == right.kind && _sameSet(left.cases, right.cases),
      (key, left, right) =>
          'Key "$key" plural/select forms differ between ${left.locale} and ${right.locale}.',
    );
  }
}

/// Heuristic for sentence-like literals in `Text` and common label arguments.
///
/// Generated files, tests, and debug text are skipped. A literal is treated
/// as user-facing when it contains a space, a run of at least three letters,
/// and enough text to be more than a short label. URLs and path-like values
/// are skipped.
final class HardcodedStringRule implements AuditRule {
  @override
  String get id => 'FG-L10N-006';
  @override
  String get title => 'Hardcoded user-facing string';
  @override
  String get category => 'localization';
  @override
  Severity get defaultSeverity => Severity.low;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.localization;
  @override
  String get description =>
      'Heuristic for Text and common label arguments that contain a sentence-like literal. Tests, debug text, and short labels are skipped.';
  @override
  String get recommendation =>
      'Move user-facing copy into an ARB catalog. Short labels, test strings, and debug text are not flagged.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final file in scope.project.dartIndex.files) {
      if (file.generated || _isTestPath(file.path)) {
        continue;
      }
      for (final literal in file.widgetStrings) {
        if (!_userFacing(literal.value)) {
          continue;
        }
        findings.add(
          emit(
            this,
            scope,
            message:
                'Possible hardcoded user-facing ${literal.kind} string. This is a heuristic.',
            path: file.path,
            line: literal.line,
            column: literal.column,
          ),
        );
      }
    }
    return findings;
  }

  bool _userFacing(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http') || trimmed.contains('/')) {
      return false;
    }
    if (RegExp(
      r'^(debug|todo|fixme|lorem)\b',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return false;
    }
    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    if (words < 2 || trimmed.length < 12) {
      return false;
    }
    return RegExp(r'[A-Za-z]{3,}').hasMatch(trimmed);
  }
}

bool _isTestPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.startsWith('test/') ||
      normalized.startsWith('integration_test/') ||
      normalized.startsWith('testing/') ||
      normalized.contains('/test/') ||
      normalized.endsWith('_test.dart');
}

List<ArbCatalog> _valid(RuleScope scope) {
  return scope.project.arbCatalogs
      .where((catalog) => catalog.error == null)
      .toList();
}

bool _sameSet(Set<String> left, Set<String> right) {
  if (left.length != right.length) {
    return false;
  }
  return left.containsAll(right);
}

List<Finding> _compare(
  AuditRule rule,
  RuleScope scope,
  bool Function(ArbMessage left, ArbMessage right) same,
  String Function(String key, ArbCatalog left, ArbCatalog right) message,
) {
  final catalogs = _valid(scope);
  if (catalogs.length < 2) {
    return const [];
  }
  final findings = <Finding>[];
  final base = catalogs.first;
  for (final other in catalogs.skip(1)) {
    for (final entry in base.messages.entries) {
      final counterpart = other.messages[entry.key];
      if (counterpart == null || same(entry.value, counterpart)) {
        continue;
      }
      findings.add(
        emit(
          rule,
          scope,
          message: message(entry.key, base, other),
          path: other.path,
        ),
      );
    }
  }
  return findings;
}

/// Built-in localization rules, in a stable evaluation order.
List<AuditRule> localizationRules() => [
  MissingArbKeyRule(),
  PlaceholderMismatchRule(),
  DuplicateArbKeyRule(),
  MissingLocaleFileRule(),
  PluralSelectRule(),
  HardcodedStringRule(),
];
