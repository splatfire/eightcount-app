#!/bin/bash
# One-command setup on your Mac:
#   cd path/to/splatfire/eightcount
#   ./setup-mac.sh                      # generate + open in Xcode
#   ./setup-mac.sh ABCDE12345           # ...and save your Team ID in project.yml
#   ./setup-mac.sh ABCDE12345 com.yourname.eightcount   # ...and your own bundle ID
#
# It checks Xcode, installs XcodeGen (via Homebrew) if needed, generates
# EightCount.xcodeproj, does a quick compile check without signing, and opens
# the project in Xcode. It never touches anything outside this folder except
# installing XcodeGen with Homebrew.
set -euo pipefail
cd "$(dirname "$0")"

TEAM_ID="${1:-}"
BUNDLE_ID="${2:-}"

echo "==> Checking Xcode"
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Xcode isn't set up. Install Xcode from the Mac App Store, open it once,"
  echo "then run:  sudo xcode-select -s /Applications/Xcode.app"
  exit 1
fi
xcodebuild -version

echo "==> Checking XcodeGen"
if ! command -v xcodegen >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is missing. Install it from https://brew.sh, then run this script again."
    exit 1
  fi
  brew install xcodegen
fi

if [ -n "$TEAM_ID" ]; then
  echo "==> Saving Team ID $TEAM_ID in project.yml"
  sed -i '' "s/DEVELOPMENT_TEAM: \".*\"/DEVELOPMENT_TEAM: \"$TEAM_ID\"/" project.yml
fi
if [ -n "$BUNDLE_ID" ]; then
  echo "==> Saving bundle ID $BUNDLE_ID in project.yml"
  sed -i '' -E "s/PRODUCT_BUNDLE_IDENTIFIER: [^ ]+  # app bundle ID/PRODUCT_BUNDLE_IDENTIFIER: $BUNDLE_ID  # app bundle ID/" project.yml
  sed -i '' -E "s/PRODUCT_BUNDLE_IDENTIFIER: [^ ]+\.uitests$/PRODUCT_BUNDLE_IDENTIFIER: $BUNDLE_ID.uitests/" project.yml
fi

echo "==> Generating EightCount.xcodeproj"
xcodegen generate

echo "==> Compile check (no signing, takes a minute or two)"
if xcodebuild build -project EightCount.xcodeproj -scheme EightCount \
     -configuration Debug -destination 'generic/platform=iOS' \
     CODE_SIGNING_ALLOWED=NO -quiet > build.log 2>&1; then
  echo "Compile check passed."
else
  echo "Compile check FAILED. Errors:"
  grep -E "error:" build.log | sort -u || tail -40 build.log
  echo "(Full log: $(pwd)/build.log) — Xcode will open anyway so you can look."
fi

echo "==> Opening Xcode"
open EightCount.xcodeproj
echo "Next: pick your iPhone at the top of Xcode and press Run (⌘R). See README.md section 1."
