import 'dart:io';

import 'package:flutterguard_audit/src/analyzer/pubspec_reader.dart';
import 'package:flutterguard_audit/src/rules/dependencies/dependency_rules.dart';

void main() {
  final lock = File('pubspec.lock');
  if (!lock.existsSync()) {
    stderr.writeln('pubspec.lock is missing. Run dart pub get.');
    exit(1);
  }
  final packages = readLockFile(lock.readAsStringSync());
  final blocked = <String>[];
  final unknown = <String>[];
  for (final package in packages) {
    final kind = cachedLicenseKind(package.name, package.version);
    stdout.writeln(
      '${package.name} ${package.version}: ${kind ?? 'not in pub cache'}',
    );
    if (kind == 'GPL') {
      blocked.add(package.name);
    }
    if (kind == null || kind == 'unknown') {
      unknown.add(package.name);
    }
  }
  if (blocked.isNotEmpty) {
    stderr.writeln('Blocked licenses: ${blocked.join(', ')}');
    exit(1);
  }
  if (unknown.isNotEmpty) {
    stderr.writeln(
      'License metadata was not classified for: ${unknown.join(', ')}. '
      'This is recorded and does not fail when the file is absent from the cache.',
    );
  }
}
