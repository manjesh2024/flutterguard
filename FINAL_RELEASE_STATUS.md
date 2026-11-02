# FlutterGuard release status

Date: 2026-11-02

## Repository

| Field | Value |
| --- | --- |
| Location | `/Volumes/Manjesh256/flutterguard` |
| Remote | https://github.com/manjesh2024/flutterguard.git |
| Visibility | public |
| Branch | main |
| Product commit | `3482bf20a9beb3fa3b8f15eff439d1e58f054c32` |
| Working tree at that commit | clean, tracking `origin/main` |
| Actions | success, run 41396678508 |

`git ls-remote origin refs/heads/main` returned that same SHA before these release notes were added. These notes are a follow-up commit.

## Package

| Field | Value |
| --- | --- |
| pub.dev name | flutterguard_audit |
| Version | 0.1.0 |
| Executable | flutterguard |
| License | MIT |
| SDK | Dart `^3.13.0` |
| Dry-run | passed, 0 warnings |
| Upload | BLOCKED |

`https://pub.dev/api/packages/flutterguard_audit` returned HTTP 404. The name was unused. `flutterguard_cli` is a different existing package and was not used.

`dart pub token list` reported no tokens. No pub credentials file was present. `dart pub publish` validated the package and stopped at the confirmation prompt. `dart pub publish --force` still required a browser login at `accounts.google.com` and waited on localhost. That wait was cancelled. Nothing was uploaded.

To publish after logging in:

```bash
dart pub login
dart pub publish
```

## Name and license decisions

The executable stays `flutterguard`. The package name is `flutterguard_audit` so it does not collide with the unrelated `flutterguard_cli` package. MIT is the license. Direct dependencies resolved as MIT, BSD, or Apache from the local pub cache. `tool/check_licenses.dart` found no GPL classification.

## Release hygiene

The product commit does not contain generated `build/` reports, coverage output, or a local baseline. Secret-shaped strings and machine paths are rejected in package source by `tool/verify_all.sh`. The security fixture keeps the public AWS documentation example key so redaction tests have a known input. These three final files record the checkout path and are listed in `.pubignore`.

## Matrix

| Gate | Status |
| --- | --- |
| Implementation and local tests | PASS |
| macOS `./tool/verify_all.sh` | PASS |
| GitHub Actions Ubuntu, macOS, Windows, Flutter | PASS |
| Public GitHub push | PASS |
| pub.dev dry-run | PASS |
| pub.dev upload and public install | BLOCKED |
| Live vulnerability network call | PARTIAL |
| OS HTML opener | PARTIAL |
| Project score | NOT IMPLEMENTED |
