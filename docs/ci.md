# CI/CD

## Local release check

On macOS and Linux:

```bash
./tool/verify_all.sh
```

The script resolves dependencies, checks formatting, runs the analyzer, runs unit, rule, integration, regression, and CLI tests, checks licenses, runs `dart pub publish --dry-run`, and checks the tree for secret-shaped strings and machine-specific paths. It prints a stage summary and exits non-zero if a mandatory stage fails.

## GitHub Actions

- `.github/workflows/ci.yml` runs on pull requests and pushes to `main`.
- Ubuntu and macOS run `tool/verify_all.sh`.
- Windows runs the Dart format, analyze, and test commands directly.
- A Flutter stable job repeats the test suite with the Dart SDK shipped by Flutter.
- The security fixture is scanned so a SARIF file can be uploaded as an artifact. Exit code `1` is expected for that fixture because its quality gate fails. Exit codes above `1` fail the job.
- `.github/workflows/release.yml` runs on tags named `v*` and performs a publish dry-run. It does not contain credentials and it does not publish.

No workflow stores tokens. A pub.dev publish from CI needs a token configured outside this repository.
