import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as p;

import '../context/file_index.dart';
import 'complexity.dart';

final class ImportFact {
  const ImportFact({
    required this.uri,
    required this.prefix,
    required this.shown,
    required this.hidden,
    required this.deferred,
    required this.line,
    required this.column,
    required this.singleLine,
    required this.lineText,
    required this.targetPath,
    required this.unused,
    required this.autoFixable,
    required this.unusedReason,
  });

  final String uri;
  final String? prefix;
  final List<String> shown;
  final List<String> hidden;
  final bool deferred;
  final int line;
  final int column;
  final bool singleLine;
  final String lineText;
  final String? targetPath;
  final bool unused;
  final bool autoFixable;
  final String unusedReason;
}

final class ExportFact {
  const ExportFact({
    required this.uri,
    required this.shown,
    required this.hidden,
    required this.targetPath,
  });

  final String uri;
  final List<String> shown;
  final List<String> hidden;
  final String? targetPath;
}

final class CommentFact {
  const CommentFact({
    required this.line,
    required this.column,
    required this.tag,
    required this.text,
  });

  final int line;
  final int column;
  final String tag;
  final String text;
}

final class MethodFact {
  const MethodFact({
    required this.name,
    required this.owner,
    required this.line,
    required this.column,
    required this.lines,
    required this.complexity,
    required this.returnsFuture,
  });

  final String name;
  final String? owner;
  final int line;
  final int column;
  final int lines;
  final int complexity;
  final bool returnsFuture;
}

final class ClassFact {
  const ClassFact({
    required this.name,
    required this.superclass,
    required this.line,
    required this.column,
    required this.lines,
  });

  final String name;
  final String? superclass;
  final int line;
  final int column;
  final int lines;

  bool get isWidget {
    const widgets = {
      'StatelessWidget',
      'StatefulWidget',
      'ConsumerWidget',
      'ConsumerStatefulWidget',
      'HookWidget',
      'StatelessHookWidget',
      'State',
    };
    final name = superclass;
    if (name == null) {
      return false;
    }
    return widgets.contains(name) || name.startsWith('State');
  }
}

final class CatchFact {
  const CatchFact({
    required this.line,
    required this.column,
    required this.empty,
    required this.enclosing,
  });

  final int line;
  final int column;
  final bool empty;
  final String? enclosing;
}

final class InvocationFact {
  const InvocationFact({
    required this.line,
    required this.column,
    required this.name,
    required this.enclosing,
    required this.sensitive,
  });

  final int line;
  final int column;
  final String name;
  final String? enclosing;
  final bool sensitive;
}

final class StringFact {
  const StringFact({
    required this.line,
    required this.column,
    required this.value,
    required this.enclosing,
  });

  final int line;
  final int column;
  final String value;
  final String? enclosing;
}

final class WidgetStringFact {
  const WidgetStringFact({
    required this.line,
    required this.column,
    required this.value,
    required this.kind,
  });

  final int line;
  final int column;
  final String value;
  final String kind;
}

final class AsyncFact {
  const AsyncFact({
    required this.name,
    required this.line,
    required this.column,
    required this.owner,
  });

  final String name;
  final int line;
  final int column;
  final String? owner;
}

final class BareCallFact {
  const BareCallFact({
    required this.name,
    required this.line,
    required this.column,
    required this.enclosing,
  });

  final String name;
  final int line;
  final int column;
  final String? enclosing;
}

final class LocationFact {
  const LocationFact({
    required this.line,
    required this.column,
    required this.label,
    required this.enclosing,
  });

  final int line;
  final int column;
  final String label;
  final String? enclosing;
}

final class StorageFact {
  const StorageFact({
    required this.line,
    required this.column,
    required this.key,
    required this.method,
  });

  final int line;
  final int column;
  final String key;
  final String method;
}

final class ParseFact {
  const ParseFact({
    required this.line,
    required this.column,
    required this.message,
  });

  final int line;
  final int column;
  final String message;
}

final class InlineIgnore {
  const InlineIgnore({
    required this.line,
    required this.ruleId,
    required this.reason,
    required this.valid,
  });

  final int line;
  final String? ruleId;
  final String? reason;
  final bool valid;
}

final class DartFileFacts {
  const DartFileFacts({
    required this.path,
    required this.generated,
    required this.imports,
    required this.exports,
    required this.identifiers,
    required this.publicNames,
    required this.comments,
    required this.methods,
    required this.classes,
    required this.catches,
    required this.prints,
    required this.sensitiveLogs,
    required this.strings,
    required this.widgetStrings,
    required this.asyncWithoutAwait,
    required this.bareCalls,
    required this.tlsBypasses,
    required this.databaseCalls,
    required this.insecureStores,
    required this.parseErrors,
    required this.ignores,
    required this.importedPackages,
    required this.futureFunctions,
    required this.importsSharedPreferences,
  });

  final String path;
  final bool generated;
  final List<ImportFact> imports;
  final List<ExportFact> exports;
  final Set<String> identifiers;
  final Set<String> publicNames;
  final List<CommentFact> comments;
  final List<MethodFact> methods;
  final List<ClassFact> classes;
  final List<CatchFact> catches;
  final List<InvocationFact> prints;
  final List<InvocationFact> sensitiveLogs;
  final List<StringFact> strings;
  final List<WidgetStringFact> widgetStrings;
  final List<AsyncFact> asyncWithoutAwait;
  final List<BareCallFact> bareCalls;
  final List<LocationFact> tlsBypasses;
  final List<LocationFact> databaseCalls;
  final List<StorageFact> insecureStores;
  final List<ParseFact> parseErrors;
  final List<InlineIgnore> ignores;
  final Set<String> importedPackages;
  final Map<String, bool> futureFunctions;
  final bool importsSharedPreferences;

  bool get containsWidget => classes.any((item) => item.isWidget);
}

final class DartIndex {
  const DartIndex({required this.files, required this.cycles});

  final List<DartFileFacts> files;
  final List<String> cycles;

  DartFileFacts? operator [](String path) {
    for (final file in files) {
      if (file.path == path) {
        return file;
      }
    }
    return null;
  }
}

DartIndex buildDartIndex({
  required List<IndexedFile> files,
  required String packageName,
}) {
  final parsed = <_Parsed>[];
  for (final file in files) {
    if (!file.relativePosix.endsWith('.dart') || file.text == null) {
      continue;
    }
    parsed.add(_parse(file, packageName));
  }
  final byPath = {for (final item in parsed) item.path: item};
  final resolved = [
    for (final item in parsed) _resolve(item, byPath, packageName),
  ];
  final graph = <String, Set<String>>{};
  for (final file in resolved) {
    graph[file.path] = {
      for (final import in file.imports)
        if (import.targetPath != null) import.targetPath!,
    };
  }
  return DartIndex(files: resolved, cycles: _cycles(graph));
}

final class _Parsed {
  _Parsed({
    required this.path,
    required this.generated,
    required this.rawImports,
    required this.exports,
    required this.identifiers,
    required this.publicNames,
    required this.comments,
    required this.methods,
    required this.classes,
    required this.catches,
    required this.prints,
    required this.sensitiveLogs,
    required this.strings,
    required this.widgetStrings,
    required this.asyncWithoutAwait,
    required this.bareCalls,
    required this.tlsBypasses,
    required this.databaseCalls,
    required this.insecureStores,
    required this.parseErrors,
    required this.ignores,
    required this.importedPackages,
    required this.futureFunctions,
    required this.importsSharedPreferences,
  });

  final String path;
  final bool generated;
  final List<_RawImport> rawImports;
  final List<ExportFact> exports;
  final Set<String> identifiers;
  final Set<String> publicNames;
  final List<CommentFact> comments;
  final List<MethodFact> methods;
  final List<ClassFact> classes;
  final List<CatchFact> catches;
  final List<InvocationFact> prints;
  final List<InvocationFact> sensitiveLogs;
  final List<StringFact> strings;
  final List<WidgetStringFact> widgetStrings;
  final List<AsyncFact> asyncWithoutAwait;
  final List<BareCallFact> bareCalls;
  final List<LocationFact> tlsBypasses;
  final List<LocationFact> databaseCalls;
  final List<StorageFact> insecureStores;
  final List<ParseFact> parseErrors;
  final List<InlineIgnore> ignores;
  final Set<String> importedPackages;
  final Map<String, bool> futureFunctions;
  final bool importsSharedPreferences;
}

final class _RawImport {
  const _RawImport({
    required this.uri,
    required this.prefix,
    required this.shown,
    required this.hidden,
    required this.deferred,
    required this.line,
    required this.column,
    required this.singleLine,
    required this.lineText,
    required this.targetPath,
  });

  final String uri;
  final String? prefix;
  final List<String> shown;
  final List<String> hidden;
  final bool deferred;
  final int line;
  final int column;
  final bool singleLine;
  final String lineText;
  final String? targetPath;
}

_Parsed _parse(IndexedFile file, String packageName) {
  final content = file.text ?? '';
  final result = parseString(
    content: content,
    path: file.relativePosix,
    throwIfDiagnostics: false,
  );
  final collector = _Collector(
    path: file.relativePosix,
    content: content,
    lineInfo: result.lineInfo,
    packageName: packageName,
  );
  result.unit.accept(collector);
  collector.collectComments(result.unit);
  final errors = <ParseFact>[];
  for (final error in result.errors) {
    final location = result.lineInfo.getLocation(error.offset);
    errors.add(
      ParseFact(
        line: location.lineNumber,
        column: location.columnNumber,
        message: error.message,
      ),
    );
  }
  return _Parsed(
    path: file.relativePosix,
    generated: _generated(file.relativePosix, content),
    rawImports: collector.imports,
    exports: collector.exports,
    identifiers: collector.identifiers,
    publicNames: collector.publicNames,
    comments: collector.comments,
    methods: collector.methods,
    classes: collector.classes,
    catches: collector.catches,
    prints: collector.prints,
    sensitiveLogs: collector.sensitiveLogs,
    strings: collector.strings,
    widgetStrings: collector.widgetStrings,
    asyncWithoutAwait: collector.asyncWithoutAwait,
    bareCalls: collector.bareCalls,
    tlsBypasses: collector.tlsBypasses,
    databaseCalls: collector.databaseCalls,
    insecureStores: collector.insecureStores,
    parseErrors: errors,
    ignores: collector.ignores,
    importedPackages: collector.importedPackages,
    futureFunctions: collector.futureFunctions,
    importsSharedPreferences: collector.importsSharedPreferences,
  );
}

bool _generated(String path, String content) {
  return path.endsWith('.g.dart') ||
      path.endsWith('.freezed.dart') ||
      path.endsWith('.gr.dart') ||
      content.contains('// GENERATED CODE') ||
      content.contains('// Generated by');
}

DartFileFacts _resolve(
  _Parsed parsed,
  Map<String, _Parsed> byPath,
  String packageName,
) {
  final imports = <ImportFact>[];
  for (final import in parsed.rawImports) {
    final unused = _unusedImport(import, parsed, byPath);
    imports.add(
      ImportFact(
        uri: import.uri,
        prefix: import.prefix,
        shown: import.shown,
        hidden: import.hidden,
        deferred: import.deferred,
        line: import.line,
        column: import.column,
        singleLine: import.singleLine,
        lineText: import.lineText,
        targetPath: import.targetPath,
        unused: unused.unused,
        autoFixable: unused.autoFixable,
        unusedReason: unused.reason,
      ),
    );
  }
  return DartFileFacts(
    path: parsed.path,
    generated: parsed.generated,
    imports: imports,
    exports: parsed.exports,
    identifiers: parsed.identifiers,
    publicNames: parsed.publicNames,
    comments: parsed.comments,
    methods: parsed.methods,
    classes: parsed.classes,
    catches: parsed.catches,
    prints: parsed.prints,
    sensitiveLogs: parsed.sensitiveLogs,
    strings: parsed.strings,
    widgetStrings: parsed.widgetStrings,
    asyncWithoutAwait: parsed.asyncWithoutAwait,
    bareCalls: parsed.bareCalls,
    tlsBypasses: parsed.tlsBypasses,
    databaseCalls: parsed.databaseCalls,
    insecureStores: parsed.insecureStores,
    parseErrors: parsed.parseErrors,
    ignores: parsed.ignores,
    importedPackages: parsed.importedPackages,
    futureFunctions: parsed.futureFunctions,
    importsSharedPreferences: parsed.importsSharedPreferences,
  );
}

final class _Unused {
  const _Unused(this.unused, this.autoFixable, this.reason);
  const _Unused.used() : this(false, false, '');

  final bool unused;
  final bool autoFixable;
  final String reason;
}

_Unused _unusedImport(
  _RawImport import,
  _Parsed parsed,
  Map<String, _Parsed> byPath,
) {
  if (import.deferred) {
    return const _Unused.used();
  }
  final used = parsed.identifiers;
  if (import.prefix != null) {
    if (!used.contains(import.prefix)) {
      return _Unused(
        true,
        import.singleLine,
        'Prefix "${import.prefix}" is never used.',
      );
    }
    return const _Unused.used();
  }
  if (import.shown.isNotEmpty &&
      import.shown.every((name) => !used.contains(name))) {
    return _Unused(
      true,
      import.singleLine,
      'None of the shown names are used.',
    );
  }
  if (import.uri == 'dart:core' &&
      import.shown.isEmpty &&
      import.hidden.isEmpty) {
    return _Unused(
      true,
      import.singleLine,
      'dart:core is imported automatically.',
    );
  }
  final target = import.targetPath == null ? null : byPath[import.targetPath];
  if (target == null || import.shown.isNotEmpty) {
    return const _Unused.used();
  }
  final names = _availableNames(target, byPath, <String>{});
  if (names.isEmpty) {
    return const _Unused.used();
  }
  final visible = names.where((name) => !import.hidden.contains(name));
  if (visible.every((name) => !used.contains(name))) {
    return const _Unused(
      true,
      false,
      'None of the imported library names are referenced. Not auto-fixed because the import may provide an extension.',
    );
  }
  return const _Unused.used();
}

Set<String> _availableNames(
  _Parsed file,
  Map<String, _Parsed> byPath,
  Set<String> stack,
) {
  if (!stack.add(file.path)) {
    return const {};
  }
  final names = {...file.publicNames};
  for (final export in file.exports) {
    final target = export.targetPath == null ? null : byPath[export.targetPath];
    if (target == null) {
      continue;
    }
    var exported = _availableNames(target, byPath, stack);
    if (export.shown.isNotEmpty) {
      exported = exported.where(export.shown.contains).toSet();
    }
    exported.removeAll(export.hidden);
    names.addAll(exported);
  }
  stack.remove(file.path);
  return names;
}

List<String> _cycles(Map<String, Set<String>> graph) {
  final color = <String, int>{};
  final stack = <String>[];
  final found = <String>{};
  void visit(String node) {
    color[node] = 1;
    stack.add(node);
    final nextNodes = (graph[node] ?? const <String>{}).toList()..sort();
    for (final next in nextNodes) {
      final state = color[next] ?? 0;
      if (state == 1) {
        final start = stack.indexOf(next);
        if (start >= 0) {
          found.add(_canonical([...stack.sublist(start), next]));
        }
      } else if (state == 0) {
        visit(next);
      }
    }
    stack.removeLast();
    color[node] = 2;
  }

  final nodes = graph.keys.toList()..sort();
  for (final node in nodes) {
    if ((color[node] ?? 0) == 0) {
      visit(node);
    }
  }
  final cycles = found.toList()..sort();
  return cycles;
}

String _canonical(List<String> cycle) {
  final body = cycle.sublist(0, cycle.length - 1);
  var best = _rotation(body);
  final reversed = body.reversed.toList();
  final other = _rotation(reversed);
  if (other.compareTo(best) < 0) {
    best = other;
  }
  return best;
}

String _rotation(List<String> body) {
  var best = '';
  for (var i = 0; i < body.length; i++) {
    final rotated = [...body.sublist(i), ...body.sublist(0, i)];
    final text = '${rotated.join(' -> ')} -> ${rotated.first}';
    if (best.isEmpty || text.compareTo(best) < 0) {
      best = text;
    }
  }
  return best;
}

String? resolveDartUri({
  required String fromPath,
  required String uri,
  required String packageName,
}) {
  if (uri.startsWith('dart:')) {
    return null;
  }
  if (uri.startsWith('package:')) {
    final rest = uri.substring('package:'.length);
    final slash = rest.indexOf('/');
    if (slash <= 0) {
      return null;
    }
    final name = rest.substring(0, slash);
    if (name != packageName) {
      return null;
    }
    return 'lib/${rest.substring(slash + 1)}';
  }
  if (uri.contains(':')) {
    return null;
  }
  final normalized = p.posix.normalize(
    p.posix.join(p.posix.dirname(fromPath), uri),
  );
  if (normalized.startsWith('../') || normalized == '..') {
    return null;
  }
  return normalized;
}

final _todoPattern = RegExp(r'\b(TODO|FIXME|HACK|XXX)\b');
final _ignorePattern = RegExp(
  r'flutterguard:ignore\s+(FG-[A-Z0-9-]+)\s+reason:\s*(.+)',
);
final _sensitivePattern = RegExp(
  r'(password|secret|token|api[_-]?key|credential|authorization)',
  caseSensitive: false,
);
const _databaseCalls = {
  'rawQuery',
  'rawInsert',
  'rawUpdate',
  'rawDelete',
  'openDatabase',
};
const _widgetArguments = {
  'hintText',
  'labelText',
  'helperText',
  'tooltip',
  'semanticLabel',
  'semanticsLabel',
};

final class _Collector extends RecursiveAstVisitor<void> {
  _Collector({
    required this.path,
    required this.content,
    required this.lineInfo,
    required this.packageName,
  });

  final String path;
  final String content;
  final LineInfo lineInfo;
  final String packageName;
  final List<String> owners = [];
  final List<_RawImport> imports = [];
  final List<ExportFact> exports = [];
  final identifiers = <String>{};
  final publicNames = <String>{};
  final comments = <CommentFact>[];
  final methods = <MethodFact>[];
  final classes = <ClassFact>[];
  final catches = <CatchFact>[];
  final prints = <InvocationFact>[];
  final sensitiveLogs = <InvocationFact>[];
  final strings = <StringFact>[];
  final widgetStrings = <WidgetStringFact>[];
  final asyncWithoutAwait = <AsyncFact>[];
  final bareCalls = <BareCallFact>[];
  final tlsBypasses = <LocationFact>[];
  final databaseCalls = <LocationFact>[];
  final insecureStores = <StorageFact>[];
  final ignores = <InlineIgnore>[];
  final importedPackages = <String>{};
  final futureFunctions = <String, bool>{};
  bool importsSharedPreferences = false;

  void collectComments(CompilationUnit unit) {
    Token? token = unit.beginToken;
    while (token != null && (!token.isEof || token.precedingComments != null)) {
      Token? comment = token.precedingComments;
      while (comment != null) {
        if (comment.type == TokenType.SINGLE_LINE_COMMENT ||
            comment.type == TokenType.MULTI_LINE_COMMENT) {
          _onComment(comment);
        }
        comment = comment.next;
      }
      if (identical(token.next, token)) {
        break;
      }
      token = token.next;
    }
  }

  void _onComment(Token comment) {
    final location = lineInfo.getLocation(comment.offset);
    final text = comment.lexeme;
    final todo = _todoPattern.firstMatch(text);
    if (todo != null) {
      comments.add(
        CommentFact(
          line: location.lineNumber,
          column: location.columnNumber,
          tag: todo.group(1)!,
          text: text.replaceAll(RegExp(r'\s+'), ' ').trim(),
        ),
      );
    }
    if (text.contains('flutterguard:ignore')) {
      final match = _ignorePattern.firstMatch(text);
      if (match == null) {
        ignores.add(
          InlineIgnore(
            line: location.lineNumber,
            ruleId: null,
            reason: null,
            valid: false,
          ),
        );
      } else {
        var reason = match.group(2)!.trim();
        if (reason.endsWith('*/')) {
          reason = reason.substring(0, reason.length - 2).trim();
        }
        ignores.add(
          InlineIgnore(
            line: location.lineNumber,
            ruleId: match.group(1),
            reason: reason,
            valid: reason.isNotEmpty,
          ),
        );
      }
    }
  }

  ({int line, int column}) _at(int offset) {
    final location = lineInfo.getLocation(offset);
    return (line: location.lineNumber, column: location.columnNumber);
  }

  String? get _owner => owners.isEmpty ? null : owners.last;

  void _addPublic(String name) {
    if (!name.startsWith('_')) {
      publicNames.add(name);
    }
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    identifiers.add(node.name);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    final uri = node.uri.stringValue;
    if (uri != null) {
      final shown = <String>[];
      final hidden = <String>[];
      for (final combinator in node.combinators) {
        if (combinator is ShowCombinator) {
          shown.addAll(combinator.shownNames.map((name) => name.name));
        } else if (combinator is HideCombinator) {
          hidden.addAll(combinator.hiddenNames.map((name) => name.name));
        }
      }
      final start = _at(node.offset);
      final end = _at(node.end);
      final lines = content.split('\n');
      final lineText = start.line > 0 && start.line <= lines.length
          ? lines[start.line - 1].trim()
          : '';
      imports.add(
        _RawImport(
          uri: uri,
          prefix: node.prefix?.name,
          shown: shown,
          hidden: hidden,
          deferred: node.deferredKeyword != null,
          line: start.line,
          column: start.column,
          singleLine: start.line == end.line,
          lineText: lineText,
          targetPath: resolveDartUri(
            fromPath: path,
            uri: uri,
            packageName: packageName,
          ),
        ),
      );
      if (uri.startsWith('package:')) {
        final rest = uri.substring('package:'.length);
        final slash = rest.indexOf('/');
        final name = slash == -1 ? rest : rest.substring(0, slash);
        if (name.isNotEmpty) {
          importedPackages.add(name);
        }
        if (name == 'shared_preferences') {
          importsSharedPreferences = true;
        }
      }
    }
  }

  @override
  void visitExportDirective(ExportDirective node) {
    final uri = node.uri.stringValue;
    if (uri == null) {
      return;
    }
    final shown = <String>[];
    final hidden = <String>[];
    for (final combinator in node.combinators) {
      if (combinator is ShowCombinator) {
        shown.addAll(combinator.shownNames.map((name) => name.name));
      } else if (combinator is HideCombinator) {
        hidden.addAll(combinator.hiddenNames.map((name) => name.name));
      }
    }
    exports.add(
      ExportFact(
        uri: uri,
        shown: shown,
        hidden: hidden,
        targetPath: resolveDartUri(
          fromPath: path,
          uri: uri,
          packageName: packageName,
        ),
      ),
    );
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final name = node.namePart.typeName.lexeme;
    _addPublic(name);
    final at = _at(node.offset);
    classes.add(
      ClassFact(
        name: name,
        superclass: node.extendsClause?.superclass.name.lexeme,
        line: at.line,
        column: at.column,
        lines: lineSpan(node, (offset) => _at(offset).line),
      ),
    );
    owners.add(name);
    super.visitClassDeclaration(node);
    owners.removeLast();
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    _addPublic(node.namePart.typeName.lexeme);
    super.visitEnumDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _addPublic(node.name.lexeme);
    super.visitMixinDeclaration(node);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    final name = node.name?.lexeme;
    if (name != null) {
      _addPublic(name);
    }
    super.visitExtensionDeclaration(node);
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    _addPublic(node.name.lexeme);
    super.visitGenericTypeAlias(node);
  }

  @override
  void visitClassTypeAlias(ClassTypeAlias node) {
    _addPublic(node.name.lexeme);
    super.visitClassTypeAlias(node);
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    _addPublic(node.name.lexeme);
    super.visitFunctionTypeAlias(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final name = node.name.lexeme;
    _addPublic(name);
    final returnsFuture = _returnsFuture(node.returnType);
    if (node.parent is CompilationUnit) {
      futureFunctions[name] = returnsFuture;
    }
    _recordCallable(
      name: name,
      node: node,
      body: node.functionExpression.body,
      returnsFuture: returnsFuture,
    );
    owners.add(name);
    super.visitFunctionDeclaration(node);
    owners.removeLast();
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _recordCallable(
      name: node.name.lexeme,
      node: node,
      body: node.body,
      returnsFuture: _returnsFuture(node.returnType),
    );
    owners.add(node.name.lexeme);
    super.visitMethodDeclaration(node);
    owners.removeLast();
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final name = node.name?.lexeme ?? node.typeName?.name ?? 'constructor';
    _recordCallable(
      name: name,
      node: node,
      body: node.body,
      returnsFuture: false,
    );
    owners.add(name);
    super.visitConstructorDeclaration(node);
    owners.removeLast();
  }

  void _recordCallable({
    required String name,
    required AstNode node,
    required FunctionBody body,
    required bool returnsFuture,
  }) {
    if (body is EmptyFunctionBody) {
      return;
    }
    final at = _at(node.offset);
    methods.add(
      MethodFact(
        name: name,
        owner: _owner,
        line: at.line,
        column: at.column,
        lines: lineSpan(node, (offset) => _at(offset).line),
        complexity: cyclomaticComplexity(node),
        returnsFuture: returnsFuture,
      ),
    );
    if (body.isAsynchronous && !_containsAwait(body)) {
      asyncWithoutAwait.add(
        AsyncFact(name: name, line: at.line, column: at.column, owner: _owner),
      );
    }
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (final variable in node.variables.variables) {
      _addPublic(variable.name.lexeme);
    }
    super.visitTopLevelVariableDeclaration(node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (node.parent is AdjacentStrings) {
      return;
    }
    _recordString(node.offset, node.value);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    final value = node.stringValue;
    if (value != null) {
      _recordString(node.offset, value);
    }
    super.visitAdjacentStrings(node);
  }

  void _recordString(int offset, String value) {
    if (value.length > 2000) {
      return;
    }
    final at = _at(offset);
    strings.add(
      StringFact(
        line: at.line,
        column: at.column,
        value: value,
        enclosing: _owner,
      ),
    );
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name.lexeme;
    if (typeName == 'Text' && node.argumentList.arguments.isNotEmpty) {
      final value = _literal(
        node.argumentList.arguments.first.argumentExpression,
      );
      if (value != null) {
        final at = _at(node.offset);
        widgetStrings.add(
          WidgetStringFact(
            line: at.line,
            column: at.column,
            value: value,
            kind: 'Text',
          ),
        );
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitNamedArgument(NamedArgument node) {
    final name = node.name.lexeme;
    if (_widgetArguments.contains(name)) {
      final value = _literal(node.argumentExpression);
      if (value != null) {
        final at = _at(node.offset);
        widgetStrings.add(
          WidgetStringFact(
            line: at.line,
            column: at.column,
            value: value,
            kind: name,
          ),
        );
      }
    }
    super.visitNamedArgument(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    final at = _at(node.offset);
    if (node.realTarget == null && (name == 'print' || name == 'debugPrint')) {
      final sensitive = node.argumentList.arguments.any(
        (argument) => _sensitiveExpression(argument.argumentExpression),
      );
      final fact = InvocationFact(
        line: at.line,
        column: at.column,
        name: name,
        enclosing: _owner,
        sensitive: sensitive,
      );
      prints.add(fact);
      if (sensitive) {
        sensitiveLogs.add(fact);
      }
    } else if (name == 'log' &&
        node.argumentList.arguments.any(
          (argument) => _sensitiveExpression(argument.argumentExpression),
        )) {
      sensitiveLogs.add(
        InvocationFact(
          line: at.line,
          column: at.column,
          name: name,
          enclosing: _owner,
          sensitive: true,
        ),
      );
    }
    if (name == 'badCertificateCallback' || name == 'onBadCertificate') {
      tlsBypasses.add(
        LocationFact(
          line: at.line,
          column: at.column,
          label: name,
          enclosing: _owner,
        ),
      );
    }
    if (_databaseCalls.contains(name)) {
      databaseCalls.add(
        LocationFact(
          line: at.line,
          column: at.column,
          label: name,
          enclosing: _owner,
        ),
      );
    }
    if (importsSharedPreferences &&
        (name == 'setString' || name == 'setStringList' || name == 'setInt')) {
      final arguments = node.argumentList.arguments;
      if (arguments.isNotEmpty) {
        final key = _literal(arguments.first.argumentExpression);
        if (key != null && _sensitivePattern.hasMatch(key)) {
          insecureStores.add(
            StorageFact(
              line: at.line,
              column: at.column,
              key: key,
              method: name,
            ),
          );
        }
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final left = node.leftHandSide;
    String? label;
    if (left is SimpleIdentifier &&
        (left.name == 'badCertificateCallback' ||
            left.name == 'onBadCertificate')) {
      label = left.name;
    } else if (left is PrefixedIdentifier &&
        (left.identifier.name == 'badCertificateCallback' ||
            left.identifier.name == 'onBadCertificate')) {
      label = left.identifier.name;
    } else if (left is PropertyAccess &&
        (left.propertyName.name == 'badCertificateCallback' ||
            left.propertyName.name == 'onBadCertificate')) {
      label = left.propertyName.name;
    }
    if (label != null) {
      final at = _at(node.offset);
      tlsBypasses.add(
        LocationFact(
          line: at.line,
          column: at.column,
          label: label,
          enclosing: _owner,
        ),
      );
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    final expression = node.expression;
    if (expression is MethodInvocation && expression.realTarget == null) {
      final at = _at(expression.offset);
      bareCalls.add(
        BareCallFact(
          name: expression.methodName.name,
          line: at.line,
          column: at.column,
          enclosing: _owner,
        ),
      );
    }
    super.visitExpressionStatement(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    final at = _at(node.offset);
    catches.add(
      CatchFact(
        line: at.line,
        column: at.column,
        empty: node.body.statements.isEmpty,
        enclosing: _owner,
      ),
    );
    super.visitCatchClause(node);
  }

  bool _sensitiveExpression(Expression expression) {
    if (expression is SimpleStringLiteral) {
      return _sensitivePattern.hasMatch(expression.value);
    }
    if (expression is SimpleIdentifier) {
      return _sensitivePattern.hasMatch(expression.name);
    }
    if (expression is StringInterpolation) {
      final snippet = content.substring(expression.offset, expression.end);
      return _sensitivePattern.hasMatch(snippet);
    }
    return false;
  }

  String? _literal(Expression expression) {
    if (expression is SimpleStringLiteral) {
      return expression.value;
    }
    if (expression is AdjacentStrings) {
      return expression.stringValue;
    }
    return null;
  }
}

bool _returnsFuture(TypeAnnotation? type) {
  if (type is NamedType) {
    final name = type.name.lexeme;
    return name == 'Future' || name == 'FutureOr';
  }
  return false;
}

bool _containsAwait(AstNode node) {
  final finder = _AwaitFinder();
  node.accept(finder);
  return finder.found;
}

final class _AwaitFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    found = true;
  }
}

/// Future-returning top-level functions visible to [file].
Set<String> futureFunctionsVisibleTo(DartFileFacts file, DartIndex index) {
  final names = <String>{
    for (final entry in file.futureFunctions.entries)
      if (entry.value) entry.key,
  };
  for (final import in file.imports) {
    final targetPath = import.targetPath;
    if (targetPath == null || import.prefix != null) {
      continue;
    }
    final target = index[targetPath];
    if (target == null) {
      continue;
    }
    for (final entry in target.futureFunctions.entries) {
      if (!entry.value || entry.key.startsWith('_')) {
        continue;
      }
      if (import.shown.isNotEmpty && !import.shown.contains(entry.key)) {
        continue;
      }
      if (import.hidden.contains(entry.key)) {
        continue;
      }
      names.add(entry.key);
    }
  }
  return names;
}
