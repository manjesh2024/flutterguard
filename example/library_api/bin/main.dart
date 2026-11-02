import 'dart:io';

import 'package:flutterguard_audit/flutterguard_audit.dart';
import 'package:path/path.dart' as p;

/// Demonstrates the public scan API. Exits 0 after it has handled results.
Future<void> main() async {
  final exampleRoot = Directory(p.dirname(Platform.script.toFilePath()))
      .parent
      .parent;
  final basicApp = Directory(p.join(exampleRoot.path, 'basic_flutter_app'));
  final intentional = Directory(
    p.join(exampleRoot.path, 'intentional_findings'),
  );

  final defaults = FlutterGuardConfig.defaults();
  stdout.writeln(
    'Defaults: discovery ${defaults.discoveryMode.name}, '
    'architecture ${defaults.architecture.profile}, '
    'reports ${defaults.reportDirectory}.',
  );

  final basicConfig = p.join(basicApp.path, 'flutterguard.yaml');
  final loaded = loadConfig(rootPath: basicApp.path, configPath: basicConfig);
  stdout.writeln(
    'Loaded basic_flutter_app discovery ${loaded.discoveryMode.name}.',
  );

  final missingRoot = Directory.systemTemp.createTempSync(
    'flutterguard_example',
  );
  try {
    loadConfig(
      rootPath: missingRoot.path,
      configPath: p.join(missingRoot.path, 'missing.yaml'),
    );
    stderr.writeln('Expected ConfigException for a missing config file.');
    exit(ExitCodes.failure);
  } on ConfigException catch (error) {
    stdout.writeln(
      'ConfigException exit ${error.exitCode}: missing file was refused.',
    );
    if (error.exitCode != ExitCodes.usage) {
      exit(ExitCodes.failure);
    }
  } finally {
    missingRoot.deleteSync(recursive: true);
  }

  final basic = await const FlutterGuardScanner().scan(
    ScanRequest(
      rootPath: basicApp.path,
      configPath: basicConfig,
      offline: true,
      writeReports: false,
    ),
  );
  stdout.writeln(
    'Basic app findings: ${basic.report.findings.length}. '
    'Exit ${basic.exitCode}.',
  );
  if (basic.exitCode != ExitCodes.success) {
    for (final finding in basic.report.findings) {
      stderr.writeln('${finding.ruleId} ${finding.path} ${finding.message}');
    }
    exit(basic.exitCode);
  }

  final sample = await const FlutterGuardScanner().scan(
    ScanRequest(
      rootPath: intentional.path,
      configPath: p.join(intentional.path, 'flutterguard.yaml'),
      offline: true,
      writeReports: false,
    ),
  );
  final rules = sample.report.findings.map((finding) => finding.ruleId).toSet();
  stdout.writeln(
    'Intentional findings: ${sample.report.findings.length}. '
    'Exit ${sample.exitCode}. Rules: ${rules.join(', ')}.',
  );
  if (!rules.contains('FG-BRAND-003') ||
      !rules.contains('FG-ARCH-001') ||
      sample.exitCode != ExitCodes.gateFailed) {
    stderr.writeln(
      'The intentional sample did not produce the expected gate failure.',
    );
    exit(ExitCodes.failure);
  }
}
