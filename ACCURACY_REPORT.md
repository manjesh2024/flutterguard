# FlutterGuard 0.2.0 accuracy and report

Verified on 2026-11-02 after `./tool/verify_all.sh` passed and `flutterguard_audit` 0.2.0 was uploaded. Published versions 0.1.0, 0.1.1, and 0.1.2 were not changed, and their tags were not moved.

## Release status

| Item | Result |
| --- | --- |
| Version | 0.2.0 |
| Commit | `ba56a3790317d222cb51bf2b727227d6451e080b` |
| Tag | `v0.2.0` |
| GitHub release | https://github.com/manjesh2024/flutterguard/releases/tag/v0.2.0 |
| pub.dev | https://pub.dev/packages/flutterguard_audit version 0.2.0, published 2026-11-02T07:39:08.830569Z |
| pub.dev score | Not reported yet. The score API returned 0/0 at publication time, so no score is claimed. |
| JSON schema | `schemaVersion` remains 1 |
| SARIF | `version` remains `2.1.0` |
| Coverage | 85.94% line coverage of `lib/` (3837/4465), above the 80% gate |
| GitHub CI | No workflow change. CI already runs the repository tests and does not pin a package version. |

`dart pub publish --dry-run` passed inside `./tool/verify_all.sh`. The upload message was: successfully uploaded version 0.2.0. The package API then listed 0.2.0 as the latest version.

## Verification

`./tool/verify_all.sh` passed every stage: dependency resolution, formatting, `dart analyze --fatal-infos`, rule catalogue freshness, unit tests, fixture scans, integration tests, regression tests, CLI smoke tests, license check, publish dry-run, coverage, and git hygiene.

The suite reported 49 passing tests before that script, and the script ran those suites again. Existing assertions were not weakened. The clean fixture still has zero findings. The localization fixture still reports `FG-L10N-001` through `FG-L10N-006`, including `Text('Welcome back')`. The multi-flavor fixture still reports `FG-BRAND-003` and `FG-BRAND-005` because its default Android and iOS names are actually different.

A security-fixture scan did not modify source files. Its HTML, JSON, and SARIF reports did not contain the fixture's access-key or secret values. The HTML file has no remote stylesheet or script URL.

The generated dashboard was opened locally. Search reduced the table to the matching rule, the severity filter reduced that set further, column sorting set `aria-sort`, one finding expanded, the theme control switched between dark and light, and the relative JSON export loaded. At a 390px width the summary cards wrap and the metadata stacks.

## Confirmed fixes

The original clean Flutter smoke app was scanned again with FlutterGuard 0.2.0, offline. Source checksums outside the report directory were unchanged. The quality gate passed with exit code 0. These earlier hits were gone:

| Rule | What changed |
| --- | --- |
| `FG-BRAND-003` | `AppFrameworkInfo.plist` is not a display name. `$(PRODUCT_NAME)` resolves from a literal xcconfig value, and a pbxproj value of `$(TARGET_NAME)` does not override that literal. `Smoke App` and `smoke_app` compare as the same name. `@string/app_name` is read from `src/main/res/values/strings.xml`. Flavor names stay out of the default comparison. |
| `FG-PLAT-001` | Debug, profile, and release manifests are overlays. A missing label is reported on the main manifest when a main manifest exists. Exported components are still checked on every manifest. |
| `FG-DEP-004` | SPDX identifiers and common headings are recognized. BSD text that says "Redistribution and use in source and binary forms" is recognized even when the file never says BSD. `flutter_lints` 6.0.0 matches that wording. Unrecognized text is info and is described as metadata, not a violation. A Flutter application with a platform directory is not flagged for an empty pubspec license field. |
| `FG-QUAL-008` | Constructor references such as `const MyApp()` and `Greeter()` count as uses. A referenced extension method keeps the import. Libraries with no visible names stay used. Uncertain bare imports are still not auto-fixed. |
| `FG-DEP-001` | The check still searches indexed project files, including files other than the one that declares the dependency. `CupertinoIcons` counts as a use of `cupertino_icons`. The message says the result is a heuristic and that FlutterGuard did not remove the dependency. |
| `FG-L10N-006` | Test paths, debug-prefixed text, and labels shorter than 12 characters are skipped. `Welcome back` is still reported. |

New regression fixtures cover the Flutter template name set, Android main/debug/profile inheritance, iOS engine metadata, macOS `PRODUCT_NAME`, legitimate flavor names, SPDX and BSD headings, constructor and extension imports, and non-user-facing strings.

## Remaining findings

On the same smoke app, three findings remain:

- `FG-BRAND-004` medium: `ios/Runner/Assets.xcassets/AppIcon.appiconset` exists as a directory and contains no files.
- `FG-BRAND-004` low: `web/favicon.png` is absent. `web/icons` is not a favicon file.
- `FG-L10N-006` low: `Text('You have pushed the button this many times:')` in `lib/main.dart`. This is user-facing copy, so the heuristic still reports it.

`cupertino_icons` was not reported on that app because the Flutter template pubspec comment contains `CupertinoIcons`. A direct dependency with neither a `package:` reference nor that symbol is still reported, and the dependency is not removed.

`FG-CFG-003` duplicate framework identifiers and empty-host cleartext findings from the earlier Vyavsetu read-only scan were outside this change. They are unchanged.

The HTML report does not calculate a project score.
