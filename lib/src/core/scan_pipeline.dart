import 'dart:io';

import '../baseline/baseline.dart';
import '../context/project_snapshot.dart';
import '../core/config.dart';
import '../core/config_loader.dart';
import '../core/finding.dart';
import '../discovery/discovery.dart';
import '../network/clients.dart';
import '../network/signals.dart';
import '../quality_gate/quality_gate.dart';
import '../reporting/formatters.dart';
import '../reporting/report_writer.dart';
import '../rules/registry.dart';
import '../rules/rule.dart';
import '../suppression/suppression.dart';
import '../toolchain/toolchain.dart';
import 'exceptions.dart';
import 'safe_path.dart';
import 'version.dart';

/// Inputs for one [FlutterGuardScanner.scan] call.
final class ScanRequest {
  /// Scans [rootPath] at [now], defaulting [now] to the current UTC time.
  ///
  /// [configPath] selects an explicit configuration file. When it is null,
  /// the scanner looks for `.flutterguard.yaml` in [rootPath] and uses
  /// defaults when that file is absent. [writeReports] controls whether
  /// HTML, JSON, Markdown, and SARIF files are written. [toolchain] skips
  /// probing the local Dart and Flutter commands when the caller already
  /// knows them. [offline] forces network checks off for this run.
  /// [outdatedClient] and [vulnerabilityClient] replace the process and
  /// HTTP clients; tests use them, and production leaves them null.
  ScanRequest({
    required this.rootPath,
    this.configPath,
    this.writeReports = true,
    DateTime? now,
    this.toolchain,
    this.offline = false,
    this.outdatedClient,
    this.vulnerabilityClient,
  }) : now = now ?? DateTime.now().toUtc();

  /// Directory that contains the Flutter project or monorepo root.
  final String rootPath;

  /// Explicit configuration file, or null to use the default lookup.
  final String? configPath;

  /// Whether the scan writes the report directory. Defaults to true.
  final bool writeReports;

  /// Timestamp stored in the report. UTC, and the current time when omitted.
  final DateTime now;

  /// Precomputed Dart and Flutter versions, or null to probe the machine.
  final ToolchainInfo? toolchain;

  /// When true, outdated and vulnerability clients are not called.
  final bool offline;

  /// Replacement for `dart pub outdated`. Null uses the process client.
  final OutdatedClient? outdatedClient;

  /// Replacement for the OSV client. Null uses the HTTP client.
  final VulnerabilityClient? vulnerabilityClient;
}

/// Report, written files, and process status from one scan.
final class ScanExecution {
  /// Stores [report], the optional [reports] paths, and [exitCode].
  ///
  /// [reports] is null when the request set `writeReports` to false.
  /// [exitCode] is [ExitCodes.success] or [ExitCodes.gateFailed]. Usage and
  /// runtime failures throw instead of returning this object.
  const ScanExecution({
    required this.report,
    required this.reports,
    required this.exitCode,
  });

  /// In-memory scan result, including findings and the quality gate.
  final ScanReport report;

  /// Paths of the files written for this scan, or null when writing was off.
  final WrittenReports? reports;

  /// [ExitCodes.success] when the gate passed, otherwise [ExitCodes.gateFailed].
  final int exitCode;
}

/// Runs discovery, rules, suppression, baseline comparison, and reporting.
///
/// ```dart
/// final execution = await const FlutterGuardScanner().scan(
///   ScanRequest(rootPath: '/path/to/app', offline: true),
/// );
/// ```
final class FlutterGuardScanner {
  /// Creates a scanner with no retained state.
  const FlutterGuardScanner();

  /// Scans [request] and returns the report and exit code.
  ///
  /// Throws [ConfigException] for a broken configuration or a baseline path
  /// that escapes the project. Throws [DiscoveryException] when discovery
  /// finds nothing usable. Does not modify source files. Network clients run
  /// only when configuration enables them and [ScanRequest.offline] is false.
  Future<ScanExecution> scan(ScanRequest request) async {
    final root = SafePath(request.rootPath).rootPath;
    final config = loadConfig(rootPath: root, configPath: request.configPath);
    final registry = RuleRegistry.builtIn.withConfig(config);
    validateKnownRules(config, registry.ids);
    final projects = const ProjectDiscovery().discover(
      rootPath: root,
      config: config,
    );
    final snapshots = [
      for (final project in projects)
        const SnapshotBuilder().build(project: project, config: config),
    ];
    final toolchain =
        request.toolchain ?? await const ToolchainProbe().detect();
    final warnings = <String>[];
    final raw = <Finding>[];
    ExternalSignals combined = ExternalSignals.disabled;
    for (final snapshot in snapshots) {
      final signals = await _signals(snapshot, config, request, warnings);
      combined = _mergeSignals(combined, signals);
      final scope = RuleScope(
        project: snapshot,
        workspace: snapshots,
        config: config,
        signals: signals,
      );
      for (final rule in registry.enabled(config)) {
        raw.addAll(rule.evaluate(scope));
      }
    }
    final visible = raw
        .where((finding) => finding.severity.rank >= config.minSeverity.rank)
        .toList();
    final fingerprinted = assignFingerprints(visible);
    final suppression = applySuppressions(
      findings: fingerprinted,
      config: config,
      projects: snapshots,
    );
    final BaselineComparison baseline;
    if (!config.baselineEnabled) {
      baseline = BaselineComparison.disabled;
    } else {
      final baselinePath = SafePath(root).joinInside(config.baselinePath);
      if (baselinePath == null) {
        throw ConfigException(
          'baseline.path escapes the project and was refused.',
        );
      }
      final file = readBaseline(baselinePath);
      baseline = compareBaseline(
        active: suppression.active,
        suppressedFingerprints: {
          for (final item in suppression.suppressed) item.finding.fingerprint,
        },
        baseline: file,
      );
    }
    final reported = baseline.enabled
        ? ([...baseline.newFindings, ...baseline.existing]
            ..sort(compareFindings))
        : suppression.active;
    final gate = evaluateGate(
      config: config,
      findings: reported,
      baseline: baseline,
    );
    final report = ScanReport(
      generatedAt: request.now,
      dartVersion: toolchain.dartVersion,
      flutterVersion: toolchain.flutterVersion,
      projects: snapshots,
      findings: reported,
      suppressed: suppression.suppressed,
      baseline: baseline,
      gate: gate,
      signals: combined,
      warnings: warnings,
    );
    WrittenReports? reports;
    if (request.writeReports) {
      reports = writeReports(rootPath: root, config: config, report: report);
      if (config.openHtml) {
        try {
          await openHtmlReport(root, reports.indexHtml);
        } on ProcessException catch (error) {
          warnings.add('Could not open the HTML report: ${error.message}');
        }
      }
    }
    return ScanExecution(
      report: report,
      reports: reports,
      exitCode: gate.passed ? ExitCodes.success : ExitCodes.gateFailed,
    );
  }

  Future<ExternalSignals> _signals(
    ProjectSnapshot snapshot,
    FlutterGuardConfig config,
    ScanRequest request,
    List<String> warnings,
  ) async {
    final outdatedEnabled = config.outdatedChecks && !request.offline;
    final vulnerabilityEnabled = config.vulnerabilityChecks && !request.offline;
    if (!outdatedEnabled && !vulnerabilityEnabled) {
      return ExternalSignals.disabled;
    }
    var outdatedStatus = outdatedEnabled ? 'ok' : 'disabled';
    var vulnerabilityStatus = vulnerabilityEnabled ? 'ok' : 'disabled';
    final outdated = <OutdatedPackage>[];
    final advisories = <PackageAdvisory>[];
    if (outdatedEnabled) {
      try {
        final client = request.outdatedClient ?? ProcessOutdatedClient();
        outdated.addAll(await client.fetch(snapshot.project.rootPath));
      } catch (error) {
        outdatedStatus = 'unavailable';
        warnings.add('Outdated check skipped: $error');
      }
    }
    if (vulnerabilityEnabled) {
      final client = request.vulnerabilityClient ?? OsvVulnerabilityClient();
      try {
        for (final locked in snapshot.lockedPackages.where(
          (item) => item.direct,
        )) {
          advisories.addAll(
            await client.fetch(package: locked.name, version: locked.version),
          );
        }
      } catch (error) {
        vulnerabilityStatus = 'unavailable';
        warnings.add('Vulnerability check skipped: $error');
      }
    }
    return ExternalSignals(
      outdatedStatus: outdatedStatus,
      vulnerabilityStatus: vulnerabilityStatus,
      outdated: outdated,
      advisories: advisories,
      warnings: const [],
    );
  }
}

ExternalSignals _mergeSignals(ExternalSignals left, ExternalSignals right) {
  if (left.outdatedStatus == 'disabled' &&
      left.vulnerabilityStatus == 'disabled') {
    return right;
  }
  return ExternalSignals(
    outdatedStatus: right.outdatedStatus,
    vulnerabilityStatus: right.vulnerabilityStatus,
    outdated: [...left.outdated, ...right.outdated],
    advisories: [...left.advisories, ...right.advisories],
    warnings: [...left.warnings, ...right.warnings],
  );
}
