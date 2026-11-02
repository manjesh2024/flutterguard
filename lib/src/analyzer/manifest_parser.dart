import 'package:xml/xml.dart';

/// Package, permissions, and export facts from one AndroidManifest.xml.
final class ManifestInfo {
  /// Creates a manifest model. Every argument is required.
  ///
  /// error is null after a successful parse. A failed parse stores the
  /// parser message and leaves the other fields null, false, or empty.
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

  /// Project-relative path of the manifest.
  final String path;

  /// `package` attribute on the root element, or null when it is absent.
  final String? packageName;

  /// `label` attribute of `application`, or null when that element or
  /// attribute is absent.
  final String? label;

  /// True when `application` sets `debuggable` to the string `true`.
  final bool debuggable;

  /// True when `application` sets `usesCleartextTraffic` to the string
  /// `true`.
  final bool cleartext;

  /// `name` values of top-level `uses-permission` elements.
  ///
  /// Permissions nested under another element are ignored. An entry without
  /// a `name` attribute is skipped.
  final List<String> permissions;

  /// Exported components under `application` that have no `intent-filter`.
  ///
  /// Includes `activity`, `activity-alias`, `service`, and `receiver` whose
  /// `exported` attribute is `true`. Each entry is that element's `name`, or
  /// the element name when `name` is absent.
  final List<String> exportedActivitiesWithoutIntent;

  /// XmlException message when the document cannot be parsed. Null after a
  /// successful parse.
  final String? error;
}

/// Parses the Android manifest at path.
///
/// Attributes are matched by local name, so an `android:` prefix does not
/// matter. Malformed XML does not throw: error is set to the XmlException
/// message and the other fields are left empty or false.
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
