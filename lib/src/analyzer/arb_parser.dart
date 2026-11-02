import 'dart:convert';

/// One user-facing string from an ARB file, with the ICU shape of its text.
final class ArbMessage {
  /// Creates a message. Every argument is required.
  ///
  /// key is the ARB id and value is the raw message text. placeholders, kind,
  /// and cases describe ICU syntax found in that text.
  const ArbMessage({
    required this.key,
    required this.value,
    required this.placeholders,
    required this.kind,
    required this.cases,
  });

  /// ARB message id. Metadata keys that start with `@` are not stored.
  final String key;

  /// Raw message text, including any ICU placeholder syntax.
  final String value;

  /// Names of `{placeholder}` segments in value, including plural and select
  /// arguments.
  final Set<String> placeholders;

  /// The last `plural` or `select` keyword in value, or null when neither
  /// appears.
  final String? kind;

  /// Case labels gathered from every `plural` or `select` placeholder in
  /// value, such as `one` or `other`.
  final Set<String> cases;
}

/// Parsed ARB file: locale, messages, repeated keys, and any JSON error.
final class ArbCatalog {
  /// Creates a catalog for the file at path. Every argument is required.
  ///
  /// error is null when text parsed as a JSON object. On failure, messages
  /// and duplicateKeys are empty while path and locale are still set.
  const ArbCatalog({
    required this.path,
    required this.locale,
    required this.messages,
    required this.duplicateKeys,
    required this.error,
  });

  /// Project-relative path of the ARB file that was parsed.
  final String path;

  /// Locale from a `@@locale` string, otherwise a `_locale.arb` suffix in
  /// the file name, otherwise the file name itself.
  final String locale;

  /// String messages keyed by id. Keys starting with `@`, and values that
  /// are not strings, are omitted.
  final Map<String, ArbMessage> messages;

  /// Top-level keys, other than `@` metadata, each extra time they appear.
  ///
  /// Empty when JSON parsing fails, even if repeated keys were seen first.
  final List<String> duplicateKeys;

  /// FormatException message when text is not a JSON object. Null after a
  /// successful parse.
  final String? error;
}

/// Parses the ARB document text located at path.
///
/// Locale is resolved before decoding. Repeated top-level keys are collected
/// with a scan that still sees duplicates JSON decoding would collapse.
/// Malformed JSON, and a JSON value that is not an object, returns a catalog
/// whose error is the format message and whose message map is empty. This
/// does not throw FormatException.
ArbCatalog parseArb(String path, String text) {
  final locale = _locale(path, text);
  try {
    final duplicates = _duplicateTopLevelKeys(text);
    final decoded = _parseJsonObject(text);
    final messages = <String, ArbMessage>{};
    for (final entry in decoded.entries) {
      if (entry.key.startsWith('@') || entry.value is! String) {
        continue;
      }
      final value = entry.value as String;
      final parsed = _icu(value);
      messages[entry.key] = ArbMessage(
        key: entry.key,
        value: value,
        placeholders: parsed.placeholders,
        kind: parsed.kind,
        cases: parsed.cases,
      );
    }
    return ArbCatalog(
      path: path,
      locale: locale,
      messages: messages,
      duplicateKeys: duplicates,
      error: null,
    );
  } on FormatException catch (error) {
    return ArbCatalog(
      path: path,
      locale: locale,
      messages: const {},
      duplicateKeys: const [],
      error: error.message,
    );
  }
}

String _locale(String path, String text) {
  final marker = RegExp(r'"@@locale"\s*:\s*"([^"]+)"').firstMatch(text);
  if (marker != null) {
    return marker.group(1)!;
  }
  final name = path.split('/').last;
  final match = RegExp(r'_([A-Za-z]{2}(?:_[A-Za-z0-9]+)?)\.arb$')
      .firstMatch(name);
  return match?.group(1) ?? name;
}

List<String> _duplicateTopLevelKeys(String text) {
  final seen = <String>{};
  final duplicates = <String>[];
  var depth = 0;
  var inString = false;
  var escape = false;
  final buffer = StringBuffer();
  String? currentKey;
  var expectingKey = true;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (inString) {
      if (escape) {
        escape = false;
        buffer.write(char);
        continue;
      }
      if (char == r'\') {
        escape = true;
        continue;
      }
      if (char == '"') {
        inString = false;
        if (depth == 1 && expectingKey) {
          currentKey = buffer.toString();
        }
        buffer.clear();
        continue;
      }
      buffer.write(char);
      continue;
    }
    if (char == '"') {
      inString = true;
      continue;
    }
    if (char == '{' || char == '[') {
      depth += 1;
      if (depth == 1) {
        expectingKey = true;
      }
      continue;
    }
    if (char == '}' || char == ']') {
      depth -= 1;
      continue;
    }
    if (depth == 1 && char == ':') {
      if (currentKey != null && !currentKey.startsWith('@')) {
        if (!seen.add(currentKey)) {
          duplicates.add(currentKey);
        }
      }
      expectingKey = false;
      currentKey = null;
      continue;
    }
    if (depth == 1 && char == ',') {
      expectingKey = true;
    }
  }
  return duplicates;
}

Map<String, Object?> _parseJsonObject(String text) {
  final decoded = jsonDecode(text);
  if (decoded is! Map) {
    throw const FormatException('ARB file must be a JSON object.');
  }
  return decoded.map((key, value) => MapEntry(key.toString(), value));
}

final class _Icu {
  const _Icu(this.placeholders, this.kind, this.cases);
  final Set<String> placeholders;
  final String? kind;
  final Set<String> cases;
}

_Icu _icu(String value) {
  final placeholders = <String>{};
  String? kind;
  final cases = <String>{};
  var i = 0;
  while (i < value.length) {
    if (value[i] != '{') {
      i += 1;
      continue;
    }
    final endName = _nameEnd(value, i + 1);
    if (endName == null) {
      i += 1;
      continue;
    }
    final name = value.substring(i + 1, endName).trim();
    if (name.isEmpty) {
      i += 1;
      continue;
    }
    placeholders.add(name);
    var cursor = endName;
    while (cursor < value.length && value[cursor] == ' ') {
      cursor += 1;
    }
    if (cursor < value.length && value[cursor] == ',') {
      final kindEnd = _wordEnd(value, cursor + 1);
      final word = value.substring(cursor + 1, kindEnd).trim();
      if (word == 'plural' || word == 'select') {
        kind = word;
        final caseStart = value.indexOf(',', kindEnd);
        if (caseStart != -1) {
          cases.addAll(_cases(value, caseStart + 1));
        }
      }
    }
    i = endName;
  }
  return _Icu(placeholders, kind, cases);
}

int? _nameEnd(String value, int start) {
  var i = start;
  while (i < value.length) {
    final char = value[i];
    if (char == ',' || char == '}') {
      return i;
    }
    if (!_isNameChar(char) && char != ' ') {
      return null;
    }
    i += 1;
  }
  return null;
}

int _wordEnd(String value, int start) {
  var i = start;
  while (i < value.length && value[i] == ' ') {
    i += 1;
  }
  final begin = i;
  while (i < value.length && _isNameChar(value[i])) {
    i += 1;
  }
  return i == begin ? start : i;
}

Set<String> _cases(String value, int start) {
  final cases = <String>{};
  var i = start;
  while (i < value.length && value[i] != '}') {
    while (i < value.length && (value[i] == ' ' || value[i] == ',')) {
      i += 1;
    }
    final begin = i;
    while (i < value.length && _isNameChar(value[i])) {
      i += 1;
    }
    if (i > begin && i < value.length && value[i] == '{') {
      cases.add(value.substring(begin, i));
      i = _skipBrace(value, i);
      continue;
    }
    if (i < value.length && value[i] == '{') {
      i = _skipBrace(value, i);
    } else if (i < value.length) {
      i += 1;
    }
  }
  return cases;
}

int _skipBrace(String value, int open) {
  var depth = 0;
  for (var i = open; i < value.length; i++) {
    if (value[i] == '{') {
      depth += 1;
    } else if (value[i] == '}') {
      depth -= 1;
      if (depth == 0) {
        return i + 1;
      }
    }
  }
  return value.length;
}

bool _isNameChar(String char) {
  final code = char.codeUnitAt(0);
  return (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      (code >= 48 && code <= 57) ||
      char == '_' ||
      char == '=';
}
