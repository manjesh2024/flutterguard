import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../auto_fix/auto_fix.dart';
import '../baseline/baseline.dart';
import '../core/config_loader.dart';
import '../core/exceptions.dart';
import '../core/safe_path.dart';
import '../core/scan_pipeline.dart';
import '../core/version.dart';
import '../discovery/discovery.dart';
import '../reporting/formatters.dart';
import '../rules/registry.dart';
import '../toolchain/toolchain.dart';

/// Destination for CLI stdout and stderr text.
abstract interface class CliIo {
  /// Writes [text] to the normal output stream. Does not add a newline.
  void writeOut(String text);

  /// Writes [text] to the error stream. Does not add a newline.
  void writeErr(String text);
}

/// [CliIo] that writes to the process stdout and stderr.
final class StdioCli implements CliIo {
  /// Creates a CLI bound to the current process streams.
  StdioCli();

  @override
  void writeOut(String text) => io.stdout.write(text);

  @override
  void writeErr(String text) => io.stderr.write(text);
}

/// [CliIo] that records output in memory for tests and embedded runs.
final class BufferCli implements CliIo {
  /// Creates an empty buffer for stdout and stderr text.
  BufferCli();

  /// Text passed to [writeOut], including any newlines the caller supplied.
  final out = StringBuffer();

  /// Text passed to [writeErr], including any newlines the caller supplied.
  final err = StringBuffer();

  @override
  void writeOut(String text) => out.write(text);

  @override
  void writeErr(String text) => err.write(text);
}

/// Command-line entry point for scan, init, rules, baseline, fix, and doctor.
///
/// ```dart
/// final exitCode = await FlutterGuardCli(ioSink: BufferCli()).run(
///   const ['--offline'],
/// );
/// ```
///
/// With no command, or with a path and flags that are not a known command,
/// [run] scans the project. `version` and `--version` print the executable
/// name and package version. `help`, `--help`, and `-h` print [rootHelp].
final class FlutterGuardCli {
  /// Creates a CLI that writes through [ioSink].
  ///
  /// When [ioSink] is omitted, output goes to a [StdioCli].
  FlutterGuardCli({CliIo? ioSink}) : ioSink = ioSink ?? StdioCli();

  /// Stream used for normal output and errors.
  final CliIo ioSink;

  /// Parses [args] and runs the selected command.
  ///
  /// Returns a process exit code. A FlutterGuard exception is written to
  /// [ioSink] and its exit code is returned. An args-parser exception returns
  /// the usage exit code. Any other error is written as `FlutterGuard failed`
  /// and returns the failure exit code. `init` can write the config file,
  /// scan can write reports, `baseline` writes the baseline file, and `fix`
  /// can edit source and write a backup.
  Future<int> run(List<String> args) async {
    try {
      return await _run(args);
    } on FlutterGuardException catch (error) {
      ioSink.writeErr('${error.message}\n');
      return error.exitCode;
    } on ArgParserException catch (error) {
      ioSink.writeErr('$error\n');
      return ExitCodes.usage;
    } catch (error) {
      ioSink.writeErr('FlutterGuard failed: $error\n');
      return ExitCodes.failure;
    }
  }

  Future<int> _run(List<String> args) async {
    if (args.isNotEmpty &&
        (args.first == '--version' || args.first == 'version')) {
      ioSink.writeOut('$executableName $packageVersion\n');
      return ExitCodes.success;
    }
    if (args.isNotEmpty &&
        (args.first == '--help' ||
            args.first == '-h' ||
            args.first == 'help')) {
      ioSink.writeOut(rootHelp);
      return ExitCodes.success;
    }
    if (args.isEmpty || _isScan(args)) {
      return _scan(args);
    }
    switch (args.first) {
      case 'init':
        return _init(args.sublist(1));
      case 'rules':
        return _rules(args.sublist(1));
      case 'baseline':
        return _baseline(args.sublist(1));
      case 'fix':
        return _fix(args.sublist(1));
      case 'doctor':
        return _doctor(args.sublist(1));
      default:
        throw UsageException('Unknown command "${args.first}".\n$rootHelp');
    }
  }

  bool _isScan(List<String> args) {
    const commands = {
      'init',
      'rules',
      'baseline',
      'fix',
      'doctor',
      'help',
      'version',
    };
    return !commands.contains(args.first) &&
        args.first != '--help' &&
        args.first != '-h';
  }

  Future<int> _scan(List<String> args) async {
    final parser = _commonParser()
      ..addFlag('help', abbr: 'h', negatable: false, help: 'Show scan help.');
    final results = _parse(parser, args, scanHelp);
    if (results['help'] == true) {
      ioSink.writeOut(scanHelp);
      return ExitCodes.success;
    }
    final root = _root(results, args);
    final execution = await const FlutterGuardScanner().scan(
      ScanRequest(
        rootPath: root,
        configPath: results['config'] as String?,
        offline: results['offline'] == true,
      ),
    );
    ioSink.writeOut(renderTerminal(execution.report));
    final reports = execution.reports;
    if (reports != null) {
      ioSink.writeOut('Reports:\n');
      ioSink.writeOut('  ${reports.indexHtml}\n');
      ioSink.writeOut('  ${reports.reportJson}\n');
      ioSink.writeOut('  ${reports.reportMarkdown}\n');
      ioSink.writeOut('  ${reports.reportSarif}\n');
    }
    return execution.exitCode;
  }

  int _init(List<String> args) {
    final parser = _commonParser()
      ..addFlag(
        'force',
        negatable: false,
        help: 'Replace an existing config file.',
      )
      ..addFlag('help', abbr: 'h', negatable: false);
    final results = _parse(parser, args, initHelp);
    if (results['help'] == true) {
      ioSink.writeOut(initHelp);
      return ExitCodes.success;
    }
    final root = _root(results, args);
    final target = FilePath(p.join(root, configFileName));
    if (target.exists && results['force'] != true) {
      throw UsageException(
        '$configFileName already exists. Re-run with --force to replace it.',
      );
    }
    target.write(configTemplate);
    ioSink.writeOut('Wrote ${p.join(root, configFileName)}\n');
    return ExitCodes.success;
  }

  int _rules(List<String> args) {
    final parser = ArgParser()..addFlag('help', abbr: 'h', negatable: false);
    if (args.isEmpty || args.first == '--help' || args.first == '-h') {
      ioSink.writeOut(rulesHelp);
      return ExitCodes.success;
    }
    final command = args.first;
    final results = _parse(parser, args.sublist(1), rulesHelp);
    if (results['help'] == true) {
      ioSink.writeOut(rulesHelp);
      return ExitCodes.success;
    }
    final registry = RuleRegistry.builtIn;
    if (command == 'list') {
      for (final rule in registry.rules) {
        ioSink.writeOut(
          '${rule.id}  [${rule.defaultSeverity.name}]  ${rule.title}\n',
        );
      }
      return ExitCodes.success;
    }
    if (command == 'explain') {
      final rest = results.rest;
      if (rest.isEmpty) {
        throw UsageException('Usage: $executableName rules explain <rule-id>');
      }
      final rule = registry.byId(rest.first);
      if (rule == null) {
        throw UsageException(
          'Unknown rule "${rest.first}". Run `$executableName rules list`.',
        );
      }
      ioSink.writeOut('${rule.id}: ${rule.title}\n');
      ioSink.writeOut('Category: ${rule.category}\n');
      ioSink.writeOut('Severity: ${rule.defaultSeverity.name}\n');
      ioSink.writeOut('Heuristic: ${rule.heuristic}\n');
      ioSink.writeOut('${rule.description}\n');
      ioSink.writeOut('Recommendation: ${rule.recommendation}\n');
      return ExitCodes.success;
    }
    throw UsageException('Unknown rules command "$command".\n$rulesHelp');
  }

  Future<int> _baseline(List<String> args) async {
    final parser = _commonParser()
      ..addFlag('force', negatable: false)
      ..addFlag('help', abbr: 'h', negatable: false);
    if (args.isEmpty) {
      throw UsageException(baselineHelp);
    }
    final command = args.first;
    final results = _parse(parser, args.sublist(1), baselineHelp);
    if (results['help'] == true) {
      ioSink.writeOut(baselineHelp);
      return ExitCodes.success;
    }
    if (command != 'create' && command != 'update') {
      throw UsageException(
        'Unknown baseline command "$command".\n$baselineHelp',
      );
    }
    final root = _root(results, args.sublist(1));
    final config = loadConfig(
      rootPath: root,
      configPath: results['config'] as String?,
    );
    final destination = SafePath(root).joinInside(config.baselinePath);
    if (destination == null) {
      throw ConfigException(
        'baseline.path escapes the project and was refused.',
      );
    }
    final exists = io.File(destination).existsSync();
    if (command == 'create' && exists && results['force'] != true) {
      throw UsageException(
        'Baseline already exists. Use `baseline update` or `--force`.',
      );
    }
    final execution = await const FlutterGuardScanner().scan(
      ScanRequest(
        rootPath: root,
        configPath: results['config'] as String?,
        writeReports: false,
        offline: results['offline'] == true,
      ),
    );
    final baseline = baselineFromFindings(
      execution.report.findings,
      execution.report.generatedAt,
    );
    writeBaseline(destination, baseline);
    ioSink.writeOut(
      '${command == 'create' ? 'Created' : 'Updated'} baseline with ${baseline.entries.length} finding(s).\n',
    );
    return ExitCodes.success;
  }

  Future<int> _fix(List<String> args) async {
    final parser = _commonParser()
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Preview edits without writing.',
      )
      ..addFlag('revert', negatable: false, help: 'Restore the latest backup.')
      ..addFlag('help', abbr: 'h', negatable: false);
    final results = _parse(parser, args, fixHelp);
    if (results['help'] == true) {
      ioSink.writeOut(fixHelp);
      return ExitCodes.success;
    }
    final root = _root(results, args);
    if (results['revert'] == true) {
      final restored = const AutoFixer().revert(root);
      if (restored == 0) {
        throw UsageException('No FlutterGuard backup was found to restore.');
      }
      ioSink.writeOut('Restored $restored file(s).\n');
      return ExitCodes.success;
    }
    final execution = await const FlutterGuardScanner().scan(
      ScanRequest(
        rootPath: root,
        configPath: results['config'] as String?,
        writeReports: false,
        offline: true,
      ),
    );
    final dryRun = results['dry-run'] == true;
    final result = const AutoFixer().apply(
      rootPath: root,
      findings: execution.report.findings,
      dryRun: dryRun,
    );
    if (dryRun) {
      ioSink.writeOut('Dry run. No files were changed.\n');
    }
    for (final preview in result.previews) {
      ioSink.writeOut(
        '${preview.path}:${preview.line} ${preview.description}\n',
      );
    }
    for (final skipped in result.skipped) {
      ioSink.writeOut('Skipped: $skipped\n');
    }
    if (!dryRun) {
      ioSink.writeOut('Updated ${result.applied} file(s).\n');
      if (result.backupDirectory != null) {
        ioSink.writeOut('Backup: ${result.backupDirectory}\n');
      }
    }
    return ExitCodes.success;
  }

  Future<int> _doctor(List<String> args) async {
    final parser = _commonParser()
      ..addFlag('help', abbr: 'h', negatable: false);
    final results = _parse(parser, args, doctorHelp);
    if (results['help'] == true) {
      ioSink.writeOut(doctorHelp);
      return ExitCodes.success;
    }
    final root = _root(results, args);
    final toolchain = await const ToolchainProbe().detect();
    ioSink.writeOut('$toolName $packageVersion\n');
    ioSink.writeOut('Dart: ${toolchain.dartVersion}\n');
    ioSink.writeOut('Flutter: ${toolchain.flutterVersion ?? 'not found'}\n');
    final configFile = io.File(p.join(root, configFileName));
    if (!configFile.existsSync()) {
      ioSink.writeOut(
        'Config: using safe defaults ($configFileName not found)\n',
      );
    } else {
      loadConfig(rootPath: root, configPath: results['config'] as String?);
      ioSink.writeOut('Config: $configFileName is valid\n');
    }
    try {
      final config = loadConfig(
        rootPath: root,
        configPath: results['config'] as String?,
      );
      final projects = const ProjectDiscovery().discover(
        rootPath: root,
        config: config,
      );
      ioSink.writeOut(
        'Projects: ${projects.map((project) => project.name).join(', ')}\n',
      );
    } on DiscoveryException catch (error) {
      ioSink.writeOut('Projects: ${error.message}\n');
    }
    final reportDir = SafePath(root).joinInside('build/flutterguard');
    ioSink.writeOut(
      reportDir == null
          ? 'Report directory: refused\n'
          : 'Report directory: build/flutterguard\n',
    );
    ioSink.writeOut('Rules: ${RuleRegistry.builtIn.rules.length}\n');
    return ExitCodes.success;
  }

  ArgParser _commonParser() {
    return ArgParser()
      ..addOption(
        'path',
        help: 'Project directory. Defaults to the current directory.',
      )
      ..addOption('config', help: 'Path to .flutterguard.yaml.')
      ..addFlag(
        'offline',
        negatable: false,
        help: 'Disable network checks for this run.',
      );
  }

  ArgResults _parse(ArgParser parser, List<String> args, String help) {
    try {
      return parser.parse(args);
    } on ArgParserException catch (error) {
      throw UsageException('$error\n$help');
    }
  }

  String _root(ArgResults results, List<String> original) {
    final option = results['path'] as String?;
    if (option != null) {
      return option;
    }
    final positional = results.rest
        .where((arg) => !arg.startsWith('-'))
        .toList();
    if (positional.isNotEmpty) {
      return positional.first;
    }
    return p.current;
  }
}

/// File wrapper used by `init` to test existence and write the config template.
final class FilePath {
  /// Binds this wrapper to [path]. Does not touch the filesystem.
  FilePath(this.path);

  /// Filesystem path passed to the constructor.
  final String path;

  /// Whether a file exists at [path].
  bool get exists => io.File(path).existsSync();

  /// Replaces the file at [path] with [contents].
  ///
  /// Does not create missing parent directories.
  void write(String contents) => io.File(path).writeAsStringSync(contents);
}

/// Help text for the top-level command list.
const String rootHelp = '''
FlutterGuard audits a Flutter project in one command.

Usage:
  flutterguard [path]
  flutterguard init
  flutterguard rules list
  flutterguard rules explain <rule-id>
  flutterguard baseline create
  flutterguard baseline update
  flutterguard fix [--dry-run]
  flutterguard doctor

Run flutterguard with no arguments inside a Flutter project to scan, write
reports, evaluate the quality gate, and print a summary.
''';

/// Help text for a scan invoked with no subcommand.
const String scanHelp = '''
Usage: flutterguard [path] [--config file] [--offline]

Discovers the Flutter project, runs every enabled module, writes
build/flutterguard reports, and returns 0 when the quality gate passes.
''';

/// Help text for `flutterguard init`.
const String initHelp = '''
Usage: flutterguard init [path] [--force]

Writes .flutterguard.yaml. Existing files are kept unless --force is set.
''';

/// Help text for `flutterguard rules list` and `rules explain`.
const String rulesHelp = '''
Usage:
  flutterguard rules list
  flutterguard rules explain FG-ARCH-001
''';

/// Help text for `flutterguard baseline create` and `baseline update`.
const String baselineHelp = '''
Usage:
  flutterguard baseline create [--force]
  flutterguard baseline update

Both commands scan without modifying source and write the baseline file from
the active configuration.
''';

/// Help text for `flutterguard fix`, including dry-run and revert.
const String fixHelp = '''
Usage:
  flutterguard fix --dry-run
  flutterguard fix
  flutterguard fix --revert

The scan itself never writes source. fix only applies deterministic import
removals and stores a backup under .flutterguard/backups.
''';

/// Help text for `flutterguard doctor`.
const String doctorHelp = '''
Usage: flutterguard doctor [path]

Prints the Dart and Flutter versions, config status, and discovered projects.
''';
