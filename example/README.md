# FlutterGuard examples

FlutterGuard audits a Flutter project from one command. It discovers the app or workspace, runs the enabled modules, writes local HTML, JSON, Markdown, and SARIF reports, evaluates a quality gate, and returns an exit code. It does not upload source code and it does not calculate a project score.

The package name is `flutterguard_audit`. The command is `flutterguard`.

These examples live in the repository and in the published package:

- [basic_flutter_app](basic_flutter_app) is a runnable Flutter application.
- [advanced_monorepo](advanced_monorepo) is a workspace FlutterGuard can discover.
- [intentional_findings](intentional_findings) is a sample of deliberate findings.
- [library_api](library_api) calls the public Dart API.
- [flutterguard.yaml](flutterguard.yaml) is the canonical configuration.

Source on GitHub: <https://github.com/manjesh2024/flutterguard/tree/main/example>

## Prerequisites

- Dart `^3.13.0`. Current Flutter stable ships that SDK.
- Flutter, for the basic application and the monorepo apps.
- A checkout of this repository when you use `dart run bin/flutterguard.dart`.

## Installation

Activate the published package:

```bash
dart pub global activate flutterguard_audit
export PATH="$PATH:$HOME/.pub-cache/bin"
flutterguard --version
```

`$HOME/.pub-cache/bin` is not on the default `PATH`. The version line looks like `flutterguard 0.2.1`.

From a checkout, without activating:

```bash
dart pub get
dart run bin/flutterguard.dart --version
```

## Basic app

[basic_flutter_app](basic_flutter_app) has `lib/main.dart`, a notes feature under `lib/features/notes/`, a widget test, `analysis_options.yaml`, Android, iOS, and web metadata, and `.flutterguard.yaml`.

```bash
cd example/basic_flutter_app
flutter pub get
flutter analyze
flutter test
cd ../..
dart run bin/flutterguard.dart example/basic_flutter_app --offline --config example/basic_flutter_app/flutterguard.yaml
```

After activation, the same scan is `flutterguard example/basic_flutter_app --offline --config example/basic_flutter_app/flutterguard.yaml`.

Reports are written to `example/basic_flutter_app/build/flutterguard/`. Exit code 0 means the quality gate passed.

## Monorepo

[advanced_monorepo](advanced_monorepo) contains `shop_app`, `admin_app`, and the shared package `shared_ui`. The root is a pub workspace and a Melos package list. It is not itself a Flutter app.

How discovery works is written in [advanced_monorepo/README.md](advanced_monorepo/README.md).

```bash
dart run bin/flutterguard.dart example/advanced_monorepo --offline --config example/advanced_monorepo/flutterguard.yaml
```

The summary lists three projects. `apps/shop/lib/generated/skipped.dart` is excluded by `**/generated/**`. The gate passes. `FG-DEP-005` reports the `shared_ui` path dependencies. Those findings are expected for this workspace.

## Configuration

Copy [flutterguard.yaml](flutterguard.yaml) to the root of an app as `.flutterguard.yaml`. That hidden name is the file FlutterGuard loads when `--config` is omitted. `init` writes the same template:

pub.dev does not publish a file whose name starts with a dot, and it does not publish `pubspec.lock`. Each example therefore also contains `flutterguard.yaml` with the same bytes as its hidden config. A Git checkout loads the hidden file automatically. The commands below pass `--config` so they use the file that is visible in this package.

```bash
dart run bin/flutterguard.dart init --help
```

Run `init --path <app>` in an app that does not already have `.flutterguard.yaml`. `--force` replaces an existing file. Without a config file, the scan uses built-in defaults: discovery `auto`, every module on, architecture profile `none`, reports under `build/flutterguard`, and a quality gate that fails on high and critical. A missing file is not an error. A malformed file or an unknown key stops the scan with exit code 2 and does not write reports.

The basic app sets `discovery.mode: single` and leaves the other sections at those defaults. The monorepo file uses `monorepo` and `featureFirst`. The intentional sample uses `clean`. Those are three different profiles, not three copies of the full template.

| Field | Meaning |
| --- | --- |
| `version` | Must be `1`. |
| `discovery.mode` | `auto`, `single`, or `monorepo`. |
| `discovery.roots` | Relative project paths. Empty means walk the tree. `..` and absolute paths are refused. |
| `discovery.maxDepth` | Walk depth from 0 to 12. Default 4. |
| `include` | Globs that replace the default file set when present. |
| `exclude` | Globs that replace the default skip list when present. |
| `modules` | Turns `branding`, `configuration`, `architecture`, `codeQuality`, `security`, `localization`, `dependencies`, or `platform` on or off. |
| `architecture.profile` | `none`, `clean`, `featureFirst`, or `custom`. |
| `architecture.featureCoupling` | Reports a feature importing another feature's internals when true. |
| `architecture.businessLogicComplexity` | Complexity limit used by the business-logic rule. |
| `architecture.layers` | Required when `profile` is `custom`. |
| `codeQuality.complexityThreshold` | Method complexity above this value is reported. Default 15. |
| `codeQuality.classLineThreshold` | Class length limit. Default 300. |
| `codeQuality.methodLineThreshold` | Method length limit. Default 80. |
| `allowedHosts` | Hosts that hardcoded-endpoint checks ignore. |
| `severity.minReport` | Drops findings below this severity. |
| `severity.overrides` | Map of rule id to severity. |
| `suppressions` | Rule or fingerprint hides. `reason` is required. |
| `baseline.enabled` | Compares the scan with `baseline.path`. |
| `baseline.path` | Baseline JSON inside the project. |
| `baseline.failOnNew` | Gate fails when a new fingerprint appears. |
| `reports.directory` | Output directory inside the project. Default `build/flutterguard`. |
| `reports.formats` | `html`, `json`, `markdown`, and `sarif`. |
| `reports.history` | Also copies reports under `history/`. |
| `reports.openHtml` | Opens the HTML report when a desktop opener exists. |
| `qualityGate.failOn` | Severities that fail the gate. Default `high` and `critical`. |
| `qualityGate.maxFindings` | Optional cap on reported findings. |
| `qualityGate.maxNewFindings` | Optional cap on new baseline findings. |
| `network.outdatedChecks` | Runs `dart pub outdated` when true. Default false. |
| `network.vulnerabilityChecks` | Queries OSV when true. Default false. |
| `localization.requiredLocales` | Locales that must have an ARB catalog. |
| `customRules` | Extra contains-text rules. |
| `rules` | Per-rule enable flag. |

## Running a full scan

From the repository root:

```bash
dart run bin/flutterguard.dart example/basic_flutter_app --offline --config example/basic_flutter_app/flutterguard.yaml
```

`--offline` skips the optional network checks. Those checks are already off unless the config enables them.

Other commands:

```bash
dart run bin/flutterguard.dart doctor --path example/basic_flutter_app
dart run bin/flutterguard.dart rules list
dart run bin/flutterguard.dart rules explain FG-SEC-001
```

## Terminal output

A finished scan prints the tool version, the Dart and Flutter versions, the project names, finding counts by severity, the quality-gate result, and each finding as severity, rule id, path, and message. Secret-shaped text is redacted. The last lines list the report paths.

Exit code 1 still means the scan finished. It means the gate failed.

## Severity

| Severity | Meaning |
| --- | --- |
| critical | The default gate fails. Reserved for the strongest secret-shaped matches. |
| high | The default gate fails. |
| medium | Reported. The default gate does not fail on medium alone. |
| low | Reported. Used for many heuristic and hygiene checks. |
| info | Reported when `severity.minReport` is `info`, which is the default. |

## HTML report

Open `build/flutterguard/index.html` from the project you scanned. The page is self-contained: no remote CSS or JavaScript. It shows project metadata, severity cards, categories, a searchable findings table, filters, recommendations, baseline status, and links to the other report files. A theme control switches light and dark. The page does not show a project score.

## JSON, Markdown, and SARIF

The same directory contains:

- `report.json` with `schemaVersion` 1
- `report.md`
- `report.sarif` with SARIF `2.1.0`

JSON includes findings, suppressions, the baseline, the quality gate, and network status. SARIF can be uploaded as a GitHub code-scanning artifact.

## Architecture profiles

`none` does not invent Clean Architecture, BLoC, Riverpod, or Provider. `clean` expects presentation, application, domain, and data boundaries. `featureFirst` expects shared code and feature API or internal files. `custom` requires `architecture.layers`.

The monorepo uses `featureFirst`. The intentional sample uses `clean` and imports the data layer from presentation, which is `FG-ARCH-001`.

## Security checks

Security rules are heuristics. A hit is not proof of a vulnerability. Values that look like secrets are redacted and are not copied into the report. Placeholder text is ignored by the assigned-secret check.

The intentional sample uses the fake strings in [intentional_findings/lib/demo_secrets.dart](intentional_findings/lib/demo_secrets.dart). Do not replace them with real credentials.

Checked areas include assigned secrets, client-secret assignments, sensitive logging, cleartext HTTP, certificate-callback names, sensitive `shared_preferences` keys, a fixed set of Android permissions, and symlinks that escape the project.

## Localization checks

With two or more ARB catalogs, FlutterGuard compares keys, placeholders, and plural or select forms. `localization.requiredLocales` reports a locale that has no catalog. `Text('Welcome back')` in the intentional sample is `FG-L10N-006`. Short labels, debug text, and test files are not treated as that finding.

## Dependency checks

A direct dependency with no reference in the scanned files is `FG-DEP-001`. The message says the result is a heuristic. FlutterGuard does not remove the dependency. `collection` in the intentional sample is that case.

License text is classified from SPDX identifiers and common headings. Unrecognized text is informational. A Flutter application that has a platform directory is not flagged for an empty pubspec license field.

Outdated and vulnerability checks stay off unless `network` enables them. A failed network call is reported as unavailable. It does not invent an advisory.

## Baseline

Create a baseline from a copy when you want to accept current findings:

```bash
dart run bin/flutterguard.dart baseline create --path example/basic_flutter_app
```

That writes `.flutterguard-baseline.json` inside the app. Later scans mark new, existing, and resolved fingerprints. `baseline update` rewrites the file. The default config leaves the baseline disabled.

## Suppression

A suppression needs a reason. The intentional config hides `FG-QUAL-004` in `lib/review.dart`:

```yaml
suppressions:
  - rule: FG-QUAL-004
    path: lib/review.dart
    reason: The sample keeps one TODO so the suppression section can show a reasoned hide.
```

An inline comment has the same effect when it sits on the finding line or the line above:

```dart
// flutterguard:ignore FG-QUAL-005 reason: Demo only.
```

The ignored finding is listed with the reason. It is not deleted from the source.

## Safe auto-fix

Auto-fix removes only a single-line unused import that is a prefix import, a show import, or a redundant `dart:core` import. It does not remove dependencies and it does not edit security configuration.

Preview the unused show import in the intentional sample:

```bash
dart run bin/flutterguard.dart fix --dry-run --path example/intentional_findings
```

`--dry-run` writes nothing. `fix` without `--dry-run` edits the file and stores the previous bytes under `.flutterguard/backups/`. `fix --revert` restores the newest backup.

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | The gate passed, or a non-scan command finished. |
| 1 | The scan finished and the gate failed. |
| 2 | Usage, discovery, or configuration was refused. |
| 3 | An unexpected local failure. |

## GitHub Actions

CI for this repository runs `./tool/verify_all.sh` on pull requests and on `main`. A tag `vX.Y.Z` whose number matches `pubspec.yaml` runs that script and then publishes with `dart-lang/setup-dart/.github/workflows/publish.yml@v1` through GitHub environment `pub.dev`. Publishing uses OIDC. The repository does not store a pub.dev token. `workflow_dispatch` does not publish.

A workflow that only audits an app looks like this:

```yaml
name: FlutterGuard
on:
  pull_request:
permissions:
  contents: read
jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable
      - run: dart pub global activate flutterguard_audit
      - run: echo "$HOME/.pub-cache/bin" >> "$GITHUB_PATH"
      - run: flutterguard --offline
```

Run it from the Flutter app, or pass the app path. Exit code 1 fails the job when the gate fails. That is the scan result, not a crash.

## Troubleshooting

- `flutterguard: command not found`: add `$HOME/.pub-cache/bin` to `PATH`, then open a new shell.
- Exit code 2 and a message about configuration: the YAML has an unknown key, the wrong `version`, or a path that escapes the project. Fix the file. FlutterGuard will not ignore a broken config.
- Exit code 2 and "No Flutter project": the directory has no `pubspec.yaml` that depends on the Flutter SDK or a top-level `flutter:` section. Use `--path` or `discovery.roots`.
- Exit code 1: read the listed rule ids. The intentional sample is supposed to exit 1.
- Reports missing: the scan did not finish, or `reports.directory` points elsewhere inside the project.
- Network findings say unavailable: `network` checks are optional and were enabled, and the call failed. `--offline` skips them.

## API documentation

The library example is [library_api/bin/main.dart](library_api/bin/main.dart).

```bash
cd example/library_api
dart pub get
dart analyze --fatal-infos
dart run bin/main.dart
```

Dartdoc for the published package: <https://pub.dev/documentation/flutterguard_audit/latest/>

Repository guides:

- <https://github.com/manjesh2024/flutterguard>
- <https://github.com/manjesh2024/flutterguard/blob/main/docs/configuration.md>
- <https://github.com/manjesh2024/flutterguard/blob/main/docs/rule-catalogue.md>
- <https://github.com/manjesh2024/flutterguard/blob/main/docs/modules.md>
- <https://github.com/manjesh2024/flutterguard/blob/main/docs/ci.md>
