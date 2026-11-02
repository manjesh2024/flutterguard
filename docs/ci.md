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
- `.github/workflows/release.yml` runs only when a tag matching `v[0-9]+.[0-9]+.[0-9]+` is pushed. That is the GitHub form of the pub.dev tag pattern `v{{version}}`. It does not run on `workflow_dispatch`.
- The release workflow runs `./tool/verify_all.sh`, then requires the tag to equal `v` plus the `pubspec.yaml` version. Publishing starts only after both checks pass.
- Publishing uses `dart-lang/setup-dart/.github/workflows/publish.yml@v1` with `id-token: write` and the GitHub environment `pub.dev`. Authentication is the temporary OIDC token from that reusable workflow. The repository does not store a pub.dev token.

No workflow stores a long-lived pub.dev credential. A tag-triggered run has not yet published a package through this workflow. `flutterguard_audit` 0.2.0 was published from a local `dart pub publish` before the workflow gained a publish job.
