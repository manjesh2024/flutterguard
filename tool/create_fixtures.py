#!/usr/bin/env python3
"""Create committed FlutterGuard audit fixtures. Not part of the CLI."""

import pathlib
import struct
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[1] / "test" / "fixtures"


def png() -> bytes:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    raw = b"\x00\xff\x00\x00"
    ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )


def write(path: str, text: str) -> None:
    file = ROOT / path
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(text)


def write_bytes(path: str, data: bytes) -> None:
    file = ROOT / path
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_bytes(data)


PUBSPEC = """name: {name}
description: Fixture.
publish_to: none
version: 0.0.1
license: MIT
environment:
  sdk: ^3.13.0
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
"""

CLEAN_PUBSPEC = """name: clean_app
description: Fixture with no intended findings.
publish_to: none
version: 0.0.1
license: MIT
environment:
  sdk: ^3.13.0
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
  assets:
    - assets/logo.png
"""

MANIFEST = """<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="{package}">
    <application android:label="{label}">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
"""

PLIST = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>{label}</string>
  <key>CFBundleIdentifier</key>
  <string>{bundle}</string>
  <key>CFBundleName</key>
  <string>{label}</string>
</dict>
</plist>
"""

GRADLE = """android {{
    defaultConfig {{
        applicationId "{app_id}"
        minSdk 24
    }}
    buildTypes {{
        release {{
            debuggable false
            minifyEnabled true
        }}
    }}
}}
"""


def platform(prefix: str, app_id: str, label: str) -> None:
    write(f"{prefix}/android/app/build.gradle", GRADLE.format(app_id=app_id))
    write(
        f"{prefix}/android/app/src/main/AndroidManifest.xml",
        MANIFEST.format(package=app_id, label=label),
    )
    write(f"{prefix}/ios/Runner/Info.plist", PLIST.format(label=label, bundle=app_id))
    write(
        f"{prefix}/ios/Runner.xcodeproj/project.pbxproj",
        f"PRODUCT_BUNDLE_IDENTIFIER = {app_id};\n",
    )
    write(
        f"{prefix}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json",
        '{"images":[]}\n',
    )
    write_bytes(f"{prefix}/android/app/src/main/res/mipmap-hdpi/ic_launcher.png", png())
    write_bytes(f"{prefix}/assets/logo.png", png())


write("clean_app/pubspec.yaml", CLEAN_PUBSPEC)
write(
    "clean_app/lib/main.dart",
    """import 'package:flutter/material.dart';

class CleanApp extends StatelessWidget {
  const CleanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
""",
)
platform("clean_app", "com.cleanapp.mobile", "Clean App")

write("simple_flutter/pubspec.yaml", PUBSPEC.format(name="simple_flutter"))
write(
    "simple_flutter/lib/main.dart",
    """import 'package:flutter/material.dart';

class SimpleApp extends StatelessWidget {
  const SimpleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: replace the sample host before release.
    print('starting');
    return const Text('ok');
  }
}

const api = 'https://api.customer.example/v1';
""",
)
platform("simple_flutter", "com.simple.flutter", "Simple")

write("multi_flavor/pubspec.yaml", PUBSPEC.format(name="multi_flavor"))
write(
    "multi_flavor/lib/main.dart",
    """import 'package:flutter/material.dart';

class MultiApp extends StatelessWidget {
  const MultiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
""",
)
write(
    "multi_flavor/android/app/build.gradle",
    """android {
    defaultConfig {
        applicationId "com.multi.app"
        minSdk 24
    }
    buildTypes {
        release {
            debuggable false
            minifyEnabled true
        }
    }
    productFlavors {
        dev {
            applicationIdSuffix ".dev"
            resValue "string", "app_name", "Multi Dev"
        }
        prod {
            applicationIdSuffix ".dev"
            resValue "string", "app_name", "Multi Prod"
        }
    }
}
""",
)
write(
    "multi_flavor/android/app/src/main/AndroidManifest.xml",
    MANIFEST.format(package="com.multi.app", label="Multi Android"),
)
write(
    "multi_flavor/ios/Runner/Info.plist",
    PLIST.format(label="Multi iOS", bundle="com.multi.app"),
)
write(
    "multi_flavor/ios/Runner.xcodeproj/project.pbxproj",
    "PRODUCT_BUNDLE_IDENTIFIER = com.multi.app;\n",
)
write(
    "multi_flavor/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json",
    "{}\n",
)
write_bytes("multi_flavor/android/app/src/main/res/mipmap-hdpi/ic_launcher.png", png())

write(
    "clean_architecture/.flutterguard.yaml",
    """version: 1
architecture:
  profile: clean
""",
)
write("clean_architecture/pubspec.yaml", PUBSPEC.format(name="clean_architecture"))
write(
    "clean_architecture/lib/presentation/home_page.dart",
    """import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../data/user_repository.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  int quote(int value) {
    if (value > 1 && value > 2 && value > 3 && value > 4 && value > 5 &&
        value > 6 && value > 7 && value > 8 && value > 9 && value > 10 &&
        value > 11 && value > 12) {
      return value;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final repository = UserRepository();
    rawQuery();
    return Text(repository.load());
  }
}

void rawQuery() {}
""",
)
write(
    "clean_architecture/lib/data/user_repository.dart",
    """class UserRepository {
  String load() => 'user';
}
""",
)
write(
    "clean_architecture/lib/domain/user.dart",
    """class User {
  const User(this.id);
  final String id;
}
""",
)
platform("clean_architecture", "com.clean.architecture", "Clean Architecture")

write("bloc_app/pubspec.yaml", PUBSPEC.format(name="bloc_app"))
write(
    "bloc_app/lib/counter_bloc.dart",
    """import 'counter_event.dart';

class CounterBloc {
  int mapEvent(Object event) => 0;
}
""",
)
write(
    "bloc_app/lib/counter_event.dart",
    """import 'counter_bloc.dart';

class CounterEvent {}
""",
)
write(
    "bloc_app/lib/counter_view.dart",
    """import 'package:flutter/material.dart';

import 'counter_bloc.dart';

class CounterView extends StatelessWidget {
  const CounterView({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
""",
)
platform("bloc_app", "com.bloc.app", "Bloc App")

write("riverpod_app/pubspec.yaml", PUBSPEC.format(name="riverpod_app"))
write(
    "riverpod_app/lib/counter_provider.dart",
    """class CounterNotifier {
  int value = 0;
}
""",
)
write(
    "riverpod_app/lib/counter_view.dart",
    """import 'package:flutter/material.dart';

import 'counter_provider.dart';

class CounterView extends ConsumerWidget {
  const CounterView({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
""",
)
platform("riverpod_app", "com.riverpod.app", "Riverpod App")

write("malformed_config/pubspec.yaml", PUBSPEC.format(name="malformed_config"))
write(
    "malformed_config/lib/main.dart",
    """class App {}
""",
)
write(
    "malformed_config/.flutterguard.yaml",
    """version: 2
""",
)

write(
    "monorepo/pubspec.yaml",
    """name: workspace_root
publish_to: none
environment:
  sdk: ^3.13.0
""",
)
write(
    "monorepo/melos.yaml",
    """name: workspace_root
packages:
  - apps/**
""",
)
write("monorepo/apps/alpha/pubspec.yaml", PUBSPEC.format(name="alpha"))
write(
    "monorepo/apps/alpha/lib/main.dart",
    """class Alpha {}
""",
)
write("monorepo/apps/alpha/android/app/build.gradle", GRADLE.format(app_id="com.shared.app"))
write(
    "monorepo/apps/alpha/android/app/src/main/AndroidManifest.xml",
    MANIFEST.format(package="com.shared.app", label="Alpha"),
)
write("monorepo/apps/beta/pubspec.yaml", PUBSPEC.format(name="beta"))
write(
    "monorepo/apps/beta/lib/main.dart",
    """void main() {
  print('beta');
}
""",
)
write("monorepo/apps/beta/android/app/build.gradle", GRADLE.format(app_id="com.shared.app"))
write(
    "monorepo/apps/beta/android/app/src/main/AndroidManifest.xml",
    MANIFEST.format(package="com.shared.app", label="Beta"),
)

write("security_app/pubspec.yaml", PUBSPEC.format(name="security_app"))
write(
    "security_app/lib/secrets.dart",
    '''const accessKey = '%s';'''
    % ("AKIA" + "IOSFODNN7EXAMPLE")
    + '''
const apiKey = 'supersecretvalue123';
const clientSecret = 'clientsecretvalue123';

void leak(String password) {
  print(password);
}

const endpoint = 'http://insecure.example';

void install(dynamic client) {
  client.badCertificateCallback = (cert, host, port) => true;
}
''',
)
write(
    "security_app/lib/storage.dart",
    """import 'package:shared_preferences/shared_preferences.dart';

Future<void> save(SharedPreferences prefs) async {
  await prefs.setString('auth_token', 'stored-token-value');
}
""",
)
write(
    "security_app/android/app/src/main/AndroidManifest.xml",
    """<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.security.app">
    <uses-permission android:name="android.permission.READ_SMS"/>
    <application android:label="Security" android:debuggable="true" android:usesCleartextTraffic="true">
        <activity android:name=".MainActivity" android:exported="true"/>
    </application>
</manifest>
""",
)
write(
    "security_app/android/app/build.gradle",
    """android {
    defaultConfig {
        applicationId "com.security.app"
        minSdk 24
    }
    buildTypes {
        release {
            debuggable true
            minifyEnabled false
        }
    }
}
""",
)

write(
    "localization_app/.flutterguard.yaml",
    """version: 1
localization:
  requiredLocales:
    - en
    - es
    - fr
""",
)
write("localization_app/l10n.yaml", "arb-dir: lib/l10n\ntemplate-arb-file: app_en.arb\n")
write("localization_app/pubspec.yaml", PUBSPEC.format(name="localization_app"))
write(
    "localization_app/lib/l10n/app_en.arb",
    """{
  "@@locale": "en",
  "hello": "Hello {name}",
  "hello": "Hello again {name}",
  "items": "{count, plural, one{1 item} other{{count} items}}",
  "onlyEn": "Only English"
}
""",
)
write(
    "localization_app/lib/l10n/app_es.arb",
    """{
  "@@locale": "es",
  "hello": "Hola",
  "items": "{count, plural, other{{count} elementos}}",
  "extra": "Solo espanol"
}
""",
)
write(
    "localization_app/lib/greeting.dart",
    """import 'package:flutter/material.dart';

class Greeting extends StatelessWidget {
  const Greeting({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('Welcome back');
  }
}
""",
)

write("auto_fix/pubspec.yaml", PUBSPEC.format(name="auto_fix"))
write(
    "auto_fix/lib/main.dart",
    """import 'dart:async' as async show Future;
import 'dart:core';

class AutoFixApp {
  void ready() {}
}
""",
)

write(
    "feature_coupling/pubspec.yaml",
    PUBSPEC.format(name="feature_coupling"),
)
write(
    "feature_coupling/lib/features/account/account.dart",
    """class AccountApi {}
""",
)
write(
    "feature_coupling/lib/features/billing/billing_page.dart",
    """import '../account/internal/account_store.dart';

class BillingPage {}
""",
)
write(
    "feature_coupling/lib/features/account/internal/account_store.dart",
    """class AccountStore {}
""",
)

print(f"fixtures written under {ROOT}")
