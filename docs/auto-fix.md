# Auto-fix safety

The scan command is read-only. Only `flutterguard fix` can change source, and only for findings whose fix id is `remove-unused-import`.

Eligible imports are a single line that is one of:

- a prefixed import (`import '...' as name;`)
- a show import (`import '...' show Name;`)
- a redundant `dart:core` import

A bare import that might carry an extension is reported and not edited.

## Commands

```bash
flutterguard fix --dry-run
flutterguard fix
flutterguard fix --revert
```

`--dry-run` prints the files and lines it would change and writes nothing. An apply writes the original files into `.flutterguard/backups/<timestamp>/` before it changes them, plus `manifest.json`. `--revert` restores the newest backup.

Fixes are skipped when the line no longer matches, the path is not a regular Dart file, or the path escapes the project. Security-sensitive configuration is not in the fix set.

`flutterguard fix` runs its scan offline so a fix does not depend on the network.
