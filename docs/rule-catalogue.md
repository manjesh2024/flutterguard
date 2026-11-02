# Rule catalogue

Stable IDs shipped with FlutterGuard 0.1.0. Heuristic rules are review signals, not proof of a defect or vulnerability.

## FG-BRAND-001

- Title: Android application ID
- Category: branding
- Default severity: medium
- Heuristic: false

Checks Android applicationId values for missing and template placeholders.

Recommendation: Set a unique applicationId in android/app/build.gradle for every shipped flavor.

## FG-BRAND-002

- Title: iOS bundle identifier
- Category: branding
- Default severity: medium
- Heuristic: false

Checks iOS bundle identifiers from Info.plist, xcconfig, and the Xcode project.

Recommendation: Set PRODUCT_BUNDLE_IDENTIFIER to the shipped bundle id, not a Flutter template value.

## FG-BRAND-003

- Title: Application name consistency
- Category: branding
- Default severity: medium
- Heuristic: false

Compares customer-facing display names. Flutter engine plists are ignored, Xcode variables such as PRODUCT_NAME are resolved, and flavor-specific names are not compared with the default name.

Recommendation: Use one customer-facing name. Flavor-specific names are allowed when they are declared on that flavor.

## FG-BRAND-004

- Title: Launcher icons
- Category: branding
- Default severity: medium
- Heuristic: false

Checks that existing platforms ship a launcher icon or favicon file.

Recommendation: Add the platform icon set. An empty or missing icon is not treated as a brand review.

## FG-BRAND-005

- Title: Flavor branding
- Category: branding
- Default severity: medium
- Heuristic: true

Checks that Android product flavors resolve to distinct ids and that iOS has a matching flavor file.

Recommendation: Give each flavor its own applicationId or suffix, and add an iOS xcconfig or scheme with the flavor name.

## FG-BRAND-006

- Title: Asset consistency
- Category: branding
- Default severity: medium
- Heuristic: false

Checks that flutter/assets entries in pubspec.yaml exist in the project.

Recommendation: Add the missing asset or remove the pubspec entry. Paths are resolved inside the project only.

## FG-CFG-001

- Title: Hardcoded endpoint
- Category: configuration
- Default severity: medium
- Heuristic: true

Reports URL string literals that are not on the configured allow list.

Recommendation: Move environment-specific hosts to String.fromEnvironment, a flavor file, or another ignored config source.

## FG-CFG-002

- Title: Production and staging mismatch
- Category: configuration
- Default severity: high
- Heuristic: true

Flags a file that mentions a release or production guard and also embeds a staging, sandbox, or local URL.

Recommendation: Select the host from the active flavor. This check is a heuristic, not proof of a bad release build.

## FG-CFG-003

- Title: Duplicate application identifiers
- Category: configuration
- Default severity: high
- Heuristic: false

Reports the same Android applicationId or iOS bundle identifier used by more than one app.

Recommendation: Give each installable app its own application id and bundle identifier.

## FG-CFG-004

- Title: Debug settings in release configuration
- Category: configuration
- Default severity: high
- Heuristic: false

Reports debuggable release Gradle types and debuggable Android manifests.

Recommendation: Set debuggable false for release builds and remove android:debuggable from the manifest.

## FG-CFG-005

- Title: Missing environment configuration
- Category: configuration
- Default severity: low
- Heuristic: true

Reports hardcoded URLs when the project shows no environment switch.

Recommendation: Introduce String.fromEnvironment, a dotenv loader, or flavor configuration before shipping hosts.

## FG-CFG-006

- Title: Build configuration
- Category: configuration
- Default severity: low
- Heuristic: false

Reports very old minSdk values and release builds with minify disabled.

Recommendation: Raise minSdk to a supported level and enable minify for release unless a documented shrinker exception exists.

## FG-ARCH-001

- Title: Layer dependency direction
- Category: architecture
- Default severity: high
- Heuristic: false

Enforces the selected architecture profile. Profile "none" does not invent a layer model.

Recommendation: Change the import or update architecture.layers so the dependency is an accepted policy.

## FG-ARCH-002

- Title: Circular imports
- Category: architecture
- Default severity: high
- Heuristic: false

Finds import cycles from the Dart AST. Cycles are reported once in a stable order.

Recommendation: Extract the shared type into a third library or invert the dependency.

## FG-ARCH-003

- Title: Business logic in a UI file
- Category: architecture
- Default severity: medium
- Heuristic: true

Heuristic for complex methods inside widget files or the configured presentation layer. It does not require BLoC, Riverpod, or Provider.

Recommendation: Move the decision logic next to the project's existing non-UI types. A high complexity score is not by itself a defect.

## FG-ARCH-004

- Title: Direct database access from UI
- Category: architecture
- Default severity: high
- Heuristic: true

Heuristic that flags widget or presentation files importing a database package or calling raw SQL helpers.

Recommendation: Keep database calls behind the project's data boundary. This is not proof that the call is unsafe.

## FG-ARCH-005

- Title: Feature coupling
- Category: architecture
- Default severity: medium
- Heuristic: false

Flags lib/features imports that cross feature folders, except the public barrel lib/features/<name>/<name>.dart.

Recommendation: Import another feature only through its public barrel, or move the shared type to lib/shared or lib/core.

## FG-QUAL-001

- Title: Excessive complexity
- Category: codeQuality
- Default severity: medium
- Heuristic: false

Reports methods whose cyclomatic complexity exceeds codeQuality.complexityThreshold.

Recommendation: Split the method or lower the decision count. The threshold is configurable.

## FG-QUAL-002

- Title: Large class
- Category: codeQuality
- Default severity: medium
- Heuristic: false

Reports classes longer than codeQuality.classLineThreshold.

Recommendation: Split the type or raise the configured threshold.

## FG-QUAL-003

- Title: Large method
- Category: codeQuality
- Default severity: medium
- Heuristic: false

Reports methods longer than codeQuality.methodLineThreshold.

Recommendation: Extract helpers or raise the configured threshold.

## FG-QUAL-004

- Title: TODO or FIXME comment
- Category: codeQuality
- Default severity: info
- Heuristic: false

Reports TODO, FIXME, HACK, and XXX comments.

Recommendation: Resolve the comment or suppress it with a reason.

## FG-QUAL-005

- Title: Debug print
- Category: codeQuality
- Default severity: low
- Heuristic: false

Reports print and debugPrint calls from the AST.

Recommendation: Remove the call or use a logger that is disabled in release builds.

## FG-QUAL-006

- Title: Empty catch
- Category: codeQuality
- Default severity: medium
- Heuristic: false

Reports catch clauses whose block has no statements.

Recommendation: Handle the error, rethrow it, or document the ignore.

## FG-QUAL-007

- Title: Suspicious asynchronous pattern
- Category: codeQuality
- Default severity: low
- Heuristic: true

Reports async bodies with no await, and unawaited calls to project functions declared to return Future.

Recommendation: Await the future, return it, or wrap it in unawaited. Declaration types are syntactic, not inferred.

## FG-QUAL-008

- Title: Unused import
- Category: codeQuality
- Default severity: low
- Heuristic: false

Reports unused imports from the Dart analyzer AST. Constructor names and extension methods count as references. Only prefix, show, and redundant dart:core imports are auto-fixable.

Recommendation: Remove the import when it is unused. Imports that may exist only for an extension are not auto-fixed.

## FG-QUAL-009

- Title: Dart parse error
- Category: codeQuality
- Default severity: low
- Heuristic: false

Reports syntax errors found while parsing Dart files.

Recommendation: Fix the syntax error so later rules can see a complete AST.

## FG-SUP-001

- Title: Suppression missing a reason
- Category: suppression
- Default severity: low
- Heuristic: false

Inline flutterguard:ignore comments must include a rule id and a reason.

Recommendation: Use `// flutterguard:ignore FG-QUAL-005 reason: why this is accepted`.

## FG-SEC-001

- Title: Hardcoded secret
- Category: security
- Default severity: high
- Heuristic: true

Pattern check for private keys, access-key ids, and assigned secret values. Values are redacted and the match is not proof of a live credential.

Recommendation: Remove the value from source and load it from the environment or the platform secret store.

## FG-SEC-002

- Title: Credential exposure
- Category: security
- Default severity: high
- Heuristic: true

Pattern check for client secrets, cloud secrets, and authorization assignments.

Recommendation: Rotate the credential if it was ever real, and keep the replacement outside the repository.

## FG-SEC-003

- Title: Sensitive logging
- Category: security
- Default severity: medium
- Heuristic: true

Flags print, debugPrint, and log calls whose arguments look sensitive.

Recommendation: Do not log secrets. The argument value is not included in the report.

## FG-SEC-004

- Title: Unsafe HTTP configuration
- Category: security
- Default severity: high
- Heuristic: true

Reports cleartext http URLs, Android cleartext traffic, and iOS arbitrary loads.

Recommendation: Use HTTPS. Local and documentation hosts in allowedHosts are ignored.

## FG-SEC-005

- Title: TLS bypass pattern
- Category: security
- Default severity: high
- Heuristic: true

AST check for badCertificateCallback and onBadCertificate. A callback is not by itself proof that certificates are ignored.

Recommendation: Remove blanket certificate acceptance. Pin or trust a specific certificate if a private CA is required.

## FG-SEC-006

- Title: Insecure storage pattern
- Category: security
- Default severity: high
- Heuristic: true

Flags SharedPreferences writes whose key looks like a token, password, or secret.

Recommendation: Prefer the platform secure storage API for credentials. The stored value is not copied into the report.

## FG-SEC-007

- Title: Platform permission risk
- Category: security
- Default severity: medium
- Heuristic: true

Lists high-impact Android permissions. Presence is not proof of misuse.

Recommendation: Drop permissions the app does not need and add a user-facing disclosure for the ones it keeps.

## FG-SEC-008

- Title: Symlink escapes the project
- Category: security
- Default severity: medium
- Heuristic: false

A symlink could not be proven to stay inside the project, so FlutterGuard did not read it.

Recommendation: Replace the symlink with a real file inside the project or remove it from the scan root.

## FG-L10N-001

- Title: Missing ARB key
- Category: localization
- Default severity: medium
- Heuristic: false

Compares message keys across ARB catalogs in the project.

Recommendation: Add the missing key to every locale catalog.

## FG-L10N-002

- Title: Placeholder mismatch
- Category: localization
- Default severity: medium
- Heuristic: false

Compares ICU placeholder names for the same key across locales.

Recommendation: Use the same placeholder names in every translation of the key.

## FG-L10N-003

- Title: Duplicate ARB key
- Category: localization
- Default severity: medium
- Heuristic: false

Reports repeated top-level keys in an ARB file.

Recommendation: Keep one entry per key. JSON parsers keep only one of the duplicates.

## FG-L10N-004

- Title: Missing locale file
- Category: localization
- Default severity: medium
- Heuristic: false

Checks l10n.yaml and localization.requiredLocales for missing catalogs.

Recommendation: Add the ARB file or remove the locale from the required list.

## FG-L10N-005

- Title: Plural and select consistency
- Category: localization
- Default severity: medium
- Heuristic: false

Compares plural/select kinds and cases for the same key across locales.

Recommendation: Give every locale the same plural or select cases, including other.

## FG-L10N-006

- Title: Hardcoded user-facing string
- Category: localization
- Default severity: low
- Heuristic: true

Heuristic for Text and common label arguments that contain a sentence-like literal. Tests, debug text, and short labels are skipped.

Recommendation: Move user-facing copy into an ARB catalog. Short labels, test strings, and debug text are not flagged.

## FG-DEP-001

- Title: Unused direct dependency
- Category: dependencies
- Default severity: low
- Heuristic: true

Reports a direct dependency that is never referenced in scanned project files. The check is a heuristic and does not edit pubspec.yaml. Codegen and lint packages in the built-in tooling list are skipped.

Recommendation: Confirm the package is unused, then remove it yourself. FlutterGuard does not remove dependencies. Fonts, code generation, and native code can use a package without a package: import.

## FG-DEP-002

- Title: Outdated dependency
- Category: dependencies
- Default severity: low
- Heuristic: true

Uses dart pub outdated only when network.outdatedChecks is enabled. Otherwise it records that the check was skipped.

Recommendation: Upgrade on a branch and run the test suite. A newer version is not automatically safe.

## FG-DEP-003

- Title: Deprecated package indicator
- Category: dependencies
- Default severity: medium
- Heuristic: true

Matches a small curated list of packages that have a maintained replacement. The list is not exhaustive.

Recommendation: Read the replacement package notes before migrating. This indicator is not a vulnerability.

## FG-DEP-004

- Title: License metadata
- Category: dependencies
- Default severity: low
- Heuristic: true

Reads LICENSE files already present in the local pub cache and recognizes SPDX identifiers and common headings. Unrecognized text is metadata, not a license violation. Flutter applications are not flagged for an empty pubspec license field.

Recommendation: Run dart pub get and review the license file. A missing cache entry or an unrecognized heading is not a license violation.

## FG-DEP-005

- Title: Dependency source
- Category: dependencies
- Default severity: medium
- Heuristic: false

Reports path and git dependencies in the production dependency section.

Recommendation: Prefer a hosted version constraint for released apps. Path and git sources are valid during development.

## FG-DEP-006

- Title: Vulnerability advisory
- Category: dependencies
- Default severity: high
- Heuristic: true

Queries the OSV API for locked package versions only when network.vulnerabilityChecks is enabled. No project source is uploaded.

Recommendation: Read the advisory and upgrade or apply the documented mitigation. An advisory id is not an exploit.

## FG-PLAT-001

- Title: Android project
- Category: platform
- Default severity: medium
- Heuristic: false

Checks an existing android/ directory for a manifest and exported components without intent filters. Debug, profile, and release overlays inherit the main application label.

Recommendation: Add the missing manifest entry on the main source set, or an intent filter before exporting a component.

## FG-PLAT-002

- Title: iOS project
- Category: platform
- Default severity: medium
- Heuristic: false

Checks an existing ios/ directory for Info.plist identity and empty privacy strings.

Recommendation: Set the bundle identifier and a non-empty usage description for every privacy key.

## FG-PLAT-003

- Title: Web project
- Category: platform
- Default severity: medium
- Heuristic: false

Checks an existing web/ directory for index.html and manifest.json.

Recommendation: Restore the Flutter web template files before building for web.

## FG-PLAT-004

- Title: Windows project
- Category: platform
- Default severity: medium
- Heuristic: false

Checks an existing windows/ directory for CMake and Runner.rc.

Recommendation: Restore the Flutter windows runner files.

## FG-PLAT-005

- Title: macOS project
- Category: platform
- Default severity: medium
- Heuristic: false

Checks an existing macos/ directory for the Xcode project and bundle identifier.

Recommendation: Restore the Flutter macOS runner and set PRODUCT_BUNDLE_IDENTIFIER.

## FG-PLAT-006

- Title: Linux project
- Category: platform
- Default severity: medium
- Heuristic: false

Checks an existing linux/ directory for CMake and my_application.cc.

Recommendation: Restore the Flutter Linux runner files.

