# Report formats

Every full scan writes the enabled formats under `build/flutterguard/` by default:

- `index.html`
- `report.json` (`schemaVersion` 1)
- `report.md`
- `report.sarif` (SARIF 2.1.0)

`reports.history: true` also copies them into a timestamped directory. `reports.openHtml: true` tries to open the HTML file with the platform opener after the scan. The default is false.

## HTML contents

The HTML report includes project metadata, the scan timestamp, Dart and Flutter versions, finding counts, category summaries, severity distribution, rule ids, relative paths, line and column, the finding message, the remediation text, baseline status (`new`, `existing`, `resolved`), and suppression details.

## JSON

`report.json` is the versioned machine-readable document. `scoring` states that no score is calculated.

## Redaction

Every rendered document passes through the secret redactor. Private-key blocks, AWS-style access key ids, Google API key shapes, Slack tokens, GitHub tokens, and assigned secret-like values are replaced. Findings for those rules never include the matched value.

## Privacy

Reports are local files. FlutterGuard does not upload the scanned tree. Optional vulnerability checks send a package name and version to the OSV API and nothing else.
