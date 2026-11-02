/// Coarse severity used by rules, reports, and quality gates.
enum Severity {
  info(0),
  low(1),
  medium(2),
  high(3),
  critical(4);

  const Severity(this.rank);

  final int rank;

  static const List<Severity> reportOrder = [
    Severity.critical,
    Severity.high,
    Severity.medium,
    Severity.low,
    Severity.info,
  ];

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
  String get sarifLevel {
    return switch (this) {
      Severity.critical || Severity.high => 'error',
      Severity.medium => 'warning',
      Severity.low || Severity.info => 'note',
    };
  }
}
