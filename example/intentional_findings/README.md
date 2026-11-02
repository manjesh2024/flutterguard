# Intentional findings

This Flutter project is a controlled sample. The findings are deliberate, and `lib/demo_secrets.dart` uses fake values only.

Read [FINDINGS.md](FINDINGS.md) for each rule id, severity, and reason.

From the repository root:

```bash
dart run bin/flutterguard.dart example/intentional_findings --offline
```

Exit code 1 is expected. The scan finished and the quality gate failed. Source files are not modified.

Preview the unused import without writing:

```bash
dart run bin/flutterguard.dart fix --dry-run --path example/intentional_findings
```
