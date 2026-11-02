import '../../core/config.dart';
import '../../core/finding.dart';
import '../../core/redaction.dart';
import '../../core/severity.dart';
import '../rule.dart';

/// Android permissions [PermissionRiskRule] treats as high-impact.
///
/// A manifest permission is reported only when its name is in this set.
/// Presence is a review signal, not proof that the permission is misused.
const dangerousPermissions = {
  'android.permission.READ_SMS',
  'android.permission.SEND_SMS',
  'android.permission.READ_CONTACTS',
  'android.permission.ACCESS_FINE_LOCATION',
  'android.permission.RECORD_AUDIO',
  'android.permission.CAMERA',
  'android.permission.QUERY_ALL_PACKAGES',
  'android.permission.MANAGE_EXTERNAL_STORAGE',
  'android.permission.REQUEST_INSTALL_PACKAGES',
  'android.permission.READ_CALL_LOG',
};

final class _SecretHit {
  const _SecretHit({
    required this.line,
    required this.column,
    required this.kind,
    required this.label,
    required this.severity,
    required this.ruleId,
  });

  final int line;
  final int column;
  final String kind;
  final String label;
  final Severity severity;
  final String ruleId;
}

List<_SecretHit> _findSecretHits(String text) {
  final hits = <_SecretHit>[];
  final occupied = <int>{};
  void add(RegExp pattern, _SecretHit? Function(RegExpMatch match) build) {
    for (final match in pattern.allMatches(text)) {
      if (occupied.contains(match.start)) {
        continue;
      }
      final hit = build(match);
      if (hit == null) {
        continue;
      }
      occupied.add(match.start);
      hits.add(hit);
    }
  }

  add(
    RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'),
    (match) => _SecretHit(
      line: _line(text, match.start),
      column: _column(text, match.start),
      kind: 'private key',
      label: 'private key',
      severity: Severity.critical,
      ruleId: 'FG-SEC-001',
    ),
  );
  add(
    RegExp(r'AKIA[0-9A-Z]{16}'),
    (match) => _SecretHit(
      line: _line(text, match.start),
      column: _column(text, match.start),
      kind: 'cloud access key id',
      label: 'access key',
      severity: Severity.critical,
      ruleId: 'FG-SEC-001',
    ),
  );
  add(
    RegExp(r'AIza[0-9A-Za-z\-_]{35}'),
    (match) => _SecretHit(
      line: _line(text, match.start),
      column: _column(text, match.start),
      kind: 'API key',
      label: 'api key',
      severity: Severity.high,
      ruleId: 'FG-SEC-001',
    ),
  );
  add(
    RegExp(
      r'(client[_-]?secret|aws[_-]?secret|authorization)\s*[:=]\s*['
      r"'"
      r'"][^'
      r"'"
      r'"]{6,}['
      r"'"
      r'"]',
      caseSensitive: false,
    ),
    (match) => _SecretHit(
      line: _line(text, match.start),
      column: _column(text, match.start),
      kind: 'credential',
      label: match.group(1) ?? 'credential',
      severity: Severity.high,
      ruleId: 'FG-SEC-002',
    ),
  );
  add(
    RegExp(
      r'(api[_-]?key|secret|token|password|passwd|pwd|private[_-]?key|access[_-]?key)\s*[:=]\s*['
      r"'"
      r'"]([^'
      r"'"
      r'"]{6,})['
      r"'"
      r'"]',
      caseSensitive: false,
    ),
    (match) {
      final value = match.group(2) ?? '';
      if (isPlaceholderSecret(value)) {
        return null;
      }
      return _SecretHit(
        line: _line(text, match.start),
        column: _column(text, match.start),
        kind: 'assigned secret',
        label: match.group(1) ?? 'secret',
        severity: Severity.high,
        ruleId: 'FG-SEC-001',
      );
    },
  );
  return hits;
}

int _line(String text, int offset) =>
    text.substring(0, offset).split('\n').length;

int _column(String text, int offset) {
  final newline = text.lastIndexOf('\n', offset - 1);
  return offset - newline;
}

/// Pattern check for private keys, access-key ids, and assigned secrets.
///
/// Placeholder values are dropped before a hit is recorded. Only hits tagged
/// for this rule are emitted; client-secret and authorization assignments are
/// left to [CredentialExposureRule]. The finding names the kind and label,
/// and the matched value is not copied into the message.
final class HardcodedSecretRule implements AuditRule {
  @override
  String get id => 'FG-SEC-001';
  @override
  String get title => 'Hardcoded secret';
  @override
  String get category => 'security';
  @override
  Severity get defaultSeverity => Severity.high;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.security;
  @override
  String get description =>
      'Pattern check for private keys, access-key ids, and assigned secret values. Values are redacted and the match is not proof of a live credential.';
  @override
  String get recommendation =>
      'Remove the value from source and load it from the environment or the platform secret store.';

  @override
  List<Finding> evaluate(RuleScope scope) =>
      _secrets(this, scope, 'FG-SEC-001');
}

/// Pattern check for client secrets, cloud secrets, and authorization assignments.
///
/// Only hits tagged for this rule are emitted. ARB files and files without
/// text are skipped. The matched value is not copied into the finding.
final class CredentialExposureRule implements AuditRule {
  @override
  String get id => 'FG-SEC-002';
  @override
  String get title => 'Credential exposure';
  @override
  String get category => 'security';
  @override
  Severity get defaultSeverity => Severity.high;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.security;
  @override
  String get description =>
      'Pattern check for client secrets, cloud secrets, and authorization assignments.';
  @override
  String get recommendation =>
      'Rotate the credential if it was ever real, and keep the replacement outside the repository.';

  @override
  List<Finding> evaluate(RuleScope scope) =>
      _secrets(this, scope, 'FG-SEC-002');
}

List<Finding> _secrets(AuditRule rule, RuleScope scope, String ruleId) {
  final findings = <Finding>[];
  for (final file in scope.project.files.files) {
    final text = file.text;
    if (text == null || file.relativePosix.endsWith('.arb')) {
      continue;
    }
    for (final hit in _findSecretHits(text)) {
      if (hit.ruleId != ruleId) {
        continue;
      }
      findings.add(
        emit(
          rule,
          scope,
          message:
              'Possible ${hit.kind} assigned to "${hit.label}" was redacted. This is a heuristic, not proof of a vulnerability.',
          path: file.relativePosix,
          line: hit.line,
          column: hit.column,
          severity: hit.severity,
        ),
      );
    }
  }
  return findings;
}

/// Flags `print`, `debugPrint`, and `log` calls whose arguments look sensitive.
///
/// Hits come from the Dart index. The argument value is not included in the
/// finding, which names the callee and the enclosing declaration.
final class SensitiveLoggingRule implements AuditRule {
  @override
  String get id => 'FG-SEC-003';
  @override
  String get title => 'Sensitive logging';
  @override
  String get category => 'security';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.security;
  @override
  String get description =>
      'Flags print, debugPrint, and log calls whose arguments look sensitive.';
  @override
  String get recommendation =>
      'Do not log secrets. The argument value is not included in the report.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final file in scope.project.dartIndex.files) {
      for (final call in file.sensitiveLogs) {
        findings.add(
          emit(
            this,
            scope,
            message:
                'Sensitive value passed to ${call.name}() was redacted. This is a heuristic.',
            path: file.path,
            line: call.line,
            column: call.column,
            enclosing: call.enclosing,
          ),
        );
      }
    }
    return findings;
  }
}

/// Reports cleartext HTTP URLs, Android cleartext traffic, and iOS arbitrary loads.
///
/// A `http://` string is ignored when its host equals an `allowedHosts`
/// entry, compared without case. Generated Dart files are skipped. A
/// manifest with cleartext traffic and an Info.plist with
/// `NSAllowsArbitraryLoads` are reported separately.
final class UnsafeHttpRule implements AuditRule {
  @override
  String get id => 'FG-SEC-004';
  @override
  String get title => 'Unsafe HTTP configuration';
  @override
  String get category => 'security';
  @override
  Severity get defaultSeverity => Severity.high;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.security;
  @override
  String get description =>
      'Reports cleartext http URLs, Android cleartext traffic, and iOS arbitrary loads.';
  @override
  String get recommendation =>
      'Use HTTPS. Local and documentation hosts in allowedHosts are ignored.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final file in scope.project.dartIndex.files) {
      if (file.generated) {
        continue;
      }
      for (final literal in file.strings) {
        if (!literal.value.startsWith('http://')) {
          continue;
        }
        final host = Uri.tryParse(literal.value)?.host.toLowerCase() ?? '';
        if (_allowedHost(host, scope)) {
          continue;
        }
        findings.add(
          emit(
            this,
            scope,
            message: 'Cleartext HTTP URL for host $host.',
            path: file.path,
            line: literal.line,
            column: literal.column,
          ),
        );
      }
    }
    for (final manifest in scope.project.manifests) {
      if (manifest.cleartext) {
        findings.add(
          emit(
            this,
            scope,
            message: 'AndroidManifest sets usesCleartextTraffic="true".',
            path: manifest.path,
          ),
        );
      }
    }
    if (scope.project.arbitraryLoads) {
      findings.add(
        emit(
          this,
          scope,
          message: 'Info.plist sets NSAllowsArbitraryLoads true.',
          path: 'ios/Runner/Info.plist',
        ),
      );
    }
    return findings;
  }

  bool _allowedHost(String host, RuleScope scope) {
    for (final allowed in scope.config.allowedHosts) {
      if (host == allowed.toLowerCase()) {
        return true;
      }
    }
    return false;
  }
}

/// AST check for `badCertificateCallback` and `onBadCertificate`.
///
/// Each hit recorded by the Dart index is reported. A callback is not by
/// itself proof that every certificate is accepted.
final class TlsBypassRule implements AuditRule {
  @override
  String get id => 'FG-SEC-005';
  @override
  String get title => 'TLS bypass pattern';
  @override
  String get category => 'security';
  @override
  Severity get defaultSeverity => Severity.high;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.security;
  @override
  String get description =>
      'AST check for badCertificateCallback and onBadCertificate. A callback is not by itself proof that certificates are ignored.';
  @override
  String get recommendation =>
      'Remove blanket certificate acceptance. Pin or trust a specific certificate if a private CA is required.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final file in scope.project.dartIndex.files) {
      for (final hit in file.tlsBypasses) {
        findings.add(
          emit(
            this,
            scope,
            message:
                'Found ${hit.label}. Confirm it does not accept every certificate. This is a heuristic.',
            path: file.path,
            line: hit.line,
            column: hit.column,
            enclosing: hit.enclosing,
          ),
        );
      }
    }
    return findings;
  }
}

/// Flags SharedPreferences writes whose key looks like a token or secret.
///
/// Hits come from the Dart index. The stored value is not copied into the
/// finding, which names the SharedPreferences method.
final class InsecureStorageRule implements AuditRule {
  @override
  String get id => 'FG-SEC-006';
  @override
  String get title => 'Insecure storage pattern';
  @override
  String get category => 'security';
  @override
  Severity get defaultSeverity => Severity.high;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.security;
  @override
  String get description =>
      'Flags SharedPreferences writes whose key looks like a token, password, or secret.';
  @override
  String get recommendation =>
      'Prefer the platform secure storage API for credentials. The stored value is not copied into the report.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final file in scope.project.dartIndex.files) {
      for (final hit in file.insecureStores) {
        findings.add(
          emit(
            this,
            scope,
            message:
                'SharedPreferences.${hit.method} uses a sensitive key. The value was redacted. This is a heuristic.',
            path: file.path,
            line: hit.line,
            column: hit.column,
          ),
        );
      }
    }
    return findings;
  }
}

/// Lists high-impact Android permissions declared in a manifest.
///
/// Only names in [dangerousPermissions] are reported. Other permissions are
/// ignored. Presence is not proof of misuse.
final class PermissionRiskRule implements AuditRule {
  @override
  String get id => 'FG-SEC-007';
  @override
  String get title => 'Platform permission risk';
  @override
  String get category => 'security';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => true;
  @override
  AuditModule get module => AuditModule.security;
  @override
  String get description =>
      'Lists high-impact Android permissions. Presence is not proof of misuse.';
  @override
  String get recommendation =>
      'Drop permissions the app does not need and add a user-facing disclosure for the ones it keeps.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    final findings = <Finding>[];
    for (final manifest in scope.project.manifests) {
      for (final permission in manifest.permissions) {
        if (!dangerousPermissions.contains(permission)) {
          continue;
        }
        findings.add(
          emit(
            this,
            scope,
            message: 'Declares $permission. Review whether the app needs it.',
            path: manifest.path,
          ),
        );
      }
    }
    return findings;
  }
}

/// Reports symlinks the scanner refused because they leave the project.
///
/// Each path in the file index's escaped-symlink list becomes one finding.
/// Those links are not read.
final class EscapedSymlinkRule implements AuditRule {
  @override
  String get id => 'FG-SEC-008';
  @override
  String get title => 'Symlink escapes the project';
  @override
  String get category => 'security';
  @override
  Severity get defaultSeverity => Severity.medium;
  @override
  bool get heuristic => false;
  @override
  AuditModule get module => AuditModule.security;
  @override
  String get description =>
      'A symlink could not be proven to stay inside the project, so FlutterGuard did not read it.';
  @override
  String get recommendation =>
      'Replace the symlink with a real file inside the project or remove it from the scan root.';

  @override
  List<Finding> evaluate(RuleScope scope) {
    return [
      for (final link in scope.project.files.escapedSymlinks)
        emit(
          this,
          scope,
          message:
              'Skipped symlink that resolves outside the project or is broken.',
          path: link,
        ),
    ];
  }
}

/// Built-in security rules, in a stable evaluation order.
List<AuditRule> securityRules() => [
  HardcodedSecretRule(),
  CredentialExposureRule(),
  SensitiveLoggingRule(),
  UnsafeHttpRule(),
  TlsBypassRule(),
  InsecureStorageRule(),
  PermissionRiskRule(),
  EscapedSymlinkRule(),
];
