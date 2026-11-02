# FlutterGuard 0.2.1 example implementation

Verified on 2026-11-02. Published package `flutterguard_audit` 0.2.0 was not modified. This release is 0.2.1.

## Examples

| Directory | What it is |
| --- | --- |
| `example/basic_flutter_app` | Runnable Flutter application: `lib/main.dart`, a notes feature, a widget test, Android, iOS, and web metadata. |
| `example/advanced_monorepo` | Pub workspace and Melos package list with `shop_app`, `admin_app`, and `shared_ui`. The root is not a Flutter project. |
| `example/intentional_findings` | Flutter project with deliberate findings. Values in `lib/demo_secrets.dart` are fake. |
| `example/library_api` | Dart program that calls the existing public scan API. |
| `example/flutterguard.yaml` | Canonical configuration. Copy it to an application root as `.flutterguard.yaml`. |

Each app also has `flutterguard.yaml` with the same bytes as `.flutterguard.yaml`. pub.dev omits names that start with a dot, so the documented scans pass `--config`.

## Commands that passed

`./tool/verify_all.sh` passed on the 0.2.1 tree, including:

- `flutter pub get`, `flutter analyze`, and `flutter test` in `example/basic_flutter_app`
- `dart run bin/flutterguard.dart example/basic_flutter_app --offline --config example/basic_flutter_app/flutterguard.yaml` (exit 0, no findings)
- the intentional sample with `--config` (exit 1, gate failed, source unchanged)
- the monorepo with `--config` (exit 0, three projects)
- `dart run bin/flutterguard.dart --version`, `--help`, `doctor`, `rules list`, and `rules explain FG-SEC-001`
- `fix --dry-run` on the intentional sample, without editing source
- `init` into a temporary directory
- `dart analyze --fatal-infos` and `dart run bin/main.dart` in `example/library_api`

Line coverage of `lib/` was 86.67% (3870/4465). The required minimum is 80%.

`dart pub publish --dry-run` reported 0 warnings. The compressed archive was 133 KB.

## Intentional findings

The sample scan reported these rules. `FG-QUAL-004` was suppressed and was not an active finding.

| Rule | Severity |
| --- | --- |
| FG-ARCH-001 | high |
| FG-BRAND-001 | medium |
| FG-BRAND-002 | medium |
| FG-BRAND-003 | medium |
| FG-BRAND-004 | medium, twice: missing Android launcher icon and missing iOS app icon set |
| FG-CFG-001 | medium |
| FG-CFG-004 | high, twice: Gradle release block and manifest `debuggable` |
| FG-CFG-005 | low |
| FG-CFG-006 | low for minify off, medium for `minSdk` 16 |
| FG-DEP-001 | low, heuristic, dependency not removed |
| FG-L10N-001 | medium |
| FG-L10N-002 | medium |
| FG-L10N-006 | low |
| FG-PLAT-001 | medium |
| FG-PLAT-002 | medium |
| FG-QUAL-005 | low |
| FG-QUAL-006 | medium |
| FG-QUAL-008 | low |
| FG-SEC-001 | high, twice: the fake password and the `secret` in `client_secret` |
| FG-SEC-002 | high |
| FG-SEC-004 | high, twice: cleartext traffic and the `http` URL |
| FG-SEC-007 | medium |

The monorepo scan reported two medium `FG-DEP-005` path-dependency findings for `shared_ui`. The gate passed. `apps/shop/lib/generated/skipped.dart` was excluded.

## Package contents

The dry-run archive includes `example/README.md`, the four example trees, their Dart sources, the basic app widget test, the intentional `FINDINGS.md`, and each visible `flutterguard.yaml`.

It does not include `test/fixtures/`, `docs/`, `doc/api/`, `build/`, `.dart_tool/`, `.github/`, this report, `local.properties`, `Generated.xcconfig`, `flutter_export_environment.sh`, `ephemeral/`, or `pubspec.lock`. Hidden `.flutterguard.yaml` files stay in Git and are not in the archive.

## Limitations

- The basic app is a small runnable demo. It is not a store listing and it is not a complete `flutter create` platform tree.
- The intentional sample is for the scanner. Its quality gate is supposed to fail.
- Security, license, unused-dependency, and hardcoded-string results are heuristics.
- `const Text('...')` is what the hardcoded-string check sees. A non-const `Text(...)` call is not collected.
- pub.dev omits dotfiles and lockfiles. Use the visible `flutterguard.yaml` with `--config` from the published package.
- No pub.dev score is claimed for 0.2.1.
- The release workflow publishes a tag `vX.Y.Z` through GitHub environment `pub.dev`. A pre-release tag does not match that pattern. Automated publishing is not claimed until that workflow uploads 0.2.1.
