/// FlutterGuard public API.
///
/// The terminal command is `flutterguard`. The pub.dev package name is
/// `flutterguard_audit`.
library;

export 'src/auto_fix/auto_fix.dart';
export 'src/baseline/baseline.dart';
export 'src/cli/cli.dart';
export 'src/core/config.dart';
export 'src/core/config_loader.dart';
export 'src/core/exceptions.dart';
export 'src/core/finding.dart';
export 'src/core/scan_pipeline.dart';
export 'src/core/severity.dart';
export 'src/core/version.dart';
export 'src/network/clients.dart' show parseOutdatedJson, parseOsvResponse;
export 'src/quality_gate/quality_gate.dart';
export 'src/reporting/formatters.dart';
export 'src/rules/registry.dart';
export 'src/rules/rule.dart';
