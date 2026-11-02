final RegExp _privateKeyPattern = RegExp(
  r'-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----',
);

final RegExp _awsAccessKeyPattern = RegExp(r'AKIA[0-9A-Z]{16}');

final RegExp _googleApiKeyPattern = RegExp(r'AIza[0-9A-Za-z\-_]{35}');

final RegExp _slackTokenPattern = RegExp(r'xox[baprs]-[0-9A-Za-z-]{10,}');

final RegExp _githubTokenPattern = RegExp(r'ghp_[0-9A-Za-z]{20,}');

final RegExp _assignmentPattern = RegExp(
  '(api[_-]?key|secret|token|password|passwd|pwd|private[_-]?key|'
  r'access[_-]?key|client[_-]?secret)\s*[:=]\s*'
  """['"][^'"]{6,}['"]""",
  caseSensitive: false,
);

/// Removes secret-shaped values from any string that may reach a report,
/// log, or terminal. The replacement is stable so repeated passes are safe.
String redactSecrets(String input) {
  var text = input.replaceAll(_privateKeyPattern, '[REDACTED_PRIVATE_KEY]');
  text = text.replaceAll(_awsAccessKeyPattern, '[REDACTED]');
  text = text.replaceAll(_googleApiKeyPattern, '[REDACTED]');
  text = text.replaceAll(_slackTokenPattern, '[REDACTED]');
  text = text.replaceAll(_githubTokenPattern, '[REDACTED]');
  text = text.replaceAllMapped(_assignmentPattern, (match) {
    final key = match.group(1) ?? 'secret';
    return '$key=[REDACTED]';
  });
  return text;
}

/// True when [value] looks like a placeholder rather than a live credential.
bool isPlaceholderSecret(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.length < 8) {
    return true;
  }
  const placeholders = <String>{
    'changeme',
    'change_me',
    'password',
    'secret',
    'your_api_key',
    'your-api-key',
    'apikey',
    'api_key',
    'token',
    'todo',
    'fixme',
    'placeholder',
    'redacted',
    'example',
    'null',
    'none',
    'undefined',
  };
  if (placeholders.contains(normalized)) {
    return true;
  }
  return normalized.contains('your_') ||
      normalized.contains('example') ||
      normalized.contains('placeholder') ||
      normalized.contains('changeme') ||
      normalized.contains(r'${') ||
      normalized.contains('<') ||
      normalized.startsWith('todo');
}
