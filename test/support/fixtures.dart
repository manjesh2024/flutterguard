import 'dart:io';

import 'package:path/path.dart' as p;

bool get fixturesPresent => Directory('test/fixtures/clean_app').existsSync();

Directory tempFixture(String name) {
  final source = Directory('test/fixtures/$name');
  if (!source.existsSync()) {
    throw StateError('Missing fixture $name');
  }
  final target = Directory.systemTemp.createTempSync('flutterguard_$name');
  _copy(source, target);
  return target;
}

void _copy(Directory source, Directory target) {
  target.createSync(recursive: true);
  for (final entity in source.listSync(followLinks: false)) {
    final destination = p.join(target.path, p.basename(entity.path));
    if (entity is Directory) {
      _copy(entity, Directory(destination));
    } else if (entity is File) {
      File(entity.path).copySync(destination);
    }
  }
}

Map<String, String> checksums(Directory root) {
  final files = <String, String>{};
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final relative = p.relative(entity.path, from: root.path);
    if (relative.startsWith('build') ||
        relative.contains('${p.separator}build${p.separator}')) {
      continue;
    }
    files[relative] = entity.readAsBytesSync().join(',');
  }
  return files;
}
