#!/usr/bin/env bash
# Build installable EditPad packages. Requires macOS with Xcode 16+.
#
#   scripts/package.sh ipa                         Unsigned .ipa, for sideloading tools
#                                                  (Sideloadly, AltStore) that re-sign it.
#   scripts/package.sh ipa --team ABCDE12345       Signed development .ipa for your own devices.
#   scripts/package.sh ipa --team ABCDE12345 --install
#                                                  ...and install it on the connected iPhone/iPad.
#   scripts/package.sh simulator [--install]       Simulator app (.zip); --install runs it in the
#                                                  booted (or a new) iOS Simulator.
#   scripts/package.sh all                         Unsigned .ipa + simulator .zip (what CI builds).
#
# Options:
#   --team ID          Apple development team ID (Xcode › Settings › Accounts). Enables signing.
#   --bundle-id ID     Override the bundle identifier for this build only, e.g. when a free
#                      Apple account reports that com.tannerpresscorp.editpad is unavailable.
#   --build-number N   CFBundleVersion (default: number of commits on HEAD).
#   --output DIR       Where packages go (default: dist/).
#   --install          Install after building (see above).
#
# Nothing in the Xcode project is modified; overrides are passed on the command line.

set -euo pipefail

# Prints the comment block at the top of this file.
usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit "${1:-0}"; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/EditPad.xcodeproj"
SCHEME="EditPad"
APP_NAME="EditPad"

mode="${1:-}"
[[ -z "$mode" || "$mode" == "-h" || "$mode" == "--help" ]] && usage 0
case "$mode" in ipa|simulator|all) shift ;; *) echo "Unknown mode: $mode" >&2; usage 1 ;; esac

team=""
bundle_id=""
build_number=""
output="$ROOT/dist"
install=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team) team="${2:?--team needs a value}"; shift 2 ;;
    --bundle-id) bundle_id="${2:?--bundle-id needs a value}"; shift 2 ;;
    --build-number) build_number="${2:?--build-number needs a value}"; shift 2 ;;
    --output) output="${2:?--output needs a value}"; shift 2 ;;
    --install) install=true; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

if [[ "$mode" == "all" && ( -n "$team" || "$install" == true ) ]]; then
  echo "'all' builds the unsigned packages only; use 'ipa --team …' for a signed build." >&2
  exit 1
fi

command -v xcodebuild >/dev/null || { echo "xcodebuild not found. This script needs macOS with Xcode 16 or later." >&2; exit 1; }

if [[ -z "$build_number" ]]; then
  build_number="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)"
fi
version="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ MARKETING_VERSION = / { print $2; exit }')"
version="${version:-1.0}"

mkdir -p "$output"
output="$(cd "$output" && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/editpad-package.XXXXXX")"
trap 'rm -rf "$work"' EXIT

common_settings=(CURRENT_PROJECT_VERSION="$build_number")
[[ -n "$bundle_id" ]] && common_settings+=(PRODUCT_BUNDLE_IDENTIFIER="$bundle_id")

log() { printf '\n==> %s\n' "$*"; }

# Prints only errors, warnings and the result line, but keeps the full log on failure.
run_xcodebuild() {
  local logfile="$work/xcodebuild-$RANDOM.log"
  if ! xcodebuild "$@" >"$logfile" 2>&1; then
    grep -E "error:|warning:|BUILD FAILED|ARCHIVE FAILED|EXPORT FAILED" "$logfile" | tail -40 >&2 || true
    echo "xcodebuild failed. Full log: $output/xcodebuild-failure.log" >&2
    cp "$logfile" "$output/xcodebuild-failure.log"
    exit 1
  fi
  grep -E "warning:" "$logfile" | grep -v "appintentsmetadataprocessor" || true
}

build_unsigned_ipa() {
  log "Archiving unsigned $APP_NAME $version ($build_number) for iOS devices"
  run_xcodebuild archive \
    -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$work/$APP_NAME.xcarchive" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
    "${common_settings[@]}"

  local app="$work/$APP_NAME.xcarchive/Products/Applications/$APP_NAME.app"
  [[ -d "$app" ]] || { echo "Archive has no $APP_NAME.app" >&2; exit 1; }

  rm -rf "$work/Payload" && mkdir -p "$work/Payload"
  cp -R "$app" "$work/Payload/"
  local ipa="$output/$APP_NAME-$version-$build_number-unsigned.ipa"
  rm -f "$ipa"
  (cd "$work" && zip -qry "$ipa" Payload)
  echo "Built $ipa"
  echo "Install it with a sideloading tool such as Sideloadly or AltStore, which signs it with your Apple ID."
}

build_signed_ipa() {
  log "Archiving signed $APP_NAME $version ($build_number) for team $team"
  run_xcodebuild archive \
    -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$work/$APP_NAME.xcarchive" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Automatic \
    "${common_settings[@]}"

  cat >"$work/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>debugging</string>
  <key>teamID</key><string>$team</string>
  <key>signingStyle</key><string>automatic</string>
  <key>compileBitcode</key><false/>
  <key>thinning</key><string>&lt;none&gt;</string>
</dict>
</plist>
EOF

  log "Exporting development .ipa"
  run_xcodebuild -exportArchive \
    -archivePath "$work/$APP_NAME.xcarchive" \
    -exportOptionsPlist "$work/ExportOptions.plist" \
    -exportPath "$work/export" \
    -allowProvisioningUpdates

  local exported
  exported="$(find "$work/export" -maxdepth 1 -name '*.ipa' | head -1)"
  [[ -n "$exported" ]] || { echo "Export produced no .ipa" >&2; exit 1; }
  local ipa="$output/$APP_NAME-$version-$build_number.ipa"
  cp "$exported" "$ipa"
  echo "Built $ipa"

  if [[ "$install" == true ]]; then
    install_on_device "$work/$APP_NAME.xcarchive/Products/Applications/$APP_NAME.app"
  fi
}

install_on_device() {
  local app="$1"
  log "Installing on connected device"
  local devices
  devices="$(xcrun devicectl list devices --hide-default-columns --columns Identifier State 2>/dev/null \
    | awk '$2 ~ /connected|available/ { print $1 }' | grep -E '^[0-9A-F-]{20,}$' || true)"
  local device
  device="$(echo "$devices" | head -1)"
  if [[ -z "$device" ]]; then
    echo "No connected iPhone or iPad found. Connect one by cable (or pair it over Wi-Fi in Xcode)," >&2
    echo "unlock it, enable Developer Mode, then run again or drag the .ipa onto it in Finder." >&2
    exit 1
  fi
  xcrun devicectl device install app --device "$device" "$app"
  echo "Installed. If iOS says the developer isn't trusted, open Settings › General › VPN & Device Management."
}

build_simulator() {
  log "Building $APP_NAME $version ($build_number) for iOS Simulator"
  run_xcodebuild build \
    -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$work/sim" \
    ONLY_ACTIVE_ARCH=NO \
    "${common_settings[@]}"

  local app="$work/sim/Build/Products/Release-iphonesimulator/$APP_NAME.app"
  [[ -d "$app" ]] || { echo "Build has no simulator $APP_NAME.app" >&2; exit 1; }
  local zip="$output/$APP_NAME-$version-$build_number-simulator.zip"
  rm -f "$zip"
  ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
  echo "Built $zip"

  if [[ "$install" == true ]]; then
    log "Installing in iOS Simulator"
    if ! xcrun simctl list devices booted | grep -q Booted; then
      local udid
      udid="$(xcrun simctl list devices available -j \
        | python3 -c 'import json,sys; d=json.load(sys.stdin)["devices"]; print(next((x["udid"] for r,v in sorted(d.items(), reverse=True) if "iOS" in r for x in v if x["name"].startswith("iPhone")), ""))')"
      [[ -n "$udid" ]] || { echo "No iPhone simulator found. Add one in Xcode › Window › Devices and Simulators." >&2; exit 1; }
      xcrun simctl boot "$udid"
    fi
    open -a Simulator
    xcrun simctl install booted "$app"
    local installed_id
    installed_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")"
    xcrun simctl launch booted "$installed_id" >/dev/null
    echo "Running $installed_id in the Simulator."
  fi
}

case "$mode" in
  ipa)
    if [[ -n "$team" ]]; then
      build_signed_ipa
    else
      [[ "$install" == true ]] && { echo "--install needs --team: an unsigned app can't be installed directly." >&2; exit 1; }
      build_unsigned_ipa
    fi
    ;;
  simulator) build_simulator ;;
  all) build_unsigned_ipa; build_simulator ;;
esac

log "Done. Packages are in $output"
