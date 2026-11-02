# FlutterGuard final report

Verified on 2026-11-02 from the project checkout. Claims below were executed in this session.

## A. Project location

`/Volumes/Manjesh256/flutterguard`

The volume was writable. The directory did not already contain a FlutterGuard repository. Git was initialized only inside this directory, on branch `main`.

## B. Repository structure

Single publishable Dart package `flutterguard_audit` with executable `flutterguard`.

- `bin/flutterguard.dart`
- `lib/src/core`, `cli`, `discovery`, `context`, `analyzer`, `rules` (branding, configuration, architecture, code_quality, security, localization, dependencies, platform, custom), `reporting`, `baseline`, `suppression`, `auto_fix`, `quality_gate`, `network`, `toolchain`
- `test/`, `test/fixtures/`, `test/regression/`, `integration_test/`
- `example/`, `docs/`, `doc/`, `tool/`, `.github/workflows/`
- `README.md`, `CHANGELOG.md`, `LICENSE`, `analysis_options.yaml`, `pubspec.yaml`, `pubspec.lock`

`docs/` is the repository guide. `doc/README.md` is the pub.dev layout entry. `.pubignore` omits `docs/`, `test/fixtures/`, and these final reports from the package archive.

## C. Features implemented

`flutterguard` discovers a Flutter project or monorepo, loads `.flutterguard.yaml` when present, uses defaults when it is absent, runs enabled modules, writes reports, evaluates the quality gate, prints a summary, and returns an exit code. Optional commands: `init`, `rules list`, `rules explain`, `baseline create`, `baseline update`, `fix --dry-run`, `fix`, `fix --revert`, `doctor`.

Exit codes: 0 gate passed, 1 gate failed, 2 usage or configuration, 3 unexpected failure.

Malformed configuration fails closed. A missing configuration file does not block a scan. No numeric project score is calculated.

## D. Audit rules implemented and tested

53 built-in rules. The catalogue test checks that every id and title appears in `docs/rule-catalogue.md`.

- Branding: FG-BRAND-001 through FG-BRAND-006
- Configuration: FG-CFG-001 through FG-CFG-006
- Architecture: FG-ARCH-001 through FG-ARCH-005
- Code quality: FG-QUAL-001 through FG-QUAL-009, plus FG-SUP-001
- Security: FG-SEC-001 through FG-SEC-008
- Localization: FG-L10N-001 through FG-L10N-006
- Dependencies: FG-DEP-001 through FG-DEP-006
- Platforms: FG-PLAT-001 through FG-PLAT-006

Architecture import direction and cycles come from the Dart analyzer AST. Profile `none` is the default and does not apply layer rules. Security matches are heuristics except the escaped-symlink rule. Secret values are not copied into findings.

## E. Commands verified

`dart run bin/flutterguard.dart` was executed for `--help`, `--version`, and the fixture scans in section L. Package tests also drive `FlutterGuardCli` for init, rules list, rules explain, baseline create, fix dry-run, fix apply, fix revert, and doctor.

## F. Dependency versions

Dart SDK constraint `^3.13.0`. Locked direct dependencies:

- analyzer 14.7.0
- args 2.7.0
- crypto 3.0.8
- path 1.9.1
- xml 7.1.0
- yaml 3.1.4
- coverage 1.16.0 (dev)
- lints 6.1.0 (dev)
- test 1.33.0 (dev)

Local toolchain: Dart 3.13.5, Flutter 3.47.7 stable.

## G. Tests executed

`./tool/verify_all.sh` completed with every stage PASS. That script runs dependency resolution, formatting, `dart analyze --fatal-infos`, catalogue freshness, unit tests, rule tests, integration tests, regression tests, CLI smoke tests, module fixture tests, configuration tests, baseline and suppression tests, report tests, auto-fix tests, redaction tests, monorepo tests, license classification, `dart pub publish --dry-run`, coverage, and git hygiene.

The coverage invocation is the full suite: `dart test --coverage=coverage test integration_test`.

## H. Total test count and failures

40 tests, 0 failures, in the coverage run recorded in `build/verify/coverage_report.log`. The same suite is repeated by the named stages. Those stages passed.

## I. Coverage

Line coverage of `lib/`: 85.11% (3583/4210). The release gate in `tool/verify_all.sh` is 80%.

## J. Static analysis

`dart analyze --fatal-infos` reported no issues, locally and in GitHub Actions.

## K. Platform verification

- Local: macOS arm64, `./tool/verify_all.sh` passed.
- GitHub Actions run 41396678508 on commit `3482bf20a9beb3fa3b8f15eff439d1e58f054c32` succeeded for Ubuntu verify, macOS verify, Windows Dart tests, Flutter stable SDK tests, and the SARIF artifact job.
- Windows does not run `verify_all.sh`. It runs format, analyze, and `dart test`.

## L. CLI smoke results

`dart run bin/flutterguard.dart <fixture> --offline`:

| Fixture | Exit | Result |
| --- | --- | --- |
| clean_app | 0 | 0 findings, gate passed |
| simple_flutter | 0 | 4 findings (1 medium, 2 low, 1 info), gate passed |
| multi_flavor | 0 | 4 medium findings, gate passed |
| clean_architecture | 1 | 3 findings (2 high, 1 medium), gate failed |
| bloc_app | 1 | 4 findings (1 high, 3 low), gate failed |
| riverpod_app | 0 | 1 low unused-import finding, no architecture finding, gate passed |
| malformed_config | 2 | configuration error, no scan summary |
| monorepo | 1 | projects alpha and beta, 4 findings (1 high), gate failed |
| security_app | 1 | 18 findings (1 critical, 9 high), gate failed |
| localization_app | 0 | 8 findings (7 medium, 1 low), gate passed |
| feature_coupling | 0 | 2 findings (1 medium, 1 low), gate passed |

Checksums of `test/fixtures/security_app/lib/secrets.dart` and `test/fixtures/clean_app/lib/main.dart` were identical before and after the scans.

## M. Report generation

The clean fixture scan wrote `build/flutterguard/index.html`, `report.json`, `report.md`, and `report.sarif`. Tests also assert HTML sections, JSON, Markdown, and SARIF rendering, plus history output when configured.

## N. Security and privacy

The security fixture stdout and stderr did not contain `AKIAIOSFODNN7EXAMPLE`, `supersecretvalue123`, or `clientsecretvalue123`. Scans do not execute the Flutter application's scripts and do not upload source. Optional network checks are off by default. The public example access-key string in the security fixture is the AWS documentation example used as a test fixture, not a live credential.

## O. GitHub repository

https://github.com/manjesh2024/flutterguard

Public. Owner `manjesh2024`. The repository did not exist before this session.

## P. Branch and commit

Branch `main`. Product commit `3482bf20a9beb3fa3b8f15eff439d1e58f054c32`. Remote `origin` is `https://github.com/manjesh2024/flutterguard.git`. `git ls-remote` matched that SHA. These release records are a later commit on the same branch.

## Q. GitHub Actions

https://github.com/manjesh2024/flutterguard/actions/runs/41396678508 on the product commit succeeded for Ubuntu verify, macOS verify, Windows Dart tests, Flutter stable SDK tests, and the SARIF artifact job. GitHub printed a Node.js 20 deprecation annotation for `actions/checkout@v4`. The run still succeeded.

https://github.com/manjesh2024/flutterguard/actions/runs/41397135903 on the release-notes commit failed. The executable smoke test exceeded the 30 second default while scanning three fixtures through `dart run`. Windows passed. The test timeout is now 3 minutes. The expected exit codes and secret checks are unchanged.

## R. pub.dev package

Not published. `https://pub.dev/api/packages/flutterguard_audit` returned HTTP 404 after the publish attempt. `dart pub publish --dry-run` completed with 0 warnings. The real publish reached validation and then required Google OAuth. No pub token or `pub-credentials.json` was present. `dart pub publish --force` started `dart pub login` and waited for a browser approval on localhost. That process was stopped. The package was not uploaded.

## S. Installation verification

Verified from the checkout: `dart run bin/flutterguard.dart --version` prints `flutterguard 0.1.0`. Installation from pub.dev was not verified because the package is not published.

## T. Known limitations

- Heuristic rules are review signals, not proof of a vulnerability or defect.
- No project score.
- Auto-fix only removes selected single-line unused imports, after writing a backup.
- Live `dart pub outdated` and the OSV HTTP client are implemented and covered through injected clients and parsers. This session did not call the public OSV API or `dart pub outdated`.
- `reports.openHtml` was not launched against a desktop opener in this session.
- Default architecture profile is `none`.
- Support is Dart 3.13 because analyzer 14 requires it.
- `docs/` is omitted from the pub archive so the package uses the singular `doc/` directory. Fixture apps are omitted so pub does not treat their Flutter imports as dependencies of this package.

## U. Remaining external blocker

pub.dev publication is blocked on interactive login. From this project directory, after a browser session is available:

```bash
dart pub login
dart pub publish
```

Do not pass `--skip-validation`. `--force` only skips the yes/no prompt; it still validates, and it still requires the login above.

## Completion matrix

| Item | Status |
| --- | --- |
| Single-command scan, eight modules, reports, gate | PASS |
| AST architecture analysis and configurable profiles | PASS |
| Baseline, suppression, deterministic auto-fix | PASS |
| Secret redaction and read-only scans | PASS |
| `./tool/verify_all.sh` on macOS | PASS |
| GitHub Actions on the product commit | PASS |
| GitHub Actions on the notes commit | FAIL, smoke-test timeout, fixed in the following commit |
| Public GitHub repository | PASS |
| `dart pub publish --dry-run` with 0 warnings | PASS |
| Public pub.dev package | BLOCKED |
| Install from pub.dev in a clean project | BLOCKED |
| Live OSV and `dart pub outdated` calls | PARTIAL |
| Opening the HTML report with the OS viewer | PARTIAL |
| Numeric project score | NOT IMPLEMENTED |
