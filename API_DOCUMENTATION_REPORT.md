# FlutterGuard API documentation report

Verified on 2026-11-02 after publishing `flutterguard_audit` 0.1.2.

`0.1.1` was already published, so this documentation release is 0.1.2. Scanner behavior and public signatures were not changed.

## Coverage

| | Before | After |
| --- | --- | --- |
| Source | pub.dev analysis of the previously published package | https://pub.dev/packages/flutterguard_audit/score for 0.1.2 |
| Public API elements | 287 | 287 |
| Documented API elements | 22 | 287 |
| Coverage | 7.7% | 100.0% |
| Dartdoc points | 0 of 10 | 10 of 10 |
| Total pub points | 150 of 160 | 160 of 160 |

The scores page says: "10/10 points: 20% or more of the public API has dartdoc comments. 287 out of 287 API elements (100.0%) have documentation comments." The documentation section total is 20/20. Pana 0.23.19 and Dart 3.13.5 produced that analysis.

Local `dart doc` on the same commit counted the same 287 public API elements, all with descriptions. `public_member_api_docs` is enabled. `dart analyze --fatal-infos` reported no issues. Before the comments were added, that lint reported 687 undocumented public members across `lib/`, including members that are not exported.

## What was documented

Every public class, constructor, field, getter, method, enum value, and top-level function in `lib/` now has a `///` comment that describes behavior. Important types such as `FlutterGuardConfig`, `FlutterGuardScanner`, `Finding`, and `FlutterGuardCli` include a short example that calls the real API.

The README no longer tells readers to wait until the package is published. It documents `dart pub global activate flutterguard_audit`, `$HOME/.pub-cache/bin` on `PATH`, `flutterguard` usage, Dart `^3.13.0`, the one-command scan, configuration, report paths, limitations, and the GitHub and pub.dev links.

## Verification

| Check | Result |
| --- | --- |
| `dart format --set-exit-if-changed` | PASS |
| `dart analyze --fatal-infos` | PASS, no issues |
| Unit, integration, regression, and CLI tests | PASS |
| `./tool/verify_all.sh` | PASS, including publish dry-run |
| Line coverage | 85.09% (3584/4212) |
| `dart doc --validate-links` | PASS, no broken links |
| `dart pub publish` | Uploaded 0.1.2 |

## Release

| Item | Value |
| --- | --- |
| Commit | `c99ce5c38b6a7fd129f1e6e0e21d9a941d3790f0` |
| Tag | `v0.1.2` |
| GitHub release | https://github.com/manjesh2024/flutterguard/releases/tag/v0.1.2 |
| Version published | 0.1.2 |
| Package | https://pub.dev/packages/flutterguard_audit |
| Scores | https://pub.dev/packages/flutterguard_audit/score |
| pub points | 160/160 |

## Remaining notes

The 0.1.2 archive includes the generated `doc/api/` tree. `.pubignore` did not exclude it, and pub does not apply `.gitignore` when `.pubignore` is present. Those pages contain no machine paths. `.pubignore` now excludes `doc/api/` for the next publish. No 0.1.3 was published for that exclusion.

`$HOME/.pub-cache/bin` is still absent from the default shell `PATH`. The README tells the user to add it.
