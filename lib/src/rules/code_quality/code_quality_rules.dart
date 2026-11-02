import '../../analyzer/dart_index.dart';
import '../../core/config.dart';
import '../../core/finding.dart';
import '../../core/severity.dart';
import '../rule.dart';

final class ComplexityRule implements AuditRule {
  @override
  String get id => 'FG-QUAL-001';
  @override
  String get title => 'Excessive complexity';
  @override
  String get category => 'codeQuality';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.codeQuality;
  @override
  String get description =>
      'Reports methods whose cyclomatic complexity exceeds codeQuality.complexityThreshold.';
  @override
  String get recommendation =>
      'Split the method or lower the decision count. The threshold is configurable.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final threshold = scope.config.codeQuality.complexityThreshold;
    final findings = <Finding>[];
    for (final file in _sources(scope)) {
      for (final method in file.methods) {
        if (method.complexity <= threshold) {
          continue;
        }
        findings.add(
          emit(
            this,
            scope,
            message:
                '${method.name} has cyclomatic complexity ${method.complexity}, above $threshold.',
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

final class LargeClassRule implements AuditRule {
  @override
  String get id => 'FG-QUAL-002';
  @override
  String get title => 'Large class';
  @override
  String get category => 'codeQuality';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.codeQuality;
  @override
  String get description =>
      'Reports classes longer than codeQuality.classLineThreshold.';
  @override
  String get recommendation =>
      'Split the type or raise the configured threshold.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final threshold = scope.config.codeQuality.classLineThreshold;
    final findings = <Finding>[];
    for (final file in _sources(scope)) {
      for (final declaration in file.classes) {
        if (declaration.lines <= threshold) {
          continue;
        }
        findings.add(
          emit(
            this,
            scope,
            message:
                'Class ${declaration.name} is ${declaration.lines} lines, above $threshold.',
            path: file.path,
            line: declaration.line,
            column: declaration.column,
            enclosing: declaration.name,
          ),
        );
      }
    }
    return findings;
  }
}

final class LargeMethodRule implements AuditRule {
  @override
  String get id => 'FG-QUAL-003';
  @override
  String get title => 'Large method';
  @override
  String get category => 'codeQuality';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.codeQuality;
  @override
  String get description =>
      'Reports methods longer than codeQuality.methodLineThreshold.';
  @override
  String get recommendation =>
      'Extract helpers or raise the configured threshold.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final threshold = scope.config.codeQuality.methodLineThreshold;
    final findings = <Finding>[];
    for (final file in _sources(scope)) {
      for (final method in file.methods) {
        if (method.lines <= threshold) {
          continue;
        }
        findings.add(
          emit(
            this,
            scope,
            message:
                '${method.name} is ${method.lines} lines, above $threshold.',
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

final class TodoRule implements AuditRule {
  @override
  String get id => 'FG-QUAL-004';
  @override
  String get title => 'TODO or FIXME comment';
  @override
  String get category => 'codeQuality';
  @override
  Severity get defaultSeverity => Severity.info;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.codeQuality;
  @override
  String get description => 'Reports TODO, FIXME, HACK, and XXX comments.';
  @override
  String get recommendation =>
      'Resolve the comment or suppress it with a reason.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final file in _sources(scope)) {
      for (final comment in file.comments) {
        findings.add(
          emit(
            this,
            scope,
            message: '${comment.tag} comment.',
            path: file.path,
            line: comment.line,
            column: comment.column,
          ),
        );
      }
    }
    return findings;
  }
}

final class DebugPrintRule implements AuditRule {
  @override
  String get id => 'FG-QUAL-005';
  @override
  String get title => 'Debug print';
  @override
  String get category => 'codeQuality';
  @override
  Severity get defaultSeverity => Severity.low;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.codeQuality;
  @override
  String get description => 'Reports print and debugPrint calls from the AST.';
  @override
  String get recommendation =>
      'Remove the call or use a logger that is disabled in release builds.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final file in _sources(scope)) {
      for (final call in file.prints) {
        findings.add(
          emit(
            this,
            scope,
            message: '${call.name}() call.',
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

final class EmptyCatchRule implements AuditRule {
  @override
  String get id => 'FG-QUAL-006';
  @override
  String get title => 'Empty catch';
  @override
  String get category => 'codeQuality';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.codeQuality;
  @override
  String get description =>
      'Reports catch clauses whose block has no statements.';
  @override
  String get recommendation =>
      'Handle the error, rethrow it, or document the ignore.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final file in _sources(scope)) {
      for (final clause in file.catches) {
        if (!clause.empty) {
          continue;
        }
        findings.add(
          emit(
            this,
            scope,
            message: 'Empty catch block.',
            path: file.path,
            line: clause.line,
            column: clause.column,
            enclosing: clause.enclosing,
          ),
        );
      }
    }
    return findings;
  }
}

final class SuspiciousAsyncRule implements AuditRule {
  @override
  String get id => 'FG-QUAL-007';
  @override
  String get title => 'Suspicious asynchronous pattern';
  @override
  String get category => 'codeQuality';
  @override
  Severity get defaultSeverity => Severity.low;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.codeQuality;
  @override
  String get description =>
      'Reports async bodies with no await, and unawaited calls to project functions declared to return Future.';
  @override
  String get recommendation =>
      'Await the future, return it, or wrap it in unawaited. Declaration types are syntactic, not inferred.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final file in _sources(scope)) {
      for (final function in file.asyncWithoutAwait) {
        findings.add(
          emit(
            this,
            scope,
            message: '${function.name} is async but does not await.',
            path: file.path,
            line: function.line,
            column: function.column,
            enclosing: function.name,
            heuristic: false,
          ),
        );
      }
      final futures = futureFunctionsVisibleTo(file, scope.project.dartIndex);
      for (final call in file.bareCalls) {
        if (call.name == 'unawaited' || !futures.contains(call.name)) {
          continue;
        }
        findings.add(
          emit(
            this,
            scope,
            message:
                'Call to Future-returning ${call.name}() is not awaited. This uses declared return types only.',
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

final class UnusedImportRule implements AuditRule {
  @override
  String get id => 'FG-QUAL-008';
  @override
  String get title => 'Unused import';
  @override
  String get category => 'codeQuality';
  @override
  Severity get defaultSeverity => Severity.low;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.codeQuality;
  @override
  String get description =>
      'Reports unused imports from the AST. Only prefix, show, and redundant dart:core imports are auto-fixable.';
  @override
  String get recommendation =>
      'Remove the import. Bare imports that may exist for extensions are reported and not auto-fixed.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final file in _sources(scope)) {
      for (final import in file.imports) {
        if (!import.unused) {
          continue;
        }
        findings.add(
          emit(
            this,
            scope,
            message: 'Unused import ${import.uri}. ${import.unusedReason}',
            path: file.path,
            line: import.line,
            column: import.column,
            fixId: import.autoFixable ? 'remove-unused-import' : null,
            fixPayload: import.autoFixable ? import.lineText : null,
            heuristic: !import.autoFixable,
          ),
        );
      }
    }
    return findings;
  }
}

final class ParseErrorRule implements AuditRule {
  @override
  String get id => 'FG-QUAL-009';
  @override
  String get title => 'Dart parse error';
  @override
  String get category => 'codeQuality';
  @override
  Severity get defaultSeverity => Severity.low;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.codeQuality;
  @override
  String get description =>
      'Reports syntax errors found while parsing Dart files.';
  @override
  String get recommendation =>
      'Fix the syntax error so later rules can see a complete AST.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final file in scope.project.dartIndex.files) {
      for (final error in file.parseErrors) {
        findings.add(
          emit(
            this,
            scope,
            message: 'Dart parse error: ${error.message}',
            path: file.path,
            line: error.line,
            column: error.column,
          ),
        );
      }
    }
    return findings;
  }
}

final class InvalidSuppressionRule implements AuditRule {
  @override
  String get id => 'FG-SUP-001';
  @override
  String get title => 'Suppression missing a reason';
  @override
  String get category => 'suppression';
  @override
  Severity get defaultSeverity => Severity.low;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.codeQuality;
  @override
  String get description =>
      'Inline flutterguard:ignore comments must include a rule id and a reason.';
  @override
  String get recommendation =>
      'Use `// flutterguard:ignore FG-QUAL-005 reason: why this is accepted`.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final file in scope.project.dartIndex.files) {
      for (final ignore in file.ignores) {
        if (ignore.valid) {
          continue;
        }
        findings.add(
          emit(
            this,
            scope,
            message: 'Suppression comment is missing a rule id or reason and was not applied.',
            path: file.path,
            line: ignore.line,
          ),
        );
      }
    }
    return findings;
  }
}

Iterable<DartFileFacts> _sources(RuleScope scope) {
  return scope.project.dartIndex.files.where((file) => !file.generated);
}

List<AuditRule> codeQualityRules() => [
  ComplexityRule(),
  LargeClassRule(),
  LargeMethodRule(),
  TodoRule(),
  DebugPrintRule(),
  EmptyCatchRule(),
  SuspiciousAsyncRule(),
  UnusedImportRule(),
  ParseErrorRule(),
  InvalidSuppressionRule(),
];
