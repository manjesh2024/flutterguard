import 'package:xml/xml.dart';

final class PlistInfo {
  const PlistInfo({required this.values, required this.error});

  final Map<String, Object?> values;
  final String? error;

  String? string(String key) {
    final value = values[key];
    return value is String ? value : null;
  }

  bool boolValue(String key) => values[key] == true;
}

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
