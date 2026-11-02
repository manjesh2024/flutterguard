# Monorepo discovery

FlutterGuard treats a directory as a Flutter project when its `pubspec.yaml` depends on the Flutter SDK or has a top-level `flutter:` section.

From this directory, `.flutterguard.yaml` sets `discovery.mode` to `monorepo` and leaves `discovery.roots` empty. Empty roots mean:

1. Walk this tree to `discovery.maxDepth` (4). Symlinks are not followed. `.dart_tool`, `build`, and the other skipped directory names are not entered.
2. Read `melos.yaml` `packages` and add each matching Flutter project. The patterns here are `apps/*` and `packages/*`.
3. Read the root `pubspec.yaml` `workspace` list and add `apps/shop`, `apps/admin`, and `packages/shared_ui` when each one is a Flutter project.

The root pubspec is not itself a Flutter project, so it is not scanned as an app. The scan reports three projects: `admin_app`, `shop_app`, and `shared_ui`.

`architecture.profile` is `featureFirst`. That profile applies inside each discovered project. `shared_ui` is a path dependency, so an app import of `package:shared_ui/shared_ui.dart` is a package import, not a layer violation.

`exclude` replaces the default exclude list. `**/generated/**` drops `apps/shop/lib/generated/skipped.dart`, including the `print` in that file.

`include` is omitted, so the built-in include globs stay in effect.

The quality gate passes. Two medium `FG-DEP-005` findings remain because `shop_app` and `admin_app` depend on `shared_ui` with a path source. That is how this workspace is wired. FlutterGuard does not rewrite those dependencies.

Run from the repository root:

```bash
dart run bin/flutterguard.dart example/advanced_monorepo --offline
```
