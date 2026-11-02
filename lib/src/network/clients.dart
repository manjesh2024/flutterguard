import 'dart:convert';
import 'dart:io';

import 'signals.dart';

/// Parses the JSON object written by `dart pub outdated --json`.
///
/// Keeps objects in `packages` whose `kind` is `direct` or `dev` and whose
/// `package` is a string. current and latest are the nested `version`
/// strings, or null when that object has no string version. discontinued is
/// true only when `isDiscontinued` is the boolean true. Returns an empty
/// list when the root is not a JSON object or `packages` is not a list.
/// Invalid JSON throws FormatException.
List<OutdatedPackage> parseOutdatedJson(String text) {
  final decoded = jsonDecode(text);
  if (decoded is! Map || decoded['packages'] is! List) {
    return const [];
  }
  final packages = <OutdatedPackage>[];
  for (final item in decoded['packages'] as List) {
    if (item is! Map) {
      continue;
    }
    final kind = item['kind'];
    if (kind != 'direct' && kind != 'dev') {
      continue;
    }
    String? versionOf(Object? value) {
      if (value is Map && value['version'] is String) {
        return value['version'] as String;
      }
      return null;
    }

    final name = item['package'];
    if (name is! String) {
      continue;
    }
    packages.add(
      OutdatedPackage(
        name: name,
        current: versionOf(item['current']),
        latest: versionOf(item['latest']),
        discontinued: item['isDiscontinued'] == true,
      ),
    );
  }
  return packages;
}

/// Parses an OSV query body into advisories for the requested package version.
///
/// package and version are copied onto every advisory and are not read from
/// body. Entries in `vulns` are kept when they are objects with a string
/// `id`. summary is the string `summary`, or empty otherwise. Returns an
/// empty list when body is not a JSON object or `vulns` is not a list.
/// Invalid JSON throws FormatException.
List<PackageAdvisory> parseOsvResponse({
  required String package,
  required String version,
  required String body,
}) {
  final decoded = jsonDecode(body);
  if (decoded is! Map || decoded['vulns'] is! List) {
    return const [];
  }
  final advisories = <PackageAdvisory>[];
  for (final item in decoded['vulns'] as List) {
    if (item is! Map || item['id'] is! String) {
      continue;
    }
    advisories.add(
      PackageAdvisory(
        package: package,
        version: version,
        id: item['id'] as String,
        summary: item['summary'] is String ? item['summary'] as String : '',
      ),
    );
  }
  return advisories;
}

/// Outdated-package client that runs `dart pub outdated --json`.
///
/// ```dart
/// final packages = await ProcessOutdatedClient().fetch(projectRoot);
/// ```
final class ProcessOutdatedClient implements OutdatedClient {
  /// Runs `dart pub outdated --json` with projectRoot as the working directory.
  ///
  /// Returns the direct and dev packages parsed from stdout. A non-zero exit
  /// throws StateError naming that exit code. The process future is capped
  /// at 60 seconds and then throws TimeoutException. Invalid JSON in stdout
  /// throws FormatException. Failure to start `dart` throws ProcessException.
  /// This starts a subprocess.
  @override
  Future<List<OutdatedPackage>> fetch(String projectRoot) async {
    final result = await Process.run(
      'dart',
      ['pub', 'outdated', '--json'],
      workingDirectory: projectRoot,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    ).timeout(const Duration(seconds: 60));
    if (result.exitCode != 0) {
      throw StateError('dart pub outdated exited ${result.exitCode}');
    }
    return parseOutdatedJson(result.stdout as String);
  }
}

/// Vulnerability client that queries the OSV API for one Pub package version.
///
/// ```dart
/// final advisories = await OsvVulnerabilityClient().fetch(
///   package: 'http',
///   version: '1.2.0',
/// );
/// ```
final class OsvVulnerabilityClient implements VulnerabilityClient {
  /// Posts package and version to `https://api.osv.dev/v1/query`.
  ///
  /// The JSON body sets the ecosystem to `Pub`. Returns advisories parsed
  /// from a response whose status is 200. Any other status throws StateError
  /// naming that code. Opening the request and closing the response each
  /// time out after 15 seconds with TimeoutException. Invalid JSON in the
  /// body throws FormatException. The HTTP client is closed with force even
  /// when the request fails. This performs a network request.
  @override
  Future<List<PackageAdvisory>> fetch({
    required String package,
    required String version,
  }) async {
    final client = HttpClient();
    try {
      final request = await client
          .postUrl(Uri.parse('https://api.osv.dev/v1/query'))
          .timeout(const Duration(seconds: 15));
      request.headers.contentType = ContentType.json;
      request.add(
        utf8.encode(
          jsonEncode({
            'package': {'name': package, 'ecosystem': 'Pub'},
            'version': version,
          }),
        ),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw StateError('OSV returned ${response.statusCode}');
      }
      return parseOsvResponse(package: package, version: version, body: body);
    } finally {
      client.close(force: true);
    }
  }
}
