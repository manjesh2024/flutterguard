#!/usr/bin/env bash
# Local release verification for macOS and Linux.
# Windows runs the same Dart commands from GitHub Actions.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

LOG_DIR="$ROOT/build/verify"
mkdir -p "$LOG_DIR"
SUMMARY="$LOG_DIR/summary.txt"
: >"$SUMMARY"
FAILED=0

# Line coverage of lib/ required by this release. Measured against the
# executable library after the suite below, then locked here.
MIN_LINE_COVERAGE=80

stage() {
  local name="$1"
  shift
  local log="$LOG_DIR/${name}.log"
  echo ""
  echo "=== $name ==="
  set +e
  "$@" >"$log" 2>&1
  local code=$?
  set -e
  if [[ $code -eq 0 ]]; then
    echo "PASS  $name" | tee -a "$SUMMARY"
  else
    echo "FAIL  $name (exit $code)" | tee -a "$SUMMARY"
    echo "----- $name (last 120 lines) -----"
    tail -n 120 "$log" || true
    FAILED=1
  fi
}

stage_shell() {
  local name="$1"
  local script="$2"
  stage "$name" bash -c "$script"
}

echo "FlutterGuard verification"
echo "Root: $ROOT"
dart --version
echo ""

stage dependency_resolution dart pub get
stage formatting dart format --output=none --set-exit-if-changed .
stage static_analysis dart analyze --fatal-infos
stage rule_catalogue dart run tool/generate_rule_catalogue.dart
stage_shell rule_catalogue_fresh "git diff --exit-code -- docs/rule-catalogue.md"

stage unit_tests dart test test/core_test.dart test/docs_test.dart
stage rule_tests dart test test/scan_test.dart
stage integration_tests dart test integration_test
stage regression_tests dart test test/regression
stage cli_smoke_tests dart test integration_test/cli_smoke_test.dart
stage module_fixture_tests dart test test/scan_test.dart
stage configuration_tests dart test test/core_test.dart --name "configuration"
stage baseline_suppression_tests dart test test/cli_safety_test.dart --name "baseline"
stage report_generation_tests dart test test/scan_test.dart --name "reports are deterministic"
stage autofix_tests dart test test/cli_safety_test.dart --name "auto-fix"
stage secret_redaction_tests dart test test/core_test.dart test/scan_test.dart --name "redact"
stage monorepo_tests dart test test/scan_test.dart --name "monorepo"

stage license_check dart run tool/check_licenses.dart
stage publish_dry_run dart pub publish --dry-run

stage_shell coverage_report '
  set -euo pipefail
  rm -rf coverage
  dart test --coverage=coverage test integration_test
  dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
  awk -F: "
    /^LF:/ { lf += \$2 }
    /^LH:/ { lh += \$2 }
    END {
      if (lf == 0) { print \"no lines\"; exit 1 }
      pct = (100 * lh) / lf
      printf \"line coverage %.2f%% (%d/%d)\\n\", pct, lh, lf
      if (pct + 0.0001 < '"$MIN_LINE_COVERAGE"') exit 1
    }
  " coverage/lcov.info
'

stage_shell git_hygiene '
  set -euo pipefail
  git rev-parse --is-inside-work-tree >/dev/null
  git diff --check
  if git ls-files build .flutterguard coverage | grep -q .; then
    echo "generated reports or coverage are tracked"
    git ls-files build .flutterguard coverage
    exit 1
  fi
  if grep -RInE "AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|BEGIN [A-Z ]*PRIVATE KEY" \
      --exclude=verify_all.sh \
      lib bin docs .github example tool README.md CHANGELOG.md pubspec.yaml; then
    echo "secret-shaped text in package source"
    exit 1
  fi
  if grep -RInE "/Users/|/Volumes/|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}" \
      --exclude=verify_all.sh \
      lib bin docs .github example tool README.md CHANGELOG.md pubspec.yaml; then
    echo "machine path or email address in package source"
    exit 1
  fi
  test -f pubspec.lock
  test -f LICENSE
  test -f CHANGELOG.md
'

echo ""
echo "=== verification summary ==="
cat "$SUMMARY"
if [[ $FAILED -ne 0 ]]; then
  echo "Verification failed."
  exit 1
fi
echo "Verification passed."
exit 0
