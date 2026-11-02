# FlutterGuard

FlutterGuard is a Dart command-line auditor for Flutter projects. One command discovers the project, runs the enabled audit modules, writes local reports, evaluates a quality gate, and returns an exit code.

The pub.dev package is `flutterguard_audit`. The terminal command is `flutterguard`.

## Features

- Project discovery for a single app, a Melos workspace, or a Dart pub workspace.
- Eight audit modules: branding, configuration, architecture, code quality, security, localization, dependencies, and platforms.
- Architecture checks use the Dart analyzer AST. The default profile does not assume Clean Architecture, BLoC, Riverpod, or Provider.
- Local HTML, JSON, Markdown, and SARIF reports. No project score is calculated.
- Baselines, suppressions with reasons, and stable fingerprints.
- Deterministic auto-fix for a narrow set of unused imports, with dry-run and backup.
- Secret-shaped values are redacted from terminal output and every report.

## Installation

`flutterguard_audit` is published on [pub.dev](https://pub.dev/packages/flutterguard_audit). The current release is 0.1.2.

```bash
dart pub global activate flutterguard_audit
```

Pub installs the `flutterguard` executable in `$HOME/.pub-cache/bin`. That directory is not on the default `PATH`. Add it, then check the version from any directory:

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
flutterguard --version
```

The command prints `flutterguard` and the installed version. Release 0.1.2 prints `flutterguard 0.1.2`. Dart `^3.13.0` is required because the package uses analyzer 14. That matches current Flutter stable.

From a checkout of this repository:

```bash
dart pub get
dart run bin/flutterguard.dart --version
```

## One-command usage

Inside a Flutter project:

```bash
flutterguard
```

That command:

1. Discovers the Flutter project, including monorepos when the root is a workspace.
2. Loads `.flutterguard.yaml` when it exists.
3. Uses safe defaults when the file is absent.
4. Runs every enabled module.
5. Writes `build/flutterguard/index.html`, `report.json`, `report.md`, and `report.sarif`.
6. Evaluates the quality gate.
7. Prints a summary.
8. Returns `0` when the gate passes, `1` when it fails, `2` for usage or configuration errors, and `3` for an unexpected runtime failure.

A missing configuration file does not block the scan. A malformed file stops the scan with an actionable error and does not write reports.

Optional commands:

```bash
flutterguard init
flutterguard rules list
flutterguard rules explain FG-ARCH-001
flutterguard baseline create
flutterguard baseline update
flutterguard fix --dry-run
flutterguard fix
flutterguard doctor
```

`flutterguard --offline` disables network-dependent checks. Those checks are already off by default.

## Library

Programs can run the same scan without the executable:

```dart
import 'package:flutterguard_audit/flutterguard_audit.dart';

final execution = await const FlutterGuardScanner().scan(
  ScanRequest(rootPath: '.'),
);
```

`execution.exitCode` is `0` when the quality gate passes and `1` when it fails. `FlutterGuardConfig.defaults` is the configuration used when `.flutterguard.yaml` is absent. `loadConfig` reads a project file and throws `ConfigException` when that file is present but invalid.

## Configuration

`flutterguard init` writes `.flutterguard.yaml` schema version 1. See [the configuration reference](https://github.com/manjesh2024/flutterguard/blob/main/docs/configuration.md). Unknown keys are errors. Absolute report paths and `..` segments are refused.

## Sample reports

A successful scan prints finding counts by severity and category. Reports stay under the project `build/flutterguard/` directory unless `reports.directory` points somewhere else inside the project. Open the HTML report locally. FlutterGuard does not upload source code.

## Supported platforms

The CLI runs on macOS, Linux, and Windows. It can audit Android, iOS, web, Windows, macOS, and Linux project files when those directories exist. `tool/verify_all.sh` is the macOS and Linux release check. Windows runs the same Dart checks through GitHub Actions.

## Limitations

- Security, business-logic, and string findings are heuristics. They are not proof of a vulnerability or a product defect.
- Outdated and vulnerability checks are optional, off by default, and report `unavailable` when the network call fails. They do not invent advisories.
- Auto-fix only removes a single-line unused import that is a prefix import, a show import, or a redundant `dart:core` import. It does not edit security-sensitive configuration.
- The default architecture profile is `none`.
- FlutterGuard does not execute the scanned application's scripts.
- There is no numeric project score.

## License

MIT. See the [license](https://github.com/manjesh2024/flutterguard/blob/main/LICENSE).

## Further reading

The repository guide lives in `docs/`. The pub package uses `doc/` because pub.dev expects a singular directory name.

- [Architecture](https://github.com/manjesh2024/flutterguard/blob/main/docs/architecture.md)
- [Audit modules](https://github.com/manjesh2024/flutterguard/blob/main/docs/modules.md)
- [Rule catalogue](https://github.com/manjesh2024/flutterguard/blob/main/docs/rule-catalogue.md)
- [Publishing](https://github.com/manjesh2024/flutterguard/blob/main/docs/publishing.md)
