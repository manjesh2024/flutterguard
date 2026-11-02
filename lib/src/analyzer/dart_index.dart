import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as p;

import '../context/file_index.dart';
import 'complexity.dart';

/// One `import` directive after URI resolution and the unused-import check.
///
/// A deferred import is recorded as used. A prefixed import is unused
/// only when its prefix is absent from the file's simple identifiers,
/// which do not include the import directive itself. An unprefixed
/// import is unused when every `show` name is unused, when it is
/// `dart:core` with no `show` or `hide`, or, when it has no `show`
/// list, when no visible name from the parsed target is referenced.
/// A missing target, an unparsed target, or a target with no public
/// or exported names stays used once those earlier checks have passed.
final class ImportFact {
  /// Creates a fact for one resolved import.
  ///
  /// Every parameter is required and is stored on the matching field.
  /// `uri` is the URI text. `prefix` is the `as` name, or null when
  /// the import has no prefix. `shown` and `hidden` are the combinator
  /// names. `deferred` reports the `deferred` keyword. `line` and
  /// `column` are the 1-based start of the directive. `singleLine`
  /// reports that the directive begins and ends on one line.
  /// `lineText` is the trimmed source of that start line. `targetPath`
  /// is the project path from [resolveDartUri], or null when the URI
  /// does not land in this package. `unused` and `autoFixable` are the
  /// unused-import result. `unusedReason` explains an unused import,
  /// or is empty when the import is used.
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

  /// Import URI as written, such as `package:foo/foo.dart`.
  final String uri;

  /// Name bound by `as`, or null when the import has no prefix.
  final String? prefix;

  /// Names gathered from every `show` combinator.
  ///
  /// Empty when the directive has no `show` combinator.
  final List<String> shown;

  /// Names gathered from every `hide` combinator.
  ///
  /// Empty when the directive hides nothing.
  final List<String> hidden;

  /// Whether the directive includes the `deferred` keyword.
  ///
  /// Deferred imports are recorded as used.
  final bool deferred;

  /// 1-based line where the import directive starts.
  final int line;

  /// 1-based column where the import directive starts.
  final int column;

  /// Whether the directive's start and end offsets share a line.
  ///
  /// Unused-import deletion consults this before removing a directive.
  final bool singleLine;

  /// Trimmed source of the line where the directive starts.
  ///
  /// Empty when that line number falls outside the file.
  final String lineText;

  /// Project-relative path of a same-package target.
  ///
  /// Null when [resolveDartUri] cannot place `uri` in this package.
  final String? targetPath;

  /// Whether this import is treated as unused.
  ///
  /// See the class description for which imports qualify. A used
  /// import stores false.
  final bool unused;

  /// Whether an unused import may be removed by deleting its one line.
  ///
  /// True when the import is unused because of its prefix, its `show`
  /// list, or a bare `dart:core` import, and the directive is one line.
  /// False when the import is used, when the directive spans lines, and
  /// when it is unused because no visible library name is referenced.
  /// That last case is kept because the import may provide an extension.
  final bool autoFixable;

  /// Why `unused` is true, or the empty string when the import is used.
  ///
  /// The text says that the prefix is never used, that none of the
  /// shown names are used, that `dart:core` is imported automatically,
  /// or that none of the imported library names are referenced.
  final String unusedReason;
}

/// One `export` directive and the project path it points at, if any.
final class ExportFact {
  /// Creates a fact for one export directive.
  ///
  /// Every parameter is required and is stored on the matching field.
  /// `uri` is the URI text. `shown` and `hidden` are the combinator
  /// names. `targetPath` is the project path from [resolveDartUri], or
  /// null when the URI does not land in this package.
  const ExportFact({
    required this.uri,
    required this.shown,
    required this.hidden,
    required this.targetPath,
  });

  /// Export URI as written in the directive.
  final String uri;

  /// Names gathered from every `show` combinator.
  ///
  /// Empty when the export is not limited by `show`.
  final List<String> shown;

  /// Names gathered from every `hide` combinator.
  ///
  /// Empty when the export hides nothing.
  final List<String> hidden;

  /// Project-relative path of a same-package export target.
  ///
  /// Null when [resolveDartUri] cannot place `uri` in this package.
  final String? targetPath;
}

/// A comment whose text contains `TODO`, `FIXME`, `HACK`, or `XXX`.
///
/// The marker match is case-sensitive, so only those uppercase words
/// are collected. Other comments are ignored here.
final class CommentFact {
  /// Creates a fact for one tagged comment.
  ///
  /// Every parameter is required and is stored on the matching field.
  /// `line` and `column` are the 1-based location of the comment token.
  /// `tag` is the matched marker. `text` is the comment lexeme with
  /// each whitespace run collapsed to one space, then trimmed.
  const CommentFact({
    required this.line,
    required this.column,
    required this.tag,
    required this.text,
  });

  /// 1-based line of the comment token.
  final int line;

  /// 1-based column of the comment token.
  final int column;

  /// Matched marker: `TODO`, `FIXME`, `HACK`, or `XXX`.
  final String tag;

  /// Full comment lexeme, with whitespace collapsed and the ends trimmed.
  final String text;
}

/// A function, method, or constructor that has a real body.
///
/// A semicolon body is omitted. An empty block is still recorded.
/// For a constructor, `name` is the constructor name, the type name
/// when the constructor is unnamed, or the word `constructor` when
/// neither token is present.
final class MethodFact {
  /// Creates a fact for one callable declaration.
  ///
  /// Every parameter is required and is stored on the matching field.
  /// `name` is the callable name described on this class. `owner` is
  /// the enclosing declaration name, or null for a top-level function.
  /// `line` and `column` are the 1-based start. `lines` is how many
  /// source lines the declaration spans. `complexity` is its cyclomatic
  /// complexity. `returnsFuture` is true when the written return type
  /// is named `Future` or `FutureOr`.
  const MethodFact({
    required this.name,
    required this.owner,
    required this.line,
    required this.column,
    required this.lines,
    required this.complexity,
    required this.returnsFuture,
  });

  /// Function, method, or constructor name recorded for this declaration.
  final String name;

  /// Enclosing declaration name, captured before this callable is entered.
  ///
  /// A method or constructor stores its class. A local function stores
  /// the function or method that contains it. A top-level function
  /// stores null. Only that one name is kept.
  final String? owner;

  /// 1-based line where the declaration starts.
  final int line;

  /// 1-based column where the declaration starts.
  final int column;

  /// Source lines from the declaration's first line through its last.
  ///
  /// The count includes both ends and is at least 1.
  final int lines;

  /// Cyclomatic complexity of this declaration.
  ///
  /// The count starts at 1 and increases for each decision point in
  /// the node, including decision points in nested functions.
  final int complexity;

  /// Whether the written return type's name is `Future` or `FutureOr`.
  ///
  /// This checks the type name as written, not a resolved type.
  /// Constructors store false.
  final bool returnsFuture;
}

/// A class declaration and the superclass name written on it.
///
/// `implements` and `with` clauses are not recorded. Mixins, enums,
/// and extensions are not class facts.
final class ClassFact {
  /// Creates a fact for one class declaration.
  ///
  /// Every parameter is required and is stored on the matching field.
  /// `name` is the class name. `superclass` is the identifier in the
  /// `extends` clause, or null when there is no `extends` clause.
  /// `line` and `column` are the 1-based start. `lines` is how many
  /// source lines the declaration spans.
  const ClassFact({
    required this.name,
    required this.superclass,
    required this.line,
    required this.column,
    required this.lines,
  });

  /// Class name as declared.
  final String name;

  /// Identifier in the `extends` clause, without type arguments.
  ///
  /// Null when the class has no `extends` clause.
  final String? superclass;

  /// 1-based line where the class declaration starts.
  final int line;

  /// 1-based column where the class declaration starts.
  final int column;

  /// Source lines from the class declaration's first line through its last.
  ///
  /// The count includes both ends and is at least 1.
  final int lines;

  /// Whether `superclass` names a widget or `State` base.
  ///
  /// Returns true when `superclass` is `StatelessWidget`,
  /// `StatefulWidget`, `ConsumerWidget`, `ConsumerStatefulWidget`,
  /// `HookWidget`, `StatelessHookWidget`, or `State`, or when that
  /// name starts with `State`. Returns false when `superclass` is null.
  /// The comparison uses the written name, including the `State` prefix
  /// check, and has no side effects.
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

/// A `catch` clause, including whether its body has no statements.
final class CatchFact {
  /// Creates a fact for one catch clause.
  ///
  /// Every parameter is required and is stored on the matching field.
  /// `line` and `column` are the 1-based location of the clause.
  /// `empty` is true when the catch body contains no statements.
  /// `enclosing` is the innermost enclosing declaration name, or null
  /// at library scope.
  const CatchFact({
    required this.line,
    required this.column,
    required this.empty,
    required this.enclosing,
  });

  /// 1-based line of the catch clause.
  final int line;

  /// 1-based column of the catch clause.
  final int column;

  /// Whether the catch body contains no statements.
  final bool empty;

  /// Innermost class, constructor, method, or function around the clause.
  ///
  /// Null when the clause is outside those declarations.
  final String? enclosing;
}

/// A `print`, `debugPrint`, or `log` call recorded while indexing.
///
/// Unqualified `print` and `debugPrint` calls are always recorded.
/// A `log` call is recorded only when one of its arguments looks like
/// a secret. Sensitivity is a case-insensitive substring match for
/// `password`, `secret`, `token`, `credential`, `authorization`, or
/// `apikey` with an optional `_` or `-` before `key`. A string literal
/// is tested by its value, an identifier by its name, and an
/// interpolation by its source text.
final class InvocationFact {
  /// Creates a fact for one logging call.
  ///
  /// Every parameter is required and is stored on the matching field.
  /// `line` and `column` are the 1-based location of the invocation.
  /// `name` is `print`, `debugPrint`, or `log`. `enclosing` is the
  /// innermost enclosing declaration name, or null at library scope.
  /// `sensitive` is true when an argument matches a sensitive word.
  const InvocationFact({
    required this.line,
    required this.column,
    required this.name,
    required this.enclosing,
    required this.sensitive,
  });

  /// 1-based line of the invocation.
  final int line;

  /// 1-based column of the invocation.
  final int column;

  /// Callee name: `print`, `debugPrint`, or `log`.
  final String name;

  /// Innermost class, constructor, method, or function around the call.
  ///
  /// Null when the call is outside those declarations.
  final String? enclosing;

  /// Whether any argument matches a sensitive word.
  ///
  /// The class description lists the words and which expressions are
  /// tested. Other argument shapes store false.
  final bool sensitive;
}

/// A string literal whose value is at most 2000 characters.
///
/// Interpolated strings are not collected. Adjacent string literals
/// are stored as one combined value, and their pieces are not stored
/// again. Values longer than 2000 characters are omitted.
final class StringFact {
  /// Creates a fact for one string literal.
  ///
  /// Every parameter is required and is stored on the matching field.
  /// `line` and `column` are the 1-based location. `value` is the
  /// literal value, already combined when the source used adjacent
  /// strings. `enclosing` is the innermost enclosing declaration name,
  /// or null at library scope.
  const StringFact({
    required this.line,
    required this.column,
    required this.value,
    required this.enclosing,
  });

  /// 1-based line of the literal.
  final int line;

  /// 1-based column of the literal.
  final int column;

  /// Literal value, with adjacent string literals already combined.
  final String value;

  /// Innermost class, constructor, method, or function around the literal.
  ///
  /// Null when the literal is outside those declarations.
  final String? enclosing;
}

/// A string literal taken from `Text` or from a label-like argument.
///
/// Collected from the first argument of a `Text` instance creation,
/// and from any named argument called `hintText`, `labelText`,
/// `helperText`, `tooltip`, `semanticLabel`, or `semanticsLabel`,
/// when that argument is a simple string or adjacent strings.
final class WidgetStringFact {
  /// Creates a fact for one widget string.
  ///
  /// Every parameter is required and is stored on the matching field.
  /// `line` and `column` are the 1-based location of the `Text`
  /// creation or the named argument. `value` is the literal text.
  /// `kind` is `Text` or the argument name.
  const WidgetStringFact({
    required this.line,
    required this.column,
    required this.value,
    required this.kind,
  });

  /// 1-based line of the `Text` creation or named argument.
  final int line;

  /// 1-based column of the `Text` creation or named argument.
  final int column;

  /// Literal text taken from that argument.
  final String value;

  /// `Text` for a text widget, otherwise the named-argument name.
  final String kind;
}

/// An `async` or `async*` callable whose body contains no `await`.
///
/// An `await` anywhere in the body, including inside a nested
/// closure, counts as present, so that callable is left out. A
/// semicolon body is omitted with the other empty callables.
final class AsyncFact {
  /// Creates a fact for one async callable that never awaits.
  ///
  /// Every parameter is required and is stored on the matching field.
  /// `name` uses the same constructor naming as [MethodFact]. `line`
  /// and `column` are the 1-based start of the declaration. `owner`
  /// is the enclosing declaration name, or null for a top-level
  /// function.
  const AsyncFact({
    required this.name,
    required this.line,
    required this.column,
    required this.owner,
  });

  /// Callable name, with unnamed constructors named the same way as
  /// [MethodFact].
  final String name;

  /// 1-based line where the async callable starts.
  final int line;

  /// 1-based column where the async callable starts.
  final int column;

  /// Enclosing declaration name, captured before this callable is entered.
  ///
  /// Null for a top-level function. Only that one enclosing name is kept.
  final String? owner;
}

/// A method call that is the entire statement and has no target.
///
/// Calls on an object, and calls nested inside a larger expression,
/// are not included. An unqualified `print` or `debugPrint` statement
/// is included along with any other bare call.
final class BareCallFact {
  /// Creates a fact for one bare call statement.
  ///
  /// Every parameter is required and is stored on the matching field.
  /// `name` is the method name. `line` and `column` are the 1-based
  /// location of the invocation. `enclosing` is the innermost enclosing
  /// declaration name, or null at library scope.
  const BareCallFact({
    required this.name,
    required this.line,
    required this.column,
    required this.enclosing,
  });

  /// Name of the method invoked as a statement.
  final String name;

  /// 1-based line of the bare invocation.
  final int line;

  /// 1-based column of the bare invocation.
  final int column;

  /// Innermost class, constructor, method, or function around the call.
  ///
  /// Null when the call is outside those declarations.
  final String? enclosing;
}

/// A source position labeled with the API name recognized there.
///
/// The label is `badCertificateCallback` or `onBadCertificate` for a
/// call or assignment, or `rawQuery`, `rawInsert`, `rawUpdate`,
/// `rawDelete`, or `openDatabase` for a call.
final class LocationFact {
  /// Creates a fact for one labeled location.
  ///
  /// Every parameter is required and is stored on the matching field.
  /// `line` and `column` are the 1-based location. `label` is the
  /// matched method or property name. `enclosing` is the innermost
  /// enclosing declaration name, or null at library scope.
  const LocationFact({
    required this.line,
    required this.column,
    required this.label,
    required this.enclosing,
  });

  /// 1-based line of the call or assignment.
  final int line;

  /// 1-based column of the call or assignment.
  final int column;

  /// Matched method or property name.
  final String label;

  /// Innermost class, constructor, method, or function around the site.
  ///
  /// Null when the site is outside those declarations.
  final String? enclosing;
}

/// A `shared_preferences` write whose key looks like a secret.
///
/// Recorded only while the file imports `package:shared_preferences`,
/// and only for `setString`, `setStringList`, or `setInt` whose first
/// argument is a string literal matching a sensitive word. The words
/// are the same substring checks described on [InvocationFact].
final class StorageFact {
  /// Creates a fact for one sensitive preference write.
  ///
  /// Every parameter is required and is stored on the matching field.
  /// `line` and `column` are the 1-based location of the call. `key`
  /// is the literal preference key. `method` is `setString`,
  /// `setStringList`, or `setInt`.
  const StorageFact({
    required this.line,
    required this.column,
    required this.key,
    required this.method,
  });

  /// 1-based line of the preference setter call.
  final int line;

  /// 1-based column of the preference setter call.
  final int column;

  /// Preference key literal that matched a sensitive word.
  final String key;

  /// Setter that wrote the key: `setString`, `setStringList`, or `setInt`.
  final String method;
}

/// One syntax diagnostic produced while parsing a Dart file.
///
/// Diagnostics are kept on the file facts so indexing can continue.
final class ParseFact {
  /// Creates a fact for one parser diagnostic.
  ///
  /// Every parameter is required and is stored on the matching field.
  /// `line` and `column` are the 1-based diagnostic location.
  /// `message` is the diagnostic text.
  const ParseFact({
    required this.line,
    required this.column,
    required this.message,
  });

  /// 1-based line of the parser diagnostic.
  final int line;

  /// 1-based column of the parser diagnostic.
  final int column;

  /// Diagnostic message reported by the parser.
  final String message;
}

/// A comment that contains `flutterguard:ignore`.
///
/// A usable comment matches `flutterguard:ignore`, then an id of
/// `FG-` plus uppercase letters, digits, or hyphens, then `reason:`
/// and a reason. A trailing `*/` on the reason is removed before the
/// reason is checked. A comment that merely contains the marker and
/// does not match stores null for the id and reason.
final class InlineIgnore {
  /// Creates a fact for one ignore comment.
  ///
  /// Every parameter is required and is stored on the matching field.
  /// `line` is the 1-based line of the comment. `ruleId` and `reason`
  /// are null when the comment does not match the expected shape.
  /// `valid` is true only when the parsed reason is non-empty.
  const InlineIgnore({
    required this.line,
    required this.ruleId,
    required this.reason,
    required this.valid,
  });

  /// 1-based line of the comment that contains `flutterguard:ignore`.
  final int line;

  /// Parsed `FG-` rule id, or null when the comment does not match.
  final String? ruleId;

  /// Parsed reason, or null when the comment does not match.
  ///
  /// A match whose reason trims to nothing stores an empty string,
  /// and that comment is not valid.
  final String? reason;

  /// Whether a non-empty reason was parsed from the comment.
  final bool valid;
}

/// Everything collected from a single Dart source file.
///
/// The lists keep source order. Import targets are resolved before
/// this object is built, so each [ImportFact] already carries its
/// unused-import result.
final class DartFileFacts {
  /// Creates the facts for one Dart file.
  ///
  /// Every parameter is required and is stored on the matching field.
  /// `path` is the project-relative POSIX path. `generated` marks a
  /// generated file. `imports`, `exports`, `identifiers`,
  /// `publicNames`, `comments`, `methods`, `classes`, `catches`,
  /// `prints`, `sensitiveLogs`, `strings`, `widgetStrings`,
  /// `asyncWithoutAwait`, `bareCalls`, `tlsBypasses`, `databaseCalls`,
  /// `insecureStores`, `parseErrors`, and `ignores` are the facts
  /// collected from this file. `importedPackages` lists `package:`
  /// names. `futureFunctions` maps each top-level function to a
  /// syntactic future return type. `importsSharedPreferences` reports
  /// a `shared_preferences` import.
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

  /// Project-relative POSIX path of this file.
  ///
  /// This is the path used by [DartIndex]'s subscript lookup.
  final String path;

  /// Whether the file is treated as generated.
  ///
  /// True when the path ends in `.g.dart`, `.freezed.dart`, or
  /// `.gr.dart`, or when the contents include `// GENERATED CODE` or
  /// `// Generated by`.
  final bool generated;

  /// Import directives in source order, after unused-import checks.
  final List<ImportFact> imports;

  /// Export directives in source order.
  final List<ExportFact> exports;

  /// Simple-identifier names found outside import and export directives.
  ///
  /// Import and export clauses are not walked, so a name that appears
  /// only in `show`, `hide`, or an import prefix is not a use.
  final Set<String> identifiers;

  /// Declared names in this file that do not start with `_`.
  ///
  /// Includes classes, enums, mixins, named extensions, typedefs,
  /// functions, and top-level variables. Nested functions are included.
  /// Methods, fields, and unnamed extensions are not.
  final Set<String> publicNames;

  /// `TODO`, `FIXME`, `HACK`, and `XXX` comments, in source order.
  final List<CommentFact> comments;

  /// Functions, methods, and constructors that have a body.
  final List<MethodFact> methods;

  /// Class declarations in source order.
  final List<ClassFact> classes;

  /// Catch clauses in source order.
  final List<CatchFact> catches;

  /// Unqualified `print` and `debugPrint` calls.
  ///
  /// Sensitive calls in this list are the same instances also stored
  /// in `sensitiveLogs`.
  final List<InvocationFact> prints;

  /// Logging calls whose arguments match a sensitive word.
  ///
  /// Includes sensitive entries from `prints`, plus any `log` call,
  /// with or without a receiver, whose argument matches.
  final List<InvocationFact> sensitiveLogs;

  /// String literals of at most 2000 characters.
  final List<StringFact> strings;

  /// String literals collected from widget text and label arguments.
  final List<WidgetStringFact> widgetStrings;

  /// Async callables whose bodies contain no `await`.
  final List<AsyncFact> asyncWithoutAwait;

  /// Statement-level calls written with no target.
  final List<BareCallFact> bareCalls;

  /// Uses of `badCertificateCallback` or `onBadCertificate`.
  ///
  /// Both calls and assignments are included. An assignment matches a
  /// simple name, a prefixed name, or a property access.
  final List<LocationFact> tlsBypasses;

  /// Calls named `rawQuery`, `rawInsert`, `rawUpdate`, `rawDelete`, or
  /// `openDatabase`.
  final List<LocationFact> databaseCalls;

  /// Sensitive `shared_preferences` writes in this file.
  final List<StorageFact> insecureStores;

  /// Parser diagnostics for this file. Indexing still returns the file.
  final List<ParseFact> parseErrors;

  /// Comments in this file that contain `flutterguard:ignore`.
  final List<InlineIgnore> ignores;

  /// Package names imported through `package:` URIs.
  ///
  /// The name is the first segment after `package:`, or the whole
  /// remainder when the URI has no slash. Empty names are omitted.
  final Set<String> importedPackages;

  /// Top-level functions mapped to a syntactic future return type.
  ///
  /// The key is the function name and can start with `_`. The value is
  /// true when the written return type's name is `Future` or
  /// `FutureOr`. Local functions and methods are omitted.
  final Map<String, bool> futureFunctions;

  /// Whether this file imports the `shared_preferences` package.
  ///
  /// True when a `package:` import's first segment is exactly
  /// `shared_preferences`.
  final bool importsSharedPreferences;

  /// Whether any class in `classes` is a widget or `State` type.
  ///
  /// Returns true when [ClassFact.isWidget] is true for at least one
  /// class. Returns false when `classes` is empty. The getter has no
  /// side effects.
  bool get containsWidget => classes.any((item) => item.isWidget);
}

/// Parsed Dart files for one package, and the import cycles among them.
///
/// [buildDartIndex] parses project files. This constructor stores
/// facts that are already collected. The subscript operator finds
/// one file by its project-relative path.
///
/// ```dart
/// final index = buildDartIndex(
///   files: indexedFiles,
///   packageName: 'my_app',
/// );
/// final direct = DartIndex(files: index.files, cycles: index.cycles);
/// final DartFileFacts? facts = direct['lib/main.dart'];
/// ```
final class DartIndex {
  /// Creates an index from facts that are already collected.
  ///
  /// Both parameters are required and are stored as given. `files` is
  /// the per-file facts. `cycles` is the canonical import-cycle text.
  /// Parsing and cycle detection are performed by [buildDartIndex].
  const DartIndex({required this.files, required this.cycles});

  /// Facts for each parsed Dart file, in the order they were parsed.
  final List<DartFileFacts> files;

  /// Canonical descriptions of import cycles.
  ///
  /// Each entry joins file paths with ` -> ` and closes the cycle by
  /// repeating the first path. A cycle and its reverse
  /// collapse to the lexicographically smallest rotation. The list is
  /// sorted. Edges come from import targets only; exports add none.
  final List<String> cycles;

  /// Returns the first [DartFileFacts] whose path equals `path`.
  ///
  /// Files are compared in list order. The result is null when no file
  /// has that path.
  DartFileFacts? operator [](String path) {
    for (final file in files) {
      if (file.path == path) {
        return file;
      }
    }
    return null;
  }
}

/// Parses Dart sources into a [DartIndex].
///
/// `files` is only read. An entry is parsed when its `relativePosix`
/// path ends in `.dart` and its `text` is non-null; every other
/// entry is skipped. Parsed files keep their input order.
/// `packageName` selects which `package:` URIs [resolveDartUri]
/// maps into `lib/`. Both parameters are required.
///
/// Syntax diagnostics are stored as [ParseFact] values on each
/// [DartFileFacts]. The returned index holds those files and the
/// import cycles among their resolved import targets.
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

/// Maps an import or export URI to a project-relative POSIX path.
///
/// `fromPath` is the file that contains the URI. `uri` is the URI
/// text. `packageName` is this package's name. All three parameters
/// are required.
///
/// Returns null for a `dart:` URI. A `package:` URI returns `lib/`
/// plus the remaining path when the segment before `/` equals
/// `packageName`. A different package, a missing `/`, or an empty
/// package segment returns null. Any other URI that contains `:`
/// returns null.
///
/// Any remaining URI is joined onto the directory of `fromPath` and
/// normalized with POSIX rules. An absolute URI replaces that
/// directory. The normalized path is returned unless it is `..` or
/// begins with `../`.
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
