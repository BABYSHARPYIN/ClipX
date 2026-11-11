#!/bin/bash
# Contract checks for scripts/install.sh that do not build or launch ClipX.
# On macOS this skips anything that would start a real install.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=install.sh
source "$REPO/scripts/install.sh"

failures=0

ok() {
    printf 'ok: %s\n' "$1"
}

bad() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

expect_true() {
    local name="$1"
    shift
    if "$@"; then
        ok "$name"
    else
        bad "$name"
    fi
}

expect_false() {
    local name="$1"
    shift
    if "$@"; then
        bad "$name"
    else
        ok "$name"
    fi
}

capture_install() {
    local err_file
    err_file=$(mktemp "${TMPDIR:-/tmp}/clipx-test.XXXXXX")
    set +e
    INSTALL_STDOUT=$(bash "$REPO/scripts/install.sh" "$@" 2>"$err_file")
    INSTALL_CODE=$?
    set -e
    INSTALL_STDERR=$(cat "$err_file")
    rm -f "$err_file"
}

expect_true "bash -n install.sh" bash -n "$REPO/scripts/install.sh"
expect_true "bash -n build_app.sh" bash -n "$REPO/scripts/build_app.sh"
expect_true "bash -n test_install.sh" bash -n "$REPO/scripts/test_install.sh"

expect_true "5.9 >= 5.9" version_ge 5.9 5.9
expect_true "5.9.2 >= 5.9" version_ge 5.9.2 5.9
expect_true "5.10 >= 5.9" version_ge 5.10 5.9
expect_true "6 >= 5.9" version_ge 6 5.9
expect_true "14.6.1 >= 14" version_ge 14.6.1 14
expect_true "26.0 >= 14" version_ge 26.0 14
expect_true "14 >= 14.0" version_ge 14 14.0
expect_false "5.8 >= 5.9" version_ge 5.8 5.9
expect_false "13.6 >= 14" version_ge 13.6 14
expect_false "14.0 >= 14.1" version_ge 14.0 14.1

swift_sample='Apple Swift version 5.9.2 (swiftlang-5.9.2.2.56 clang-1500.1.0.2.5)
Target: arm64-apple-macosx14.0'
parsed=$(printf '%s\n' "$swift_sample" | parse_swift_version)
if [[ "$parsed" == "5.9.2" ]]; then
    ok "parse Swift 5.9.2"
else
    bad "parse Swift 5.9.2 (got '$parsed')"
fi

swift6='Apple Swift version 6.0.3 (swiftlang-6.0.3.1.10 clang-1600.0.30.1)'
parsed=$(printf '%s\n' "$swift6" | parse_swift_version)
if [[ "$parsed" == "6.0.3" ]]; then
    ok "parse Swift 6.0.3"
else
    bad "parse Swift 6.0.3 (got '$parsed')"
fi

capture_install --help
if [[ "$INSTALL_CODE" -eq 0 ]] && printf '%s\n' "$INSTALL_STDOUT" | grep -q 'Accessibility'; then
    ok "--help exits 0"
else
    bad "--help exits 0 (code $INSTALL_CODE)"
fi

capture_install --not-a-real-flag
if [[ "$INSTALL_CODE" -eq 1 ]] && printf '%s\n' "$INSTALL_STDERR" | grep -q 'result: failed'; then
    ok "unknown option exits 1"
else
    bad "unknown option exits 1 (code $INSTALL_CODE)"
fi

capture_install --prefix
if [[ "$INSTALL_CODE" -eq 1 ]] && printf '%s\n' "$INSTALL_STDERR" | grep -q 'Missing directory'; then
    ok "missing --prefix value exits 1"
else
    bad "missing --prefix value exits 1 (code $INSTALL_CODE)"
fi

capture_install --keep-in-build --prefix /Applications
if [[ "$INSTALL_CODE" -eq 1 ]] && printf '%s\n' "$INSTALL_STDERR" | grep -q 'keep-in-build'; then
    ok "conflicting location flags exit 1"
else
    bad "conflicting location flags exit 1 (code $INSTALL_CODE)"
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
    ok "skip non-macOS rejection test on Darwin"
else
    capture_install
    if [[ "$INSTALL_CODE" -eq 1 ]] && printf '%s\n' "$INSTALL_STDERR" | grep -q 'macOS'; then
        ok "non-macOS install exits 1"
    else
        bad "non-macOS install exits 1 (code $INSTALL_CODE)"
    fi
    capture_install --check
    if [[ "$INSTALL_CODE" -eq 1 ]] && printf '%s\n' "$INSTALL_STDERR" | grep -q 'macOS'; then
        ok "non-macOS --check exits 1"
    else
        bad "non-macOS --check exits 1 (code $INSTALL_CODE)"
    fi
fi

help_out=$(bash "$REPO/scripts/build_app.sh" --help)
if printf '%s\n' "$help_out" | grep -q -- '--no-dmg'; then
    ok "build_app.sh --help mentions --no-dmg"
else
    bad "build_app.sh --help mentions --no-dmg"
fi

set +e
bash "$REPO/scripts/build_app.sh" --bogus >/dev/null 2>&1
build_code=$?
set -e
if [[ "$build_code" -eq 1 ]]; then
    ok "build_app.sh rejects unknown options"
else
    bad "build_app.sh rejects unknown options (code $build_code)"
fi

if grep -q 'hdiutil create' "$REPO/scripts/build_app.sh" \
    && grep -q 'open -R' "$REPO/scripts/build_app.sh" \
    && grep -q 'SKIP_DMG' "$REPO/scripts/build_app.sh"; then
    ok "default DMG path is still in build_app.sh"
else
    bad "default DMG path is still in build_app.sh"
fi

if grep -q 'AXIsProcessTrustedWithOptions' "$REPO/ClipboardHistory/Services/GlobalHotkeyMonitor.swift" \
    && grep -q -- '--accessibility-status' "$REPO/ClipboardHistory/Services/GlobalHotkeyMonitor.swift" \
    && grep -q 'accessibility-status' "$REPO/scripts/install.sh" \
    && grep -q 'ClipboardHistory/accessibility-status' "$REPO/scripts/install.sh" \
    && grep -q 'exitIfStatusRequested' "$REPO/ClipboardHistory/ClipboardHistoryApp.swift" \
    && grep -q 'recordForRunningApp' "$REPO/ClipboardHistory/ClipboardHistoryApp.swift"; then
    ok "app prompts for Accessibility and records trust"
else
    bad "app prompts for Accessibility and records trust"
fi

if grep -E 'TCC\.db|csrutil|sudo' "$REPO/scripts/install.sh" >/dev/null; then
    bad "install.sh contains a TCC, SIP, or sudo command"
else
    ok "install.sh does not bypass TCC or SIP"
fi

if [[ "$failures" -ne 0 ]]; then
    printf '%s\n' "$failures test(s) failed" >&2
    exit 1
fi

printf '%s\n' "all install contract checks passed"
