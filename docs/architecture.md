# Architecture

FlutterGuard 0.1.0 is one publishable Dart package, `flutterguard_audit`. The executable name is `flutterguard`.

## Dependency direction

```text
bin/flutterguard.dart
  -> cli
    -> scan pipeline
      -> discovery, file index, project snapshot
      -> Dart AST index and structured parsers
      -> rule registry
      -> suppression, baseline, quality gate
      -> report writers
    -> auto-fix (only the fix command)
```

Rules do not import the CLI. Reporting does not import rules. Parsers do not decide severity. The registry is the only place that constructs built-in rules.

## Scan pipeline

1. Load configuration. Missing file means defaults. Invalid YAML, unknown keys, bad globs, and schema version mismatches throw `ConfigException` and exit `2`.
2. Discover Flutter projects. A project has a `pubspec.yaml` with a Flutter SDK dependency or a top-level `flutter:` section. Melos `packages` and Dart workspace members are included. Symlinks are not followed.
3. Index files that match include globs and miss exclude globs. Binary files keep their size and no text. A symlink whose target resolves outside the project becomes `FG-SEC-008` and is not read.
4. Parse Dart with `package:analyzer`. Gradle, XML, plist, ARB, and pubspec files use structured parsers.
5. Run enabled rules. Findings are sorted, fingerprinted, filtered by minimum severity, and compared with suppressions and the optional baseline.
6. Evaluate the quality gate and write the requested report formats.

The scan does not write source files and does not run the Flutter application's scripts.

## Models

Findings, configuration, and report documents are immutable. Rule IDs are stable strings such as `FG-ARCH-001`. Fingerprints are SHA-256 of rule, relative path, message, enclosing name, and a duplicate index. Line numbers are not part of the fingerprint.

Paths stored in reports are project-relative POSIX paths. `SafePath` rejects absolute report directories and any path that leaves the project lexically or after symlink resolution. On macOS a temp directory under `/var` resolves to `/private/var`; both forms are treated as the same root so real files are not mistaken for escapes.

## Schemas

- Configuration `version: 1`
- JSON report `schemaVersion: 1`
- Baseline `schemaVersion: 1`
- SARIF `2.1.0`

## What is not in the library

Company-specific rules stay out of this package. A project can add literal `contains` checks with ids that start with `FG-CUSTOM-`. Those checks are not regular expressions.
