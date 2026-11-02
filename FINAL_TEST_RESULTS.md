# FlutterGuard test results

Recorded from `./tool/verify_all.sh` on macOS arm64, Dart 3.13.5, Flutter 3.47.7, on 2026-11-02.

## Verification stages

Every stage printed PASS and the script exited 0.

| Stage | Result |
| --- | --- |
| dependency_resolution | PASS |
| formatting | PASS |
| static_analysis | PASS |
| rule_catalogue | PASS |
| rule_catalogue_fresh | PASS |
| unit_tests | PASS |
| rule_tests | PASS |
| integration_tests | PASS |
| regression_tests | PASS |
| cli_smoke_tests | PASS |
| module_fixture_tests | PASS |
| configuration_tests | PASS |
| baseline_suppression_tests | PASS |
| report_generation_tests | PASS |
| autofix_tests | PASS |
| secret_redaction_tests | PASS |
| monorepo_tests | PASS |
| license_check | PASS |
| publish_dry_run | PASS |
| coverage_report | PASS |
| git_hygiene | PASS |

## Suite totals

`dart test --coverage=coverage test integration_test` reported `+40: All tests passed!`

Failures: 0.

Line coverage of `lib/`: 85.11% (3583 of 4210). Gate: 80%.

`dart analyze --fatal-infos`: no issues.

`dart pub publish --dry-run`: 0 warnings. Exit 0.

## What the tests cover

- Core parsing, globs, redaction, fingerprints, Gradle, ARB, complexity, import cycles, outdated and OSV JSON parsers, and configuration rejection.
- Fixture scans for a clean app, a simple app, flavors, Clean Architecture, BLoC, Riverpod, a monorepo, security, localization, and feature coupling.
- CLI exit codes, doctor, init, baseline, suppression, auto-fix dry-run/apply/revert, symlink escape, and inline ignore without a reason.
- A regression test that a macOS temp root reached through `/var` is still scanned.
- Executable smoke tests for help, version, the clean fixture (exit 0), malformed config (exit 2), and the security fixture (exit 1, secret strings absent).
- Custom rules, empty platform directories, dependency signals, report history, and failing network clients.

## CLI fixture execution

Separate from the test runner, `dart run bin/flutterguard.dart` was run with `--offline` on each fixture. Source checksums did not change.

| Fixture | Exit | Findings |
| --- | --- | --- |
| clean_app | 0 | 0 |
| simple_flutter | 0 | 4 |
| multi_flavor | 0 | 4 |
| clean_architecture | 1 | 3 |
| bloc_app | 1 | 4 |
| riverpod_app | 0 | 1 (FG-QUAL-008, not an architecture rule) |
| malformed_config | 2 | scan refused |
| monorepo | 1 | 4 across alpha and beta |
| security_app | 1 | 18, including 1 critical |
| localization_app | 0 | 8 |
| feature_coupling | 0 | 2 |

## GitHub Actions

Run https://github.com/manjesh2024/flutterguard/actions/runs/41396678508 on `3482bf20a9beb3fa3b8f15eff439d1e58f054c32` succeeded:

- Verify (ubuntu-latest), including `./tool/verify_all.sh`
- Verify (macos-latest), including `./tool/verify_all.sh`
- Windows Dart tests: format, analyze, test
- Flutter stable SDK: analyze and test
- SARIF artifact from the security fixture

## Not executed

- A live query to `https://api.osv.dev` and a live `dart pub outdated` process. Parsers and injected clients were tested. Failures become status `unavailable` rather than invented advisories.
- `reports.openHtml` launching `open` or `xdg-open`.
- `dart pub publish` upload. Login was required and the upload was not completed.
