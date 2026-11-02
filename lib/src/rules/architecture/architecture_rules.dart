import '../../analyzer/dart_index.dart';
import '../../core/config.dart';
import '../../core/finding.dart';
import '../../core/glob.dart';
import '../../core/severity.dart';
import '../rule.dart';

/// Package names treated as database clients by the UI database-access check.
///
/// A widget or presentation file that imports one of these packages is
/// reported. The set is a fixed review list, not every database plugin.
const databasePackages = {
  'sqflite',
  'sqflite_common',
  'sqflite_sqlcipher',
  'drift',
  'moor',
  'moor_flutter',
  'hive',
  'hive_flutter',
  'isar',
  'isar_flutter_libs',
  'floor',
  'objectbox',
  'realm',
  'sembast',
};

const _uiMethods = {
  'build',
  'initState',
  'dispose',
  'didChangeDependencies',
  'didUpdateWidget',
};

/// Flags imports that point from one architecture layer into a forbidden layer.
///
/// When the selected profile does not enforce layers, evaluation returns no
/// findings. Otherwise each Dart file is assigned the first configured layer
/// whose path pattern matches, and an import is reported when the target
/// layer is different and is not in that layer's allowed import set.
final class LayerDependencyRule implements AuditRule {
  @override
  String get id => 'FG-ARCH-001';
  @override
  String get title => 'Layer dependency direction';
  @override
  String get category => 'architecture';
  @override
  Severity get defaultSeverity => Severity.high;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.architecture;
  @override
  String get description =>
      'Enforces the selected architecture profile. Profile "none" does not invent a layer model.';
  @override
  String get recommendation =>
      'Change the import or update architecture.layers so the dependency is an accepted policy.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final policy = scope.config.architecture;
    if (!policy.enforcesLayers) {
      return const [];
    }
    final findings = <Finding>[];
    for (final file in scope.project.dartIndex.files) {
      final sourceLayer = _layer(file.path, policy.layers);
      if (sourceLayer == null) {
        continue;
      }
      final allowed = policy.layers
          .firstWhere((layer) => layer.name == sourceLayer)
          .mayImport
          .toSet();
      for (final import in file.imports) {
        final target = import.targetPath;
        if (target == null) {
          continue;
        }
        final targetLayer = _layer(target, policy.layers);
        if (targetLayer == null ||
            targetLayer == sourceLayer ||
            allowed.contains(targetLayer)) {
          continue;
        }
        findings.add(
          emit(
            this,
            scope,
            message:
                '$sourceLayer file ${file.path} imports $targetLayer file $target, which profile "${policy.profile}" does not allow.',
            path: file.path,
            line: import.line,
            column: import.column,
          ),
        );
      }
    }
    return findings;
  }
}

/// Reports each import cycle from the Dart index once, in index order.
///
/// The finding path is the first library named in the cycle.
final class CircularImportRule implements AuditRule {
  @override
  String get id => 'FG-ARCH-002';
  @override
  String get title => 'Circular imports';
  @override
  String get category => 'architecture';
  @override
  Severity get defaultSeverity => Severity.high;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.architecture;
  @override
  String get description =>
      'Finds import cycles from the Dart AST. Cycles are reported once in a stable order.';
  @override
  String get recommendation =>
      'Extract the shared type into a third library or invert the dependency.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    return [
      for (final cycle in scope.project.dartIndex.cycles)
        emit(
          this,
          scope,
          message: 'Circular import: $cycle.',
          path: cycle.split(' -> ').first,
        ),
    ];
  }
}

/// Heuristic for complex methods living in a widget or presentation file.
///
/// Generated files, UI lifecycle methods, and methods whose names start with
/// `build` are skipped. A remaining method is reported when its cyclomatic
/// complexity is at least `architecture.businessLogicComplexity`.
final class BusinessLogicPlacementRule implements AuditRule {
  @override
  String get id => 'FG-ARCH-003';
  @override
  String get title => 'Business logic in a UI file';
  @override
  String get category => 'architecture';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.architecture;
  @override
  String get description =>
      'Heuristic for complex methods inside widget files or the configured presentation layer. It does not require BLoC, Riverpod, or Provider.';
  @override
  String get recommendation =>
      'Move the decision logic next to the project\'s existing non-UI types. A high complexity score is not by itself a defect.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final threshold = scope.config.architecture.businessLogicComplexity;
    final findings = <Finding>[];
    for (final file in scope.project.dartIndex.files) {
      if (file.generated || !_uiFile(file, scope)) {
        continue;
      }
      for (final method in file.methods) {
        if (_uiMethods.contains(method.name) ||
            method.name.startsWith('build')) {
          continue;
        }
        if (method.complexity < threshold) {
          continue;
        }
        findings.add(
          emit(
            this,
            scope,
            message:
                'Method ${method.name} in a UI file has cyclomatic complexity ${method.complexity} (threshold $threshold).',
            path: file.path,
            line: method.line,
            column: method.column,
            enclosing: method.name,
          ),
        );
      }
    }
    return findings;
  }
}

/// Heuristic that flags database imports or raw SQL calls inside UI files.
///
/// Generated files are skipped. A file that imports any name in
/// [databasePackages] is reported and is not also scanned for call sites.
/// Otherwise the first recorded database call in that file is reported.
final class DirectDatabaseAccessRule implements AuditRule {
  @override
  String get id => 'FG-ARCH-004';
  @override
  String get title => 'Direct database access from UI';
  @override
  String get category => 'architecture';
  @override
  Severity get defaultSeverity => Severity.high;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.architecture;
  @override
  String get description =>
      'Heuristic that flags widget or presentation files importing a database package or calling raw SQL helpers.';
  @override
  String get recommendation =>
      'Keep database calls behind the project\'s data boundary. This is not proof that the call is unsafe.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final file in scope.project.dartIndex.files) {
      if (file.generated || !_uiFile(file, scope)) {
        continue;
      }
      final imported = file.importedPackages.intersection(databasePackages);
      if (imported.isNotEmpty) {
        findings.add(
          emit(
            this,
            scope,
            message: 'UI file imports database package ${imported.join(', ')}.',
            path: file.path,
          ),
        );
        continue;
      }
      if (file.databaseCalls.isNotEmpty) {
        final call = file.databaseCalls.first;
        findings.add(
          emit(
            this,
            scope,
            message: 'UI file calls ${call.label}.',
            path: file.path,
            line: call.line,
            column: call.column,
            enclosing: call.enclosing,
          ),
        );
      }
    }
    return findings;
  }
}

/// Flags `lib/features` imports that reach into another feature's internals.
///
/// Returns no findings when `architecture.featureCoupling` is off. An import
/// of `lib/features/<name>/<name>.dart` is allowed; any other file under a
/// different feature directory is reported.
final class FeatureCouplingRule implements AuditRule {
  @override
  String get id => 'FG-ARCH-005';
  @override
  String get title => 'Feature coupling';
  @override
  String get category => 'architecture';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.architecture;
  @override
  String get description =>
      'Flags lib/features imports that cross feature folders, except the public barrel lib/features/<name>/<name>.dart.';
  @override
  String get recommendation =>
      'Import another feature only through its public barrel, or move the shared type to lib/shared or lib/core.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    if (!scope.config.architecture.featureCoupling) {
      return const [];
    }
    final feature = RegExp(r'^lib/features/([^/]+)/');
    final findings = <Finding>[];
    for (final file in scope.project.dartIndex.files) {
      final source = feature.firstMatch(file.path);
      if (source == null) {
        continue;
      }
      for (final import in file.imports) {
        final target = import.targetPath;
        if (target == null) {
          continue;
        }
        final other = feature.firstMatch(target);
        if (other == null || other.group(1) == source.group(1)) {
          continue;
        }
        final name = other.group(1)!;
        final barrel = 'lib/features/$name/$name.dart';
        if (target == barrel) {
          continue;
        }
        findings.add(
          emit(
            this,
            scope,
            message:
                'Feature ${source.group(1)} imports ${other.group(1)} internals at $target.',
            path: file.path,
            line: import.line,
            column: import.column,
          ),
        );
      }
    }
    return findings;
  }
}

String? _layer(String path, List<LayerPolicy> layers) {
  for (final layer in layers) {
    for (final pattern in layer.paths) {
      if (GlobMatcher(pattern).matches(path)) {
        return layer.name;
      }
    }
  }
  return null;
}

bool _uiFile(DartFileFacts file, RuleScope scope) {
  if (file.containsWidget) {
    return true;
  }
  final layer = _layer(file.path, scope.config.architecture.layers);
  return layer == 'presentation';
}

/// Built-in architecture rules, in a stable evaluation order.
List<AuditRule> architectureRules() => [
  LayerDependencyRule(),
  CircularImportRule(),
  BusinessLogicPlacementRule(),
  DirectDatabaseAccessRule(),
  FeatureCouplingRule(),
];
