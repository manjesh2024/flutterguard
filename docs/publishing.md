# Publishing

## Name

The pub.dev package name is `flutterguard_audit`. The executable remains `flutterguard`.

`flutterguard` was unused on pub.dev at the time of this decision. `flutterguard_audit` was also unused. An unrelated package, `flutterguard_cli`, already describes a different tool. This project uses `flutterguard_audit` so the package slug matches the product proposal and does not collide with that name.

## License

MIT. Direct dependencies are BSD, MIT, or Apache licensed. `tool/check_licenses.dart` reads license files from the local pub cache and fails the release check on a GPL classification. Missing license files are reported and do not by themselves fail the check.

## Package contents

`dart pub publish --dry-run` is the validation step. Do not pass `--force` or `--skip-validation` to hide a real problem.

The published package must not contain credentials, private company rules, or machine-specific paths. Release notes that record a build machine stay out of the package through `.pubignore`.

`docs/` is the repository guide set required by the project layout. pub.dev warns on a plural top-level `docs` directory, so `.pubignore` omits it and `doc/README.md` points at the GitHub guides. `test/fixtures/` is also omitted. Those apps import Flutter and other packages on purpose, and publishing them as part of this Dart package would make pub analyze those imports as dependencies of FlutterGuard. The fixtures remain in the Git repository and in CI.

`flutterguard_audit` 0.1.0 is the first version published on pub.dev. 0.1.1 documented the install path. 0.1.2 documents the public Dart API. 0.2.0 improves audit accuracy and the local HTML report. Later versions follow the same dry-run and publish steps.

## Release steps

1. Run `./tool/verify_all.sh`.
2. Confirm `CHANGELOG.md` and the version in `pubspec.yaml` match.
3. Tag that commit `v` plus the pubspec version, for example `v0.2.0` for version `0.2.0`.
4. Push the tag. `.github/workflows/release.yml` runs `./tool/verify_all.sh`, checks that the tag matches `pubspec.yaml`, and then calls `dart-lang/setup-dart/.github/workflows/publish.yml@v1`.
5. The publish job uses GitHub environment `pub.dev` and OIDC. It does not use a long-lived pub.dev token.

The workflow publishes only after verification passes. It does not run from `workflow_dispatch`. Pushing the tag is what starts it. Automated publishing is configured in the workflow; a version tag has not yet published a package through GitHub Actions.

## Repository

The public source repository is `flutterguard` on the maintainer's GitHub account. Homepage, issue tracker, and documentation fields in `pubspec.yaml` point at that repository.
