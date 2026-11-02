import 'package:xml/xml.dart';

/// Values from the first `dict` in a property list, plus any parse error.
final class PlistInfo {
  /// Creates a plist model. Both arguments are required.
  ///
  /// error is null when a `dict` was decoded.
  const PlistInfo({required this.values, required this.error});

  /// Keys from the first `dict` mapped to decoded values.
  ///
  /// Strings and unrecognized tags are trimmed text. `true` and `false`
  /// become bools. `integer` becomes an int, or null when it does not parse.
  /// Nested `dict` elements become maps.
  final Map<String, Object?> values;

  /// Null when a `dict` was decoded. Otherwise `Info.plist has no dict.` or
  /// the XmlException message.
  final String? error;

  /// String stored for key, or null when the key is missing or the value is
  /// not a string.
  String? string(String key) {
    final value = values[key];
    return value is String ? value : null;
  }

  /// True only when key is stored as the boolean true.
  ///
  /// Missing keys, false, and every non-bool value return false.
  bool boolValue(String key) => values[key] == true;
}

/// Parses plist XML and reads the first `dict` in document order.
///
/// Each `key` element is paired with the following element. A document with
/// no `dict` returns an empty map and error `Info.plist has no dict.`.
/// Malformed XML does not throw: the map is empty and error is the
/// XmlException message.
PlistInfo parsePlist(String text) {
  try {
    final document = XmlDocument.parse(text);
    final dicts = document.findAllElements('dict');
    if (dicts.isEmpty) {
      return const PlistInfo(values: {}, error: 'Info.plist has no dict.');
    }
    return PlistInfo(values: _dict(dicts.first), error: null);
  } on XmlException catch (error) {
    return PlistInfo(values: const {}, error: error.message);
  }
}

Map<String, Object?> _dict(XmlElement dict) {
  final values = <String, Object?>{};
  final children = dict.childElements.toList();
  for (var i = 0; i < children.length; i++) {
    if (children[i].name.local != 'key' || i + 1 >= children.length) {
      continue;
    }
    values[children[i].innerText.trim()] = _value(children[i + 1]);
    i += 1;
  }
  return values;
}

Object? _value(XmlElement element) {
  switch (element.name.local) {
    case 'string':
      return element.innerText.trim();
    case 'true':
      return true;
    case 'false':
      return false;
    case 'integer':
      return int.tryParse(element.innerText.trim());
    case 'dict':
      return _dict(element);
    default:
      return element.innerText.trim();
  }
}
