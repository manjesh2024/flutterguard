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

## Release steps

1. Run `./tool/verify_all.sh`.
2. Confirm `CHANGELOG.md` and the version in `pubspec.yaml` match.
3. Tag the commit.
4. Run `dart pub publish --dry-run`.
5. Run `dart pub publish` from an authenticated publisher account.

GitHub Actions on a `v*` tag runs the dry-run only.

## Repository

The public source repository is `flutterguard` on the maintainer's GitHub account. Homepage, issue tracker, and documentation fields in `pubspec.yaml` point at that repository.
