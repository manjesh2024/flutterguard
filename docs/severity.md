# Severity policy

FlutterGuard orders severities as `info < low < medium < high < critical`.

The default quality gate fails the process when any active finding is `high` or `critical`. Exit code `1` means the gate failed. Exit code `0` means the gate passed. Configuration and usage errors use exit code `2`. Unexpected failures use exit code `3`.

`severity.minReport` drops findings below that level before the gate. `severity.overrides` and `rules.<id>.severity` replace a rule's default for that project.

SARIF levels are `error` for high and critical, `warning` for medium, and `note` for info and low.

A baseline with `failOnNew: true` also fails the gate when a new finding is at a failing severity. Existing baselined findings stay visible and are labeled `existing`. They do not by themselves fail `failOnNew`.

No score is calculated. Reports contain counts and the severity of each finding. A future scoring model would need its own documented configuration and would not be implied by these counts.
