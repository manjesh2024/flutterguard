/// Coarse severity used by rules, reports, and quality gates.
///
/// [rank] orders the values from [info] through [critical]. The quality gate
/// fails on the severities listed in configuration, which defaults to
/// [high] and [critical].
enum Severity {
  /// Informational note that does not suggest a defect.
  info(0),

  /// Low-confidence or low-impact review signal.
  low(1),

  /// Issue worth reviewing before release.
  medium(2),

  /// Issue the default quality gate treats as a failure.
  high(3),

  /// Issue the default quality gate treats as a failure.
  critical(4);

  /// Creates a severity whose sort position is [rank].
  const Severity(this.rank);

  /// Sort weight. Higher values are more severe.
  final int rank;

  /// Severities in report order, most severe first.
  static const List<Severity> reportOrder = [
    Severity.critical,
    Severity.high,
    Severity.medium,
    Severity.low,
    Severity.info,
  ];

  /// Parses a severity name from configuration.
  ///
  /// [raw] must be `info`, `low`, `medium`, `high`, or `critical`.
  /// [path] is included in the [FormatException] message so the caller can
  /// point at the YAML key. Matching is case-sensitive and does not trim
  /// [raw].
  static Severity parse(String raw, {required String path}) {
    for (final severity in Severity.values) {
      if (severity.name == raw) {
        return severity;
      }
    }
    throw FormatException(
      '$path must be one of: ${Severity.values.map((item) => item.name).join(', ')}.',
    );
  }

  /// SARIF 2.1.0 result level for this severity.
  ///
  /// [critical] and [high] are `error`, [medium] is `warning`, and [low]
  /// and [info] are `note`.
  String get sarifLevel {
    return switch (this) {
      Severity.critical || Severity.high => 'error',
      Severity.medium => 'warning',
      Severity.low || Severity.info => 'note',
    };
  }
}
