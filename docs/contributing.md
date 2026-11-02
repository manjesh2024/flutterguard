# Contributing

## Development

```bash
dart pub get
dart format .
dart analyze --fatal-infos
dart test test integration_test
./tool/verify_all.sh
```

Use the fixtures under `test/fixtures/` for rule behavior. Add a regression test when a bug is fixed. Do not delete a failing test to make the suite pass.

## Rule changes

Add the rule in the matching file under `lib/src/rules/` and register it in `lib/src/rules/registry.dart`. Keep the id stable. Document it by running:

```bash
dart run tool/generate_rule_catalogue.dart
```

Commit the updated `docs/rule-catalogue.md`. Heuristic rules must say they are heuristics in the description.

## Design constraints

- Do not execute code from the scanned project.
- Do not put secret values in findings or logs.
- Do not add a project score without a documented model.
- Do not auto-fix security configuration.
- Keep company-specific rules out of this repository.

## Commits

Explain why the change exists. Do not commit `build/`, `coverage/`, `.flutterguard/`, or a baseline produced by a local scan.
