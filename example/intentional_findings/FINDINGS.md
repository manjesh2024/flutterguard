# Expected findings

Every issue in this directory is deliberate. The values in `lib/demo_secrets.dart` are fake demonstration strings. They are not credentials, and this sample has no private key.

`FG-QUAL-004` is suppressed by `.flutterguard.yaml` and should appear under suppressions, not as an active finding. Launcher-icon findings can also appear because this sample does not ship icon files.

| Rule | Severity | Why it is here |
| --- | --- | --- |
| FG-BRAND-001 | medium | `applicationId` is the template value `com.example.intentional`. |
| FG-BRAND-002 | medium | The iOS bundle id uses the same template value. |
| FG-BRAND-003 | medium | Android display name `Demo Android` and iOS display name `Demo iOS` differ. |
| FG-BRAND-004 | medium | Android `ic_launcher` and the iOS `AppIcon.appiconset` are omitted. There is no `web/` directory, so no favicon finding is produced. |
| FG-CFG-001 | medium | `lib/demo_secrets.dart` contains `http://insecure.demo.test/api`. |
| FG-CFG-004 | high | The release build type and the manifest are marked debuggable. |
| FG-CFG-005 | low | A URL is present and the project has no environment switch. |
| FG-CFG-006 | low and medium | `minSdk` is 16 and release minify is off. |
| FG-ARCH-001 | high | `lib/presentation/home_page.dart` imports `lib/data/store.dart` under the `clean` profile. |
| FG-QUAL-004 | info | A TODO in `lib/review.dart`. Hidden by a suppression that names the rule, path, and reason. |
| FG-QUAL-005 | low | `print` in `lib/quality.dart`. |
| FG-QUAL-006 | medium | An empty `catch` in `lib/quality.dart`. |
| FG-QUAL-008 | low | `lib/unused_import.dart` imports `Store` and does not use it. Safe to preview with `fix --dry-run`. |
| FG-SEC-001 | high | A fake `password` assignment. The same line that assigns `client_secret` also matches this rule because the name contains `secret`. Both values are redacted. |
| FG-SEC-002 | high | A fake `client_secret` assignment. The value is redacted. |
| FG-SEC-004 | high | The same cleartext URL, plus `usesCleartextTraffic="true"`. |
| FG-SEC-007 | medium | The manifest declares `android.permission.CAMERA`. |
| FG-L10N-001 | medium | `onlyEn` exists in English and not in Spanish. |
| FG-L10N-002 | medium | `greeting` has `{name}` in English and no placeholder in Spanish. |
| FG-L10N-006 | low | `Text('Welcome back')` is user-facing copy. |
| FG-DEP-001 | low | `collection` is a direct dependency and is not referenced. It is not removed. |
| FG-PLAT-001 | medium | `.MainActivity` is exported and has no intent filter. |
| FG-PLAT-002 | medium | `NSCameraUsageDescription` is empty. |

The quality gate fails because high findings are present. That is exit code 1, which means the scan finished.
