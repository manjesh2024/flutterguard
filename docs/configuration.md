# Configuration reference

File: `.flutterguard.yaml`. Schema version: `1`.

`flutterguard init` writes the template. If the file is missing, FlutterGuard uses the same defaults and scans. If the file is present, unknown keys, the wrong version, and invalid types fail the command with exit code `2`.

## Top-level keys

| Key | Purpose |
| --- | --- |
| `version` | Must be integer `1`. |
| `discovery` | `mode` (`auto`, `single`, `monorepo`), `roots`, `maxDepth`. |
| `include` / `exclude` | Globs using only `*`, `?`, and `**`. `..` is refused. |
| `modules` | Booleans for the eight module names. |
| `architecture` | `profile`, optional `layers`, `featureCoupling`, `businessLogicComplexity`. |
| `codeQuality` | Complexity and size thresholds. |
| `allowedHosts` | Hosts ignored by the hardcoded-endpoint rule. |
| `severity` | `minReport` and per-rule `overrides`. |
| `suppressions` | List of `{rule or fingerprint, reason, optional path}`. |
| `baseline` | `enabled`, `path`, `failOnNew`. |
| `reports` | `directory`, `formats`, `history`, `openHtml`. |
| `qualityGate` | `failOn`, optional `maxFindings`, optional `maxNewFindings`. |
| `network` | `outdatedChecks`, `vulnerabilityChecks`. Both default to false. |
| `localization` | `requiredLocales`. |
| `customRules` | Literal contains rules. See [custom rules](custom-rules.md). |
| `rules` | Per-rule `enabled` and `severity`. |

`reports.directory` and `baseline.path` must stay inside the project. Absolute paths are refused.

## Architecture profiles

- `none`: no layer rules. Feature coupling still runs when `featureCoupling` is true.
- `clean`: presentation, application, domain, and data layers.
- `featureFirst`: shared, feature public barrels, and feature internals.
- `custom`: requires `architecture.layers`. Each layer has `name`, `paths`, and `mayImport`.

## Severity names

`info`, `low`, `medium`, `high`, `critical`.

## Inline suppression

```dart
// flutterguard:ignore FG-QUAL-005 reason: debug session
print('starting');
```

The comment may be on the finding line or the previous line. A missing reason does not suppress the finding and adds `FG-SUP-001`.

## Example

See [example/.flutterguard.yaml](../example/.flutterguard.yaml).
