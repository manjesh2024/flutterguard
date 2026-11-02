import 'dart:convert';
import 'dart:io';

import 'signals.dart';

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

final class ProcessOutdatedClient implements OutdatedClient {
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

final class OsvVulnerabilityClient implements VulnerabilityClient {
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
