import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:flutterguard_audit/flutterguard_audit.dart';
import 'package:flutterguard_audit/src/analyzer/arb_parser.dart';
import 'package:flutterguard_audit/src/analyzer/complexity.dart';
import 'package:flutterguard_audit/src/analyzer/dart_index.dart';
import 'package:flutterguard_audit/src/analyzer/gradle_parser.dart';
import 'package:flutterguard_audit/src/context/file_index.dart';
import 'package:flutterguard_audit/src/core/fingerprint.dart';
import 'package:flutterguard_audit/src/core/glob.dart';
import 'package:flutterguard_audit/src/core/redaction.dart';
import 'package:test/test.dart';

void main() {
  test('package version matches pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('version: $packageVersion'));
    expect(executableName, 'flutterguard');
  });

  test('globs match dart files and build directories', () {
    final dart = GlobMatcher('**/*.dart');
    expect(dart.matches('lib/main.dart'), isTrue);
    expect(dart.matches('main.dart'), isTrue);
    expect(dart.matches('lib/main.txt'), isFalse);
    final build = GlobMatcher('**/build/**');
    expect(build.matches('build/app.so'), isTrue);
    expect(build.matches('android/build/app.so'), isTrue);
    expect(build.matches('lib/main.dart'), isFalse);
  });

  test('redaction removes secret-shaped values and is stable', () {
    const secret = 'AKIAIOSFODNN7EXAMPLE';
    const assigned = 'apiKey = "supersecretvalue123"';
    final once = redactSecrets('$secret $assigned');
    expect(once.contains(secret), isFalse);
    expect(once.contains('supersecretvalue123'), isFalse);
    expect(redactSecrets(once), once);
    expect(isPlaceholderSecret('changeme'), isTrue);
    expect(isPlaceholderSecret('supersecretvalue123'), isFalse);
  });

  test('fingerprints ignore line numbers and stay distinct', () {
    final first = buildFingerprint(
      ruleId: 'FG-QUAL-005',
      path: 'lib/main.dart',
      message: 'print() call.',
      enclosing: 'main',
      duplicateIndex: 0,
    );
    final moved = buildFingerprint(
      ruleId: 'FG-QUAL-005',
      path: 'lib/main.dart',
      message: 'print() call.',
      enclosing: 'main',
      duplicateIndex: 0,
    );
    final second = buildFingerprint(
      ruleId: 'FG-QUAL-005',
      path: 'lib/main.dart',
      message: 'print() call.',
      enclosing: 'main',
      duplicateIndex: 1,
    );
    expect(first, moved);
    expect(first, isNot(second));
  });

  test('gradle parser reads flavors and release flags', () {
    final model = parseGradle('android/app/build.gradle', '''
android {
  defaultConfig {
    applicationId "com.multi.app"
    minSdk 24
  }
  buildTypes {
    release {
      debuggable true
      minifyEnabled false
    }
  }
  productFlavors {
    dev { applicationIdSuffix ".dev" }
    prod { applicationId "com.multi.prod" }
  }
}
''');
    expect(model.applicationIds, contains('com.multi.app'));
    expect(model.releaseDebuggable, isTrue);
    expect(model.releaseMinify, isFalse);
    expect(model.minSdk, 24);
    expect(model.flavors.map((flavor) => flavor.name), ['dev', 'prod']);
    expect(
      model.flavors.first.resolvedId('com.multi.app'),
      'com.multi.app.dev',
    );
  });

  test('arb parser finds duplicates, placeholders, and plurals', () {
    final catalog = parseArb('lib/l10n/app_en.arb', '''
{
  "@@locale": "en",
  "hello": "Hello {name}",
  "hello": "Hello again {name}",
  "items": "{count, plural, one{1 item} other{{count} items}}"
}
''');
    expect(catalog.locale, 'en');
    expect(catalog.duplicateKeys, contains('hello'));
    expect(catalog.messages['hello']!.placeholders, contains('name'));
    expect(catalog.messages['items']!.kind, 'plural');
    expect(catalog.messages['items']!.cases, containsAll(['one', 'other']));
  });

  test('cyclomatic complexity counts decisions', () {
    final unit = parseString(
      content: '''
int f(int x) {
  if (x > 0 && x < 10) {
    return x;
  }
  for (var i = 0; i < x; i++) {
    if (i == 2) {
      return i;
    }
  }
  return 0;
}
''',
      throwIfDiagnostics: false,
    );
    final function = unit.unit.declarations.first;
    expect(cyclomaticComplexity(function), 5);
  });

  test('import cycle is detected from the AST', () {
    final index = buildDartIndex(
      packageName: 'sample',
      files: [
        _dart('lib/a.dart', "import 'b.dart';\nclass A {}\n"),
        _dart('lib/b.dart', "import 'a.dart';\nclass B {}\n"),
      ],
    );
    expect(index.cycles, isNotEmpty);
    expect(index.cycles.single, contains('lib/a.dart'));
  });

  test('outdated and OSV parsers read documented payloads', () {
    final outdated = parseOutdatedJson('''
{"packages":[{"package":"http","kind":"direct","isDiscontinued":false,"current":{"version":"1.0.0"},"latest":{"version":"1.2.0"}}]}
''');
    expect(outdated.single.latest, '1.2.0');
    final advisories = parseOsvResponse(
      package: 'http',
      version: '1.0.0',
      body: '{"vulns":[{"id":"GHSA-test","summary":"example"}]}',
    );
    expect(advisories.single.id, 'GHSA-test');
  });

  test('init template is valid configuration', () {
    final config = parseConfig(configTemplate);
    expect(config.discoveryMode, DiscoveryMode.auto);
    expect(config.modules.values, everyElement(isTrue));
    expect(config.failOn, containsAll([Severity.high, Severity.critical]));
    expect(config.openHtml, isFalse);
    expect(config.outdatedChecks, isFalse);
  });

  test('malformed and unknown configuration fail closed', () {
    expect(
      () => parseConfig('version: [\n'),
      throwsA(
        isA<ConfigException>().having(
          (error) => error.message,
          'message',
          contains('Malformed YAML'),
        ),
      ),
    );
    expect(
      () => parseConfig('version: 1\nmodules:\n  notAModule: true\n'),
      throwsA(
        isA<ConfigException>().having(
          (error) => error.message,
          'message',
          contains('unknown key'),
        ),
      ),
    );
    expect(() => parseConfig('version: 9\n'), throwsA(isA<ConfigException>()));
    expect(
      () => parseConfig('version: 1\nreports:\n  directory: ../outside\n'),
      throwsA(
        isA<ConfigException>().having(
          (error) => error.message,
          'message',
          contains('refused'),
        ),
      ),
    );
  });
}

IndexedFile _dart(String path, String text) {
  return IndexedFile(
    relativePosix: path,
    size: text.length,
    text: text,
    tooLarge: false,
  );
}
