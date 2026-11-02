# Custom rules

Custom rules are literal text checks. They are not regular expressions.

```yaml
customRules:
  - id: FG-CUSTOM-001
    severity: medium
    category: configuration
    message: Legacy host still appears in this project.
    recommendation: Move the host into configuration.
    fileGlobs:
      - "**/*.dart"
    contains: "legacy.internal.example"
    heuristic: true
```

Rules:

- The id must start with `FG-CUSTOM-` and match the rule-id shape.
- `contains` is 1 to 200 characters.
- Globs use `*`, `?`, and `**` only.
- The rule is heuristic unless `heuristic: false` is set. Prefer `true`.
- These rules run with the configuration module. Disabling that module disables them.
- `rules.FG-CUSTOM-001.enabled` can turn one rule off.

A match reports the file and line. It does not evaluate the string as code.
