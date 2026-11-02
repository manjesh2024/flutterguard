import 'package:xml/xml.dart';

final class ManifestInfo {
  const ManifestInfo({
    required this.path,
    required this.packageName,
    required this.label,
    required this.debuggable,
    required this.cleartext,
    required this.permissions,
    required this.exportedActivitiesWithoutIntent,
    required this.error,
  });

  final String path;
  final String? packageName;
  final String? label;
  final bool debuggable;
  final bool cleartext;
  final List<String> permissions;
  final List<String> exportedActivitiesWithoutIntent;
  final String? error;
}

ManifestInfo parseManifest(String path, String text) {
  try {
    final document = XmlDocument.parse(text);
    final root = document.rootElement;
    XmlElement? application;
    final permissions = <String>[];
    for (final element in root.childElements) {
      if (element.name.local == 'application') {
        application = element;
      } else if (element.name.local == 'uses-permission') {
        final name = _attr(element, 'name');
        if (name != null) {
          permissions.add(name);
        }
      }
    }
    final exported = <String>[];
    if (application != null) {
      for (final element in application.childElements) {
        if (element.name.local != 'activity' &&
            element.name.local != 'activity-alias' &&
            element.name.local != 'service' &&
            element.name.local != 'receiver') {
          continue;
        }
        if (_attr(element, 'exported') == 'true' &&
            !element.childElements.any(
              (child) => child.name.local == 'intent-filter',
            )) {
          exported.add(_attr(element, 'name') ?? element.name.local);
        }
      }
    }
    return ManifestInfo(
      path: path,
      packageName: _attr(root, 'package'),
      label: application == null ? null : _attr(application, 'label'),
      debuggable:
          application != null && _attr(application, 'debuggable') == 'true',
      cleartext:
          application != null &&
          _attr(application, 'usesCleartextTraffic') == 'true',
      permissions: permissions,
      exportedActivitiesWithoutIntent: exported,
      error: null,
    );
  } on XmlException catch (error) {
    return ManifestInfo(
      path: path,
      packageName: null,
      label: null,
      debuggable: false,
      cleartext: false,
      permissions: const [],
      exportedActivitiesWithoutIntent: const [],
      error: error.message,
    );
  }
}

String? _attr(XmlElement element, String localName) {
  for (final attribute in element.attributes) {
    if (attribute.name.local == localName) {
      return attribute.value;
    }
  }
  return null;
}
