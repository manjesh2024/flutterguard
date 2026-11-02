/// Outcome of optional network checks. Default scans leave both disabled.
final class ExternalSignals {
  const ExternalSignals({
    required this.outdatedStatus,
    required this.vulnerabilityStatus,
    required this.outdated,
    required this.advisories,
    required this.warnings,
  });

  final String outdatedStatus;
  final String vulnerabilityStatus;
  final List<OutdatedPackage> outdated;
  final List<PackageAdvisory> advisories;
  final List<String> warnings;

  static const disabled = ExternalSignals(
    outdatedStatus: 'disabled',
    vulnerabilityStatus: 'disabled',
    outdated: [],
    advisories: [],
    warnings: [],
  );
}

final class OutdatedPackage {
  const OutdatedPackage({
    required this.name,
    required this.current,
    required this.latest,
    required this.discontinued,
  });

  final String name;
  final String? current;
  final String? latest;
  final bool discontinued;
}

final class PackageAdvisory {
  const PackageAdvisory({
    required this.package,
    required this.version,
    required this.id,
    required this.summary,
  });

  final String package;
  final String version;
  final String id;
  final String summary;
}

abstract interface class OutdatedClient {
  Future<List<OutdatedPackage>> fetch(String projectRoot);
}

abstract interface class VulnerabilityClient {
  Future<List<PackageAdvisory>> fetch({
    required String package,
    required String version,
  });
}
