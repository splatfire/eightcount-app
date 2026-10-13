#!/bin/bash
# EightCount — one-command setup on your Mac.
#
#   ./setup-mac.sh             generate the Xcode project, compile check, open Xcode
#   ./setup-mac.sh --install   ...and build, sign, install and launch on your
#                              iPhone (connected by cable, unlocked)
#
# Options:
#   --team ABCDE12345          your Apple Team ID (found automatically if possible)
#   --bundle-id com.you.app    use your own bundle ID (if Xcode says the default is taken)
#   --no-open                  don't open Xcode at the end
#
# Things only you can do (the script tells you when they're missing):
#   1. Xcode → Settings → Accounts → + → sign in with your Apple ID (one time)
#   2. iPhone: tap "Trust" when connected, turn on Settings → Privacy & Security
#      → Developer Mode (one time, needs a restart)
#   3. Free Apple ID: after the first install, iPhone Settings → General →
#      VPN & Device Management → your Apple ID → Trust (one time)
set -euo pipefail
cd "$(dirname "$0")"

INSTALL=0; OPEN=1; TEAM_ID=""; BUNDLE_ID=""
while [ $# -gt 0 ]; do
  case "$1" in
    --install) INSTALL=1 ;;
    --no-open) OPEN=0 ;;
    --team) TEAM_ID="${2:-}"; shift ;;
    --bundle-id) BUNDLE_ID="${2:-}"; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) # old style: ./setup-mac.sh TEAMID [BUNDLE_ID]
       if [ -z "$TEAM_ID" ]; then TEAM_ID="$1"; else BUNDLE_ID="$1"; fi ;;
  esac
  shift
done

step() { printf '\n\033[1;35m==> %s\033[0m\n' "$1"; }
fail() { printf '\n\033[1;31m✗ %s\033[0m\n' "$1"; exit 1; }

# ---------------------------------------------------------------- Xcode
step "Checking Xcode"
if ! xcodebuild -version >/dev/null 2>&1; then
  fail "Xcode isn't ready. Install Xcode from the Mac App Store, open it once
  (let it install components), then run:
    sudo xcode-select -s /Applications/Xcode.app
  and run this script again."
fi
xcodebuild -version
# First-launch tasks (license, components). Harmless if already done.
xcodebuild -runFirstLaunch >/dev/null 2>&1 || true

# ---------------------------------------------------------------- XcodeGen
step "Checking XcodeGen"
if ! command -v xcodegen >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    fail "Homebrew is missing. Install it with the one line from https://brew.sh
  (follow the 'Next steps' it prints), then run this script again."
  fi
  brew install xcodegen
fi
xcodegen --version

# ---------------------------------------------------------------- Team ID
find_team_id() {
  # 1) From an existing "Apple Development" signing certificate (OU = Team ID).
  local subj
  subj=$(security find-certificate -c "Apple Development" -p 2>/dev/null \
         | openssl x509 -noout -subject 2>/dev/null || true)
  if [ -n "$subj" ]; then
    echo "$subj" | sed -nE 's/.*OU ?= ?([A-Z0-9]{10}).*/\1/p' | head -1
    return
  fi
  # 2) From the teams Xcode knows about (after signing in under Settings → Accounts).
  defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null \
    | sed -nE 's/.*teamID = "?([A-Z0-9]{10})"?;.*/\1/p' | head -1
}

if [ -z "$TEAM_ID" ]; then
  TEAM_ID=$(sed -nE 's/.*DEVELOPMENT_TEAM: "([A-Z0-9]{10})".*/\1/p' project.yml | head -1)
fi
if [ -z "$TEAM_ID" ]; then
  TEAM_ID=$(find_team_id || true)
  [ -n "$TEAM_ID" ] && echo "Found your Team ID: $TEAM_ID"
fi
if [ -n "$TEAM_ID" ]; then
  sed -i '' -E "s/DEVELOPMENT_TEAM: \"[^\"]*\"/DEVELOPMENT_TEAM: \"$TEAM_ID\"/" project.yml
fi
if [ -n "$BUNDLE_ID" ]; then
  echo "Using bundle ID $BUNDLE_ID"
  sed -i '' -E "s/PRODUCT_BUNDLE_IDENTIFIER: [^ ]+  # app bundle ID/PRODUCT_BUNDLE_IDENTIFIER: $BUNDLE_ID  # app bundle ID/" project.yml
  sed -i '' -E "s/PRODUCT_BUNDLE_IDENTIFIER: [^ ]+\.uitests$/PRODUCT_BUNDLE_IDENTIFIER: $BUNDLE_ID.uitests/" project.yml
fi
APP_BUNDLE_ID=$(sed -nE 's/.*PRODUCT_BUNDLE_IDENTIFIER: ([^ ]+)  # app bundle ID.*/\1/p' project.yml)

# ---------------------------------------------------------------- Project
step "Generating EightCount.xcodeproj"
xcodegen generate

step "Compile check (no signing, 1–3 minutes the first time)"
if xcodebuild build -project EightCount.xcodeproj -scheme EightCount \
     -configuration Debug -destination 'generic/platform=iOS' \
     -derivedDataPath build/check CODE_SIGNING_ALLOWED=NO -quiet > build.log 2>&1; then
  echo "✓ Compiles."
else
  echo "Compile check FAILED. Errors:"
  grep -E "error:" build.log | sort -u || tail -40 build.log
  echo "Full log: $(pwd)/build.log"
  [ "$INSTALL" = 1 ] && fail "Fix the build errors first (or ask Claude Code with the log)."
fi

# ---------------------------------------------------------------- iPhone
if [ "$INSTALL" = 1 ]; then
  [ -n "$TEAM_ID" ] || fail "No Apple Team found. In Xcode: Settings (⌘,) → Accounts → + →
  Apple Account → sign in. Then run this script again
  (or pass it: ./setup-mac.sh --install --team ABCDE12345)."

  step "Looking for your iPhone"
  JSON=$(mktemp)
  xcrun devicectl list devices --json-output "$JSON" >/dev/null 2>&1 || true
  DEVICE_INFO=$(python3 - "$JSON" <<'PY'
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    devices = []
best = None
for d in devices:
    hw = d.get("hardwareProperties", {})
    if hw.get("platform") != "iOS" or hw.get("deviceType", "iPhone") != "iPhone":
        continue
    conn = d.get("connectionProperties", {})
    props = d.get("deviceProperties", {})
    row = [d.get("identifier", ""), hw.get("udid", ""), props.get("name", "iPhone"),
           conn.get("pairingState", ""), props.get("developerModeStatus", ""),
           conn.get("tunnelState", "")]
    # Prefer a device that is paired and currently connected.
    if best is None or (row[3] == "paired" and row[5] != "unavailable"):
        best = row
print("|".join(best) if best else "")
PY
)
  rm -f "$JSON"
  [ -n "$DEVICE_INFO" ] || fail "No iPhone found. Connect it with a cable, unlock it and tap
  \"Trust This Computer\". Then run this script again."
  IFS='|' read -r DEVICE_ID DEVICE_UDID DEVICE_NAME PAIRING DEVMODE _ <<< "$DEVICE_INFO"
  echo "Found: $DEVICE_NAME ($DEVICE_UDID) — pairing: ${PAIRING:-?}, developer mode: ${DEVMODE:-?}"
  [ "$PAIRING" = "paired" ] || fail "The iPhone isn't paired yet. Unlock it, tap \"Trust\", enter
  your passcode, then run this script again."
  if [ "$DEVMODE" = "disabled" ]; then
    fail "Developer Mode is off. On the iPhone: Settings → Privacy & Security → Developer Mode
  → on → Restart → after restart tap \"Turn On\". Then run this script again."
  fi

  step "Building and signing for $DEVICE_NAME (team $TEAM_ID)"
  if ! xcodebuild build -project EightCount.xcodeproj -scheme EightCount \
       -configuration Debug -destination "platform=iOS,id=$DEVICE_UDID" \
       -derivedDataPath build/device \
       -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
       DEVELOPMENT_TEAM="$TEAM_ID" > device-build.log 2>&1; then
    echo "Signing/build failed:"
    grep -E "error:" device-build.log | sort -u | head -20 || tail -40 device-build.log
    if grep -qiE "bundle identifier|App ID|is not available" device-build.log; then
      echo
      echo "→ The bundle ID is probably taken. Run again with your own, e.g.:"
      echo "  ./setup-mac.sh --install --bundle-id com.$(whoami | tr -cd 'a-z0-9').eightcount"
    fi
    if grep -qiE "No Accounts|account|sign in" device-build.log; then
      echo
      echo "→ Sign in to Xcode: Settings (⌘,) → Accounts → + → Apple Account."
    fi
    fail "Full log: $(pwd)/device-build.log"
  fi
  APP=build/device/Build/Products/Debug-iphoneos/EightCount.app
  echo "✓ Built and signed."

  step "Installing on $DEVICE_NAME"
  xcrun devicectl device install app --device "$DEVICE_ID" "$APP"

  step "Launching EightCount"
  if xcrun devicectl device process launch --device "$DEVICE_ID" "$APP_BUNDLE_ID" >/dev/null 2>&1; then
    echo "✓ EightCount is running on your iPhone."
  else
    echo "Installed, but iOS didn't let it start yet. With a free Apple ID do this once:"
    echo "  iPhone Settings → General → VPN & Device Management → your Apple ID → Trust"
    echo "Then tap the EightCount icon on your home screen."
  fi
  echo
  echo "Free Apple ID: the app stops opening after 7 days — just run"
  echo "  ./setup-mac.sh --install --no-open"
  echo "again with the iPhone connected. Your projects and notes stay."
fi

# ---------------------------------------------------------------- Xcode
if [ "$OPEN" = 1 ]; then
  step "Opening Xcode"
  open EightCount.xcodeproj
fi
echo
echo "Done."
