/// Outcome of optional network checks. Default scans leave both disabled.
final class ExternalSignals {
  /// Creates a signal result. Every argument is required and stored as given.
  const ExternalSignals({
    required this.outdatedStatus,
    required this.vulnerabilityStatus,
    required this.outdated,
    required this.advisories,
    required this.warnings,
  });

  /// Status string for the outdated-package check.
  ///
  /// The disabled constant stores `disabled`.
  final String outdatedStatus;

  /// Status string for the vulnerability check.
  ///
  /// The disabled constant stores `disabled`.
  final String vulnerabilityStatus;

  /// Packages reported by the outdated check.
  final List<OutdatedPackage> outdated;

  /// Advisories reported by the vulnerability check.
  final List<PackageAdvisory> advisories;

  /// Notes collected while the checks ran.
  ///
  /// The disabled constant uses an empty list.
  final List<String> warnings;

  /// Both checks left off, with empty package, advisory, and warning lists.
  ///
  /// Both status strings are `disabled`.
  static const disabled = ExternalSignals(
    outdatedStatus: 'disabled',
    vulnerabilityStatus: 'disabled',
    outdated: [],
    advisories: [],
    warnings: [],
  );
}

/// One package reported by `dart pub outdated --json`.
final class OutdatedPackage {
  /// Creates an outdated package. Every argument is required.
  ///
  /// current and latest are null when the payload has no version string for
  /// that side.
  const OutdatedPackage({
    required this.name,
    required this.current,
    required this.latest,
    required this.discontinued,
  });

  /// Package name from the outdated payload.
  final String name;

  /// Version currently resolved, or null when the payload omitted it.
  final String? current;

  /// Newest reported version, or null when the payload omitted it.
  final String? latest;

  /// True when the payload marked the package discontinued.
  final bool discontinued;
}

/// One vulnerability advisory for a queried package version.
final class PackageAdvisory {
  /// Creates an advisory. Every argument is required.
  ///
  /// summary may be empty when the payload did not include one.
  const PackageAdvisory({
    required this.package,
    required this.version,
    required this.id,
    required this.summary,
  });

  /// Package name the advisory was requested for.
  final String package;

  /// Version string the advisory was requested for.
  final String version;

  /// Identifier from the advisory payload.
  final String id;

  /// Short description from the payload, or empty when it had none.
  final String summary;
}

/// Fetches outdated direct and dev packages for one project.
abstract interface class OutdatedClient {
  /// Returns outdated packages for the project at projectRoot.
  ///
  /// Implementations decide how the lookup is performed and which failures
  /// they throw.
  Future<List<OutdatedPackage>> fetch(String projectRoot);
}

/// Fetches vulnerability advisories for one package version.
abstract interface class VulnerabilityClient {
  /// Returns advisories for package at version.
  ///
  /// Both arguments are required. Implementations decide how the lookup is
  /// performed and which failures they throw.
  Future<List<PackageAdvisory>> fetch({
    required String package,
    required String version,
  });
}
