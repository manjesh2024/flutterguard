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

final class ScanRequest {
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

  final String rootPath;
  final String? configPath;
  final bool writeReports;
  final DateTime now;
  final ToolchainInfo? toolchain;
  final bool offline;
  final OutdatedClient? outdatedClient;
  final VulnerabilityClient? vulnerabilityClient;
}

final class ScanExecution {
  const ScanExecution({
    required this.report,
    required this.reports,
    required this.exitCode,
  });

  final ScanReport report;
  final WrittenReports? reports;
  final int exitCode;
}

final class FlutterGuardScanner {
  const FlutterGuardScanner();

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
