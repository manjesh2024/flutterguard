# Audit modules

Each module can be disabled in `.flutterguard.yaml`. Disabling a module disables its rules. Custom `contains` rules are registered with the configuration module, so they run only when that module is enabled.

## Branding

Reads Android Gradle application ids and `resValue` app names, Android manifests, iOS Info.plist display names and bundle ids, Xcode project bundle ids, asset catalogs, web manifests, and pubspec Flutter assets. Reports placeholder ids, missing or empty icons, flavor ids that collapse to the same value, and names that disagree across platforms.

## Configuration

Finds URL literals whose hosts are not on the allow list, duplicate application or bundle ids across discovered projects, release builds marked debuggable, release builds with minification disabled, and `minSdk` below 21. A missing environment example is an informational heuristic, not proof that configuration is absent.

## Architecture

Builds an import graph from the analyzer AST and reports cycles from that graph. Layer rule `FG-ARCH-001` runs only when the profile is `clean`, `featureFirst`, or `custom`. Profile `none` is the default and does not apply layer rules. Feature coupling looks at `lib/features/<name>/` and allows a feature's public barrel. Direct database access and heavy business logic in widget files are heuristics.

## Code quality

Uses AST facts for cyclomatic complexity, class and method size, empty catches, unawaited future-returning calls, and unused imports. Comments are scanned for `TODO`, `FIXME`, `HACK`, and `XXX`. `print` and `debugPrint` are flagged. Parse errors become `FG-QUAL-009`. An inline ignore without a reason becomes `FG-SUP-001`.

## Security

Pattern and AST heuristics for secret-shaped literals, credential assignments, logging of sensitive names, `http://` URLs, TLS callback assignments, `shared_preferences` writes of token-like keys, and a fixed set of high-risk Android permissions. Values are not copied into findings. A hit is not proof of a vulnerability. `FG-SEC-008` is the exception: an escaped symlink is a definite file-access decision.

## Localization

Parses ARB files as JSON and also scans the raw text for duplicate keys. Compares placeholders and plural or select cases across locales. `localization.requiredLocales` lists locales that must have a file. When no ARB files and no required locales exist, the module stays quiet. Hardcoded user-facing strings are a heuristic.

## Dependencies

Reads `pubspec.yaml` and `pubspec.lock`. The lockfile is included by the default file globs. Unused direct dependencies are estimated from import URIs, with a tooling allow list. Deprecated packages come from a small curated map. License metadata is read from the local pub cache when a lockfile entry exists and is not legal advice. Path and git production dependencies are reported. Outdated versions and OSV advisories run only when `network` enables them.

## Platforms

When `android/`, `ios/`, `web/`, `windows/`, `macos/`, or `linux/` exists, the module checks for the expected entry files of that platform. A platform directory that is absent is not a finding.
