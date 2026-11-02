# Baseline and suppression

## Fingerprints

Each finding has a SHA-256 fingerprint of its rule id, relative path, message, enclosing declaration, and a duplicate index. The line number is excluded so a finding that moves a few lines keeps the same fingerprint.

## Baseline

```bash
flutterguard baseline create
flutterguard baseline update
```

`create` refuses to replace an existing baseline unless `--force` is set. `update` overwrites the baseline file. Both commands scan without modifying source. The default path is `.flutterguard-baseline.json` and the schema version is `1`.

Enable comparison in config:

```yaml
baseline:
  enabled: true
  path: .flutterguard-baseline.json
  failOnNew: true
```

The report then labels findings `new`, `existing`, or `resolved`. Resolved fingerprints are listed even though the finding is no longer active.

Add `.flutterguard-baseline.json` to version control when the team wants a shared baseline. It is gitignored by the FlutterGuard package itself so this repository does not publish a baseline.

## Suppression

A YAML suppression needs a reason and either a rule id or a fingerprint. `path` is an optional glob.

```yaml
suppressions:
  - rule: FG-QUAL-004
    path: "lib/generated/**"
    reason: Generated license headers.
```

Inline comments are described in [configuration.md](configuration.md). Suppression metadata is included in the HTML and JSON reports.
