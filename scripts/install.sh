#!/bin/bash
# Install ClipX, launch it, and report Accessibility trust.
# Idempotent. Does not grant Accessibility, edit privacy databases, or change SIP.
# Compatible with macOS /bin/bash 3.2. See AGENTS.md.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

PREFIX="/Applications"
PREFIX_SET=0
KEEP_IN_BUILD=0
CHECK_ONLY=0
LAUNCHED_PID=""
ACCESSIBILITY_STATE=""
SETTINGS_OPENED=0

die() {
    printf 'result: failed\n' >&2
    printf 'error: %s\n' "$*" >&2
    exit 1
}

step() {
    printf 'step: %s\n' "$*"
}

usage() {
    cat <<'EOF'
Usage: scripts/install.sh [options]

Build ClipX, install it, clear quarantine, ad-hoc sign, launch, and print
whether Accessibility is trusted. Safe to run again. On a Mac with System
Integrity Protection left on, this cannot grant Accessibility for you.

Options:
  --prefix DIR       Directory to install into (default: /Applications)
  --keep-in-build    Launch build/ClipX.app instead of copying it
  --check            Do not rebuild or re-sign. Re-check trust and relaunch
  -h, --help         Show this help

Exit codes:
  0  ClipX is running and Accessibility is trusted
  1  Setup failed (compiler, signature, launch, or this is not macOS)
  2  ClipX is running, but a person must allow Accessibility

After exit 2, a person allows ClipX under Privacy & Security → Accessibility,
then run: bash scripts/install.sh --check
Do not run a full install again after that approval unless the code changed.
EOF
}

version_ge() {
    # True when $1 >= $2. Numeric dot-separated versions only (5.9, 14.6.1, 26).
    local ver1="$1"
    local ver2="$2"
    local a b
    ver1="${ver1%%[^0-9.]*}"
    ver2="${ver2%%[^0-9.]*}"
    while true; do
        a="${ver1%%.*}"
        b="${ver2%%.*}"
        if [[ -z "$a" ]]; then a=0; fi
        if [[ -z "$b" ]]; then b=0; fi
        # Split so this stays valid on macOS /bin/bash 3.2.
        if [[ "$a" =~ [^0-9] ]]; then return 1; fi
        if [[ "$b" =~ [^0-9] ]]; then return 1; fi
        if ((10#$a > 10#$b)); then return 0; fi
        if ((10#$a < 10#$b)); then return 1; fi
        if [[ "$ver1" == *.* ]]; then ver1="${ver1#*.}"; else ver1=""; fi
        if [[ "$ver2" == *.* ]]; then ver2="${ver2#*.}"; else ver2=""; fi
        if [[ -z "$ver1" && -z "$ver2" ]]; then return 0; fi
    done
}

parse_swift_version() {
    local line
    line=$(sed -n 's/.*Swift version \([0-9][0-9.]*\).*/\1/p')
    printf '%s\n' "${line%%$'\n'*}"
}

require_cmd() {
    local cmd="$1"
    local hint="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        die "Missing '$cmd'. $hint"
    fi
}

require_macos() {
    local os_ver
    if [[ "$(uname -s)" != "Darwin" ]]; then
        die "ClipX is a macOS menu-bar app and can only be installed on macOS. This machine is $(uname -s). Clone the repo on a Mac and run: bash scripts/install.sh"
    fi
    os_ver=$(sw_vers -productVersion 2>/dev/null || true)
    os_ver="${os_ver%%[^0-9.]*}"
    if [[ -z "$os_ver" ]]; then
        die "Could not read the macOS version from sw_vers."
    fi
    if ! version_ge "$os_ver" 14; then
        die "macOS $os_ver is too old. ClipX needs macOS 14 or newer."
    fi
    printf 'macos: %s\n' "$os_ver"
}

preflight_install_tools() {
    local devdir raw ver
    if ! devdir=$(xcode-select -p 2>/dev/null); then
        die "No Xcode developer directory is selected. Install Xcode 15 or newer, or the Swift 5.9 command line tools, then run: xcode-select --install"
    fi
    if [[ ! -d "$devdir" ]]; then
        die "xcode-select points at $devdir, which is not a directory. Run: xcode-select --install"
    fi
    require_cmd swift "Install Xcode 15 or newer so 'swift' is on PATH."
    require_cmd codesign "codesign is part of macOS. Reinstall the command line tools with: xcode-select --install"
    require_cmd sips "sips is required to build the app icon."
    require_cmd iconutil "iconutil comes with Xcode or the command line tools. Run: xcode-select --install"
    require_cmd ditto "ditto is required to copy the app bundle."
    require_cmd xattr "xattr is required to clear quarantine."
    require_cmd open "open is required to launch ClipX and System Settings."
    require_cmd pgrep "pgrep is required to confirm ClipX is running."
    if [[ ! -x /usr/libexec/PlistBuddy ]]; then
        die "Missing /usr/libexec/PlistBuddy, which scripts/build_app.sh uses to stamp the bundle id."
    fi
    raw=$(swift --version 2>&1 || true)
    ver=$(printf '%s\n' "$raw" | parse_swift_version)
    if [[ -z "$ver" ]]; then
        die "Could not parse 'swift --version'. ClipX needs Swift 5.9 or newer. Output was: $raw"
    fi
    if ! version_ge "$ver" 5.9; then
        die "Swift $ver is too old. ClipX needs Swift 5.9 or newer (Xcode 15 or newer)."
    fi
    printf 'swift: %s\n' "$ver"
    printf 'developer_dir: %s\n' "$devdir"
}

preflight_check_tools() {
    require_cmd codesign "codesign is required to verify the installed app."
    require_cmd xattr "xattr is required to clear quarantine."
    require_cmd open "open is required to launch ClipX and System Settings."
    require_cmd pgrep "pgrep is required to confirm ClipX is running."
    if [[ ! -x /usr/libexec/PlistBuddy ]]; then
        die "Missing /usr/libexec/PlistBuddy."
    fi
}

resolve_prefix() {
    if [[ "$KEEP_IN_BUILD" -eq 1 ]]; then
        return 0
    fi
    if [[ ! -d "$PREFIX" ]]; then
        die "Install directory does not exist: $PREFIX. Create it, or pass --prefix with a directory you can write to. This script does not request administrator rights."
    fi
    if [[ ! -w "$PREFIX" ]]; then
        die "Cannot write to $PREFIX. Pass --prefix with a writable directory (for example \$HOME/Applications after you create it). This script does not request administrator rights."
    fi
    PREFIX=$(cd "$PREFIX" && pwd)
}

target_app() {
    if [[ "$KEEP_IN_BUILD" -eq 1 ]]; then
        printf '%s\n' "$ROOT/build/ClipX.app"
    else
        printf '%s\n' "$PREFIX/ClipX.app"
    fi
}

recheck_command() {
    local cmd
    cmd="bash $ROOT/scripts/install.sh --check"
    if [[ "$KEEP_IN_BUILD" -eq 1 ]]; then
        cmd="$cmd --keep-in-build"
    elif [[ "$PREFIX_SET" -eq 1 ]]; then
        cmd="$cmd --prefix $(printf '%q' "$PREFIX")"
    fi
    printf '%s\n' "$cmd"
}

assert_clipx_bundle() {
    local app="$1"
    local plist bid bin
    plist="$app/Contents/Info.plist"
    bin="$app/Contents/MacOS/ClipX"
    if [[ ! -d "$app" ]]; then
        die "ClipX is not installed at $app. From the repo root run: bash scripts/install.sh"
    fi
    if [[ ! -f "$plist" ]]; then
        die "Missing Info.plist at $plist"
    fi
    if [[ ! -x "$bin" ]]; then
        die "Missing executable $bin"
    fi
    if ! bid=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist" 2>/dev/null); then
        die "Could not read CFBundleIdentifier from $plist"
    fi
    if [[ "$bid" != "com.clipx.app" ]]; then
        die "Refusing $app because its bundle id is '$bid', not com.clipx.app. Use scripts/install.sh (it builds with scripts/build_app.sh). The Xcode project still produces a different product name and bundle id, so do not point this script at that copy."
    fi
}

clear_quarantine_if_present() {
    local app="$1"
    local listing
    listing=$(xattr -lr "$app" 2>/dev/null || true)
    case "$listing" in
        *com.apple.quarantine*)
            step "Removing quarantine from $app"
            if ! xattr -cr "$app"; then
                die "Could not remove quarantine from $app"
            fi
            listing=$(xattr -lr "$app" 2>/dev/null || true)
            case "$listing" in
                *com.apple.quarantine*)
                    die "Quarantine is still set on $app"
                    ;;
            esac
            ;;
    esac
}

sign_app() {
    local app="$1"
    local details
    step "Ad-hoc signing $app"
    clear_quarantine_if_present "$app"
    if ! codesign --force --deep --sign - "$app"; then
        die "Ad-hoc codesign failed for $app"
    fi
    if ! codesign --verify "$app"; then
        die "codesign verification failed for $app. ClipX was not launched."
    fi
    # Do not pipe codesign into grep: a short read plus pipefail looks like failure.
    details=$(codesign -dv "$app" 2>&1 || true)
    case "$details" in
        *Signature=adhoc*) ;;
        *)
            die "ClipX at $app is not ad-hoc signed. codesign said: $details"
            ;;
    esac
}

verify_signature() {
    local app="$1"
    if ! codesign --verify "$app" 2>/dev/null; then
        die "Code signature check failed for $app. Run a full install so the app can be signed: bash $ROOT/scripts/install.sh"
    fi
}

quit_clipx() {
    local i
    if ! pgrep -x ClipX >/dev/null 2>&1; then
        return 0
    fi
    step "Stopping the running ClipX"
    osascript -e 'tell application "ClipX" to quit' >/dev/null 2>&1 || true
    i=0
    while pgrep -x ClipX >/dev/null 2>&1; do
        if [[ "$i" -ge 5 ]]; then
            killall ClipX >/dev/null 2>&1 || true
            sleep 1
            if pgrep -x ClipX >/dev/null 2>&1; then
                killall -9 ClipX >/dev/null 2>&1 || true
                sleep 1
            fi
            break
        fi
        sleep 1
        i=$((i + 1))
    done
    if pgrep -x ClipX >/dev/null 2>&1; then
        die "Could not quit the running ClipX process."
    fi
}

launch_and_confirm() {
    local app="$1"
    local i pids
    step "Launching $app"
    if ! open "$app"; then
        die "Could not launch $app"
    fi
    i=0
    while [[ "$i" -lt 20 ]]; do
        if pgrep -x ClipX >/dev/null 2>&1; then
            pids=$(pgrep -x ClipX || true)
            LAUNCHED_PID=${pids%%$'\n'*}
            if [[ -n "$LAUNCHED_PID" ]]; then
                return 0
            fi
        fi
        sleep 1
        i=$((i + 1))
    done
    die "ClipX did not stay running after launch. Run this from a logged-in macOS desktop (Terminal or a local agent). A headless SSH session cannot start a menu-bar app. If you are already on the desktop, look in Console.app for a ClipX crash."
}

accessibility_status_file() {
    printf '%s\n' "$HOME/Library/Application Support/ClipboardHistory/accessibility-status"
}

# The menu-bar process writes this after it starts and, if needed, asks for
# Accessibility. Waiting on the file avoids launching a second ClipX.
wait_for_accessibility_report() {
    local file i state
    if [[ -z "${HOME:-}" ]]; then
        die "HOME is not set. Run this as the logged-in Mac user."
    fi
    file=$(accessibility_status_file)
    rm -f "$file"
    launch_and_confirm "$1"
    step "Waiting for Accessibility status"
    i=0
    while [[ "$i" -lt 30 ]]; do
        if [[ -f "$file" ]]; then
            state=$(tr -d '[:space:]' <"$file")
            if [[ "$state" == "trusted" || "$state" == "not_trusted" ]]; then
                ACCESSIBILITY_STATE=$state
                confirm_still_running
                return 0
            fi
        fi
        if ! ps -p "$LAUNCHED_PID" >/dev/null 2>&1; then
            die "ClipX (pid $LAUNCHED_PID) exited before it recorded Accessibility status."
        fi
        sleep 1
        i=$((i + 1))
    done
    die "Timed out after 30s waiting for $file. ClipX writes trusted or not_trusted there after launch. Run this from a logged-in macOS desktop so the app can talk to WindowServer."
}

open_accessibility_settings() {
    local url
    SETTINGS_OPENED=0
    for url in \
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" \
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
    do
        if open "$url"; then
            SETTINGS_OPENED=1
            step "Opened System Settings ($url)"
            return 0
        fi
    done
    printf 'warning: could not open the Accessibility pane. Open it yourself.\n' >&2
    return 0
}

confirm_still_running() {
    if [[ -z "$LAUNCHED_PID" ]]; then
        die "ClipX has no recorded pid."
    fi
    if ! ps -p "$LAUNCHED_PID" >/dev/null 2>&1; then
        die "ClipX (pid $LAUNCHED_PID) exited during the Accessibility check."
    fi
}

print_ready() {
    local app="$1"
    local pid="$2"
    printf '%s\n' \
        "result: ready" \
        "accessibility: trusted" \
        "app: $app" \
        "bundle_id: com.clipx.app" \
        "running: yes" \
        "pid: $pid" \
        "hotkey: Cmd+Shift+V"
    printf '\n%s\n' "ClipX is running and Accessibility is trusted. The menu-bar icon is the clipboard symbol. The app stays out of the Dock. The global hotkey is Cmd+Shift+V unless it was changed in settings."
    printf '%s\n' "ClipX 已在运行，辅助功能已授权。菜单栏有剪切板图标，默认全局热键是 Cmd+Shift+V。"
}

print_needs_human() {
    local app="$1"
    local pid="$2"
    local next="$3"
    local settings_line
    if [[ "$SETTINGS_OPENED" -eq 1 ]]; then
        settings_line="System Settings was opened to Privacy & Security → Accessibility."
    else
        settings_line="Open System Settings → Privacy & Security → Accessibility yourself."
    fi
    printf '%s\n' \
        "result: needs_human" \
        "accessibility: not_trusted" \
        "app: $app" \
        "bundle_id: com.clipx.app" \
        "running: yes" \
        "pid: $pid" \
        "next: $next"
    cat <<EOF

ClipX is running, but Accessibility is not granted, so the global hotkey will not fire.
The menu-bar icon still opens the panel. This script cannot grant Accessibility while System Integrity Protection stays on.

A system prompt should be on screen. $settings_line

Do this once:
1. Allow ClipX in the system dialog, or turn ClipX on in the Accessibility list.
2. If ClipX is missing from the list, click + and choose:
   $app
3. Run this. It does not rebuild or re-sign, so the approval stays attached to this copy:
   $next

A later full install (bash scripts/install.sh with no --check) rebuilds and signs again.
macOS then treats ClipX as a different app and asks for Accessibility again.
Trust is also per path: build/ClipX.app and /Applications/ClipX.app are not the same grant.

需要你在「系统设置 → 隐私与安全性 → 辅助功能」中允许 ClipX。脚本无法代替你授权。完成后只执行上面的 next 命令。
EOF
}

finish_from_state() {
    local app="$1"
    confirm_still_running
    if [[ "$ACCESSIBILITY_STATE" == "trusted" ]]; then
        print_ready "$app" "$LAUNCHED_PID"
        exit 0
    fi
    open_accessibility_settings
    print_needs_human "$app" "$LAUNCHED_PID" "$(recheck_command)"
    exit 2
}

run_check() {
    local app
    preflight_check_tools
    resolve_prefix
    app=$(target_app)
    assert_clipx_bundle "$app"
    verify_signature "$app"
    clear_quarantine_if_present "$app"
    # Relaunch so a grant made while ClipX was already running takes effect.
    # RegisterEventHotKey runs at launch; a later approval does not bind the hotkey.
    quit_clipx
    wait_for_accessibility_report "$app"
    finish_from_state "$app"
}

run_install() {
    local built app
    preflight_install_tools
    resolve_prefix
    quit_clipx
    step "Building with scripts/build_app.sh --no-dmg"
    if ! bash "$ROOT/scripts/build_app.sh" --no-dmg; then
        die "Build failed. The compiler output above is the reason."
    fi
    built="$ROOT/build/ClipX.app"
    assert_clipx_bundle "$built"
    if [[ "$KEEP_IN_BUILD" -eq 1 ]]; then
        app="$built"
    else
        app="$PREFIX/ClipX.app"
        step "Installing $app"
        rm -rf "$app"
        if ! ditto "$built" "$app"; then
            die "Could not copy $built to $app"
        fi
    fi
    sign_app "$app"
    assert_clipx_bundle "$app"
    wait_for_accessibility_report "$app"
    finish_from_state "$app"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefix)
                shift
                if [[ $# -lt 1 ]]; then
                    usage >&2
                    die "Missing directory after --prefix"
                fi
                PREFIX="$1"
                PREFIX_SET=1
                ;;
            --prefix=*)
                PREFIX="${1#--prefix=}"
                PREFIX_SET=1
                if [[ -z "$PREFIX" ]]; then
                    usage >&2
                    die "Missing directory after --prefix"
                fi
                ;;
            --keep-in-build)
                KEEP_IN_BUILD=1
                ;;
            --check)
                CHECK_ONLY=1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                usage >&2
                die "Unknown option: $1"
                ;;
        esac
        shift
    done
}

main() {
    parse_args "$@"
    if [[ "$KEEP_IN_BUILD" -eq 1 && "$PREFIX_SET" -eq 1 ]]; then
        die "--keep-in-build does not take --prefix. Choose one install location."
    fi
    require_macos
    if [[ "$CHECK_ONLY" -eq 1 ]]; then
        run_check
    else
        run_install
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
