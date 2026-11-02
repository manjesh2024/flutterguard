# FlutterGuard post-publication report

Verified on 2026-11-02. Commands were run outside the FlutterGuard source checkout when the check was an installation or a scan of another project.

## Published package verification

| Check | Result |
| --- | --- |
| Package page | https://pub.dev/packages/flutterguard_audit returned HTTP 200 |
| Version page | https://pub.dev/packages/flutterguard_audit/versions/0.1.0 returned HTTP 200 |
| Package API | `flutterguard_audit` latest was `0.1.0` when verification started. `0.1.1` is now also listed |
| Published at | `0.1.0` at 2026-11-02T06:16:32Z. `0.1.1` at 2026-11-02T06:30:03Z |
| Description | Audit Flutter projects for branding, configuration, architecture, code quality, security, localization, dependencies, and platform setup |
| Homepage and repository | https://github.com/manjesh2024/flutterguard |
| Executable mapping | `flutterguard` -> `flutterguard` |
| SDK constraint | `^3.13.0` |
| Archive | https://pub.dev/api/archives/flutterguard_audit-0.1.0.tar.gz |

Status: **PASS** for public availability of 0.1.0. **PASS** for the 0.1.1 documentation upload after the API listed it.

## Installed version

`dart pub global activate flutterguard_audit` from `/tmp` installed 0.1.0 first. The shim is `$HOME/.pub-cache/bin/flutterguard`. After 0.1.1 became visible to the pub client, `dart pub global activate flutterguard_audit 0.1.1` from `/tmp` succeeded.

`flutterguard --version` with only the pub-cache bin directory added to `PATH`, and with the working directory `/tmp`, printed `flutterguard 0.1.1`.

The clean-project scan below was executed while the active global package was still 0.1.0. Its report header says `Package flutterguard_audit 0.1.0`.

## Global executable and PATH

Pub printed this warning on activate:

`Pub installs executables into $HOME/.pub-cache/bin, which is not on your path.`

A clean environment whose `PATH` is `/usr/bin:/bin` plus the Flutter SDK did not find `flutterguard`. The same environment with `$HOME/.pub-cache/bin` appended ran `flutterguard 0.1.1`.

Status: **PASS** for the installed executable. **FAIL** for the default login `PATH`. The README for 0.1.1 now tells the user to add that directory.

## Clean-project smoke test

Created `/tmp/fg-smoke-35D9/smoke_app` with `flutter create`. The scan used `/Users/strong/.pub-cache/bin/flutterguard`, not `dart run` from the FlutterGuard checkout.

| Check | Result |
| --- | --- |
| Discovery | Project `smoke_app` at `.` |
| Configuration | No `.flutterguard.yaml`. Defaults enabled every module |
| Toolchain | Dart 3.13.5, Flutter 3.47.7 |
| Findings | 8 (0 critical, 0 high, 3 medium, 4 low, 1 info) |
| Categories with findings | branding, code quality, dependencies, localization, platform |
| Architecture, configuration, security | Ran under the defaults and produced no findings on this template |
| Exit code | 0, quality gate passed |
| HTML | `build/flutterguard/index.html` |
| JSON | `report.json`, schema 1, package version 0.1.0, no project score |
| Markdown | `report.md` names FlutterGuard and `smoke_app` |
| SARIF | `report.sarif`, version 2.1.0, one run |
| Source checksum | `a180ea3702fbcff8118c505bbcbf574def97089288cd98f5761e09b2ec8f6023` before and after, excluding `.dart_tool` and `build` |

Status: **PASS**.

## HTML report verification

`open` launched the HTML report on macOS. The same file was then served on `http://127.0.0.1:8765/index.html` and read in a browser.

The page title is FlutterGuard report. It shows package `flutterguard_audit` 0.1.0, schema 1, project `smoke_app`, platforms android, ios, linux, macos, web, and windows, the scan timestamp, Dart 3.13.5, Flutter 3.47.7, 8 findings, severity counts, category counts, rule ids, file paths, recommendations, baseline state, suppression count 0, quality gate Passed, and network checks disabled. It states that no project score is calculated.

Status: **PASS**.

## Vyavsetu dogfooding

Command, from `/Volumes/Manjesh256/vyavsetu-platform`, using the global 0.1.0 binary:

`flutterguard --offline`

Exit code 1. The quality gate failed. No source files were changed. `git status --porcelain` matched the pre-scan list after the generated `build/flutterguard/` directory was removed. That directory was gitignored. The repository already had unrelated local modifications; those lines were present before the scan and were not edited.

Discovered projects: `vyavsetu_business_admin`, `vyavsetu_customer`, `vyavsetu_driver`, `vyavsetu_pos`, `vyavsetu_super_admin`, `auth`, `core`, `database`, `design_system`, `network`, `offline_sync`, `shared_models`.

467 findings: 0 critical, 12 high, 149 medium, 250 low, 56 info. 249 were marked heuristic.

### Confirmed issues

- `FG-SEC-004` on `apps/pos/android/app/src/main/AndroidManifest.xml`: the manifest sets `android:usesCleartextTraffic="true"`.
- `FG-SEC-004` on test files that contain real `http://` URLs, including `gateway.sandbox.net`, `192.168.1.100`, and `api.vyavsetu.com`.
- `FG-CFG-001` for production and staging API hosts hardcoded in app entry files and `packages/core/lib/src/config/app_config.dart`. These are real URL literals. Whether they are acceptable configuration is a product decision.
- `FG-ARCH-003` and `FG-ARCH-005` in the POS app: high cyclomatic complexity in UI methods and cross-feature imports. These match the structural checks. They are review items, not automatically defects.
- `FG-QUAL-005` debug prints and large-method findings are direct source matches.

### False positives

- `FG-CFG-003` high: `io.flutter.flutter.app` is the Flutter engine id in each app's `ios/Flutter/AppFrameworkInfo.plist`, not the application id. The five apps do not share one customer bundle id. The real Android application id checked for business admin is `com.vyavsetu.businessadmin.vyavsetu_business_admin`.
- `FG-SEC-004` messages that say `Cleartext HTTP URL for host .` have an empty host. Those hits are parser noise.
- `FG-BRAND-003` treats Flutter template strings `App` from `AppFrameworkInfo.plist` and `$(PRODUCT_NAME)` as customer-facing names.
- `FG-PLAT-001` on debug and profile manifests that omit an application label. That is the Flutter template, also seen on the clean `smoke_app`.

### Heuristic warnings

- Four `FG-SEC-001` hits are in `packages/auth/test/auth_test.dart` and `packages/network/test/network_test.dart`. The report redacted the values and labeled them heuristics. They were not treated as confirmed secrets.
- `FG-L10N-006` hardcoded `Text` strings: 53 hits.
- `FG-QUAL-007` suspicious async patterns: 76 hits.
- `FG-QUAL-008` unused-import heuristics: 54 hits.
- `FG-DEP-001` unused direct dependencies: 31 hits. `apps/business_admin` has no `package:auth/` import, so that particular warning matches the scanned files. Path-package imports elsewhere may still be missed.
- `FG-DEP-004` license metadata: 70 hits, including local path packages that are not in the pub cache.

### Configuration and unsupported patterns

- `FG-DEP-005`: 38 path or git production dependencies. That is normal for this monorepo and is not a release defect.
- `FG-CFG-005`: hardcoded URLs without `String.fromEnvironment`, `flutter_dotenv`, or an `.env` inside the app directory. The monorepo root has an `.env` file. FlutterGuard indexes each Flutter package separately, so the root env file is outside those packages.
- Default discovery found the five apps and the Flutter packages. It did not require a Melos file. The root has no `pubspec.yaml`.
- No automatic fixes were applied.

Status: **PASS** for a read-only scan. The gate failure is the tool's result, not a scan crash.

## GitHub release

| Release | URL | Commit |
| --- | --- | --- |
| FlutterGuard 0.1.0 | https://github.com/manjesh2024/flutterguard/releases/tag/v0.1.0 | `7b21627d2ceb77d37050e96b1d743a91505de6f5` |
| FlutterGuard 0.1.1 | https://github.com/manjesh2024/flutterguard/releases/tag/v0.1.1 | `f829bf595e331985a3abec6c04a3d74eb97f6e25` |

No tag or release existed before this session. `v0.1.0` points at the commit that was `main` when 0.1.0 was published. It was not moved. `v0.1.1` points at the documentation patch that was uploaded to pub.dev.

## Documentation fixes

README installation now says the package is published, links to https://pub.dev/packages/flutterguard_audit, states Dart `^3.13.0`, and tells the user to add `$HOME/.pub-cache/bin` to `PATH`. The one-command workflow, configuration link, report paths, and limitations were already present and were left in place.

`CHANGELOG.md`, `pubspec.yaml`, and `lib/src/core/version.dart` are 0.1.1. The executable smoke test expects `0.1.1`.

`./tool/verify_all.sh` passed on commit `f829bf595e331985a3abec6c04a3d74eb97f6e25` before publication. `dart pub publish` uploaded 0.1.1. The server said the version can take up to 10 minutes to appear. The package API listed it on the first poll.

## Remaining issues

- `$HOME/.pub-cache/bin` is still absent from the default shell `PATH`.
- The first `dart pub global activate flutterguard_audit 0.1.1` failed because the pub client's copy of the version index was still 0.1.0. A later fetch returned 0.1.1 and activation succeeded.
- Vyavsetu's `io.flutter.flutter.app` duplicate-id finding and empty-host cleartext findings are false positives in 0.1.1. They were not changed in this patch.
- GitHub Actions for `f829bf5` completed successfully: https://github.com/manjesh2024/flutterguard/actions/runs/41400399326. The `v0.1.0` and `v0.1.1` release workflows also completed successfully.

## Pass or fail

| Item | Status |
| --- | --- |
| pub.dev 0.1.0 public metadata and executable mapping | PASS |
| Global install of 0.1.0 and clean-project scan | PASS |
| Global install of 0.1.1 from outside the source checkout | PASS |
| Default PATH contains `flutterguard` | FAIL |
| Clean-project reports and unchanged source | PASS |
| HTML report opened and inspected | PASS |
| Vyavsetu read-only dogfood | PASS |
| GitHub Release FlutterGuard 0.1.0 | PASS |
| Documentation patch 0.1.1 published | PASS |
| `./tool/verify_all.sh` on the 0.1.1 commit | PASS |
| GitHub Actions on `f829bf5` | PASS |
