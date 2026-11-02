# Changelog

## 0.2.1

- Add runnable public examples: a Flutter application, a workspace, a controlled findings sample, and a library program that uses the existing scan API.
- Document installation, configuration, reports, baselines, suppression, auto-fix, and exit codes in the example README that pub.dev shows on the Example tab.
- Run those examples from `tool/verify_all.sh`. The checks need the Flutter SDK.

## 0.2.0

- Compare customer-facing display names. Flutter engine plists are ignored, Xcode `PRODUCT_NAME` values are resolved, and spacing differences such as `Smoke App` and `smoke_app` match. Flavor-specific names stay out of that comparison.
- Treat Android debug, profile, and release manifests as overlays. A missing application label is reported on the main manifest when the main source set exists.
- Recognize SPDX identifiers and common license headings, including BSD redistribution text. Unrecognized license text is informational metadata. Flutter applications are not flagged for an empty pubspec license field.
- Treat constructor names and extension methods as uses of an imported library. Extension imports stay unfixed when the use is uncertain.
- State that unused-dependency results are a heuristic and that FlutterGuard does not remove dependencies. `CupertinoIcons` counts as a use of `cupertino_icons`.
- Skip short labels, debug text, and test files in the hardcoded-string heuristic.
- Replace the HTML report with a local dashboard: light and dark themes, summary cards, filters, sorting, expandable findings, and relative export links. JSON and SARIF schemas are unchanged.

## 0.1.2

- Document the public Dart API and enforce `public_member_api_docs`.
- Describe the published `dart pub global activate` install path, including `$HOME/.pub-cache/bin` on `PATH`.

## 0.1.1

- Document that `flutterguard_audit` 0.1.0 is published and that `$HOME/.pub-cache/bin` must be on `PATH` before `flutterguard` runs.

## 0.1.0

- Initial public release of the `flutterguard_audit` package and the `flutterguard` command.
- Single-command scan with discovery, eight audit modules, local reports, and quality gates.
- Baseline comparison, reasoned suppressions, and dry-run auto-fix for selected unused imports.
- Configuration schema version 1 and JSON report schema version 1.
