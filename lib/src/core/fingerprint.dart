import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Stable identity for a finding.
///
/// Line numbers are intentionally excluded so a finding keeps its identity
/// when surrounding lines move. An index disambiguates identical findings in
/// the same declaration.
String buildFingerprint({
  required String ruleId,
  required String? path,
  required String message,
  required String? enclosing,
  required int duplicateIndex,
}) {
  final payload = [
    ruleId,
    path ?? '',
    message.trim(),
    enclosing ?? '',
    '$duplicateIndex',
  ].join('|');
  return sha256.convert(utf8.encode(payload)).toString();
}
