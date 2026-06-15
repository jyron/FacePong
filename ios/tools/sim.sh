#!/bin/bash
# Build, install, launch on the booted iPhone simulator and grab frames.
# Usage: tools/sim.sh [shotPrefix] [numShots] [delayBetween]
set -e
cd "$(dirname "$0")/.."
SIM=${SIM:-BFD6B377-32EC-4125-8D79-EEB5C3FEBA5C}   # iPhone 17 Pro
PREFIX=${1:-/tmp/fp}
SHOTS=${2:-3}
DELAY=${3:-0.7}

DD="$PWD/.build"
# Regenerate the project so newly-added Swift files & resources are always included.
xcodegen generate >/dev/null
xcodebuild -project FacePong.xcodeproj -scheme FacePong -sdk iphonesimulator \
  -configuration Debug -destination "platform=iOS Simulator,id=$SIM" \
  -derivedDataPath "$DD" \
  build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -iE "error:|BUILD SUCCEEDED|BUILD FAILED" | head -40

APP="$DD/Build/Products/Debug-iphonesimulator/FacePong.app"
xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1 || true
xcrun simctl terminate "$SIM" com.facepong.app >/dev/null 2>&1 || true
xcrun simctl install "$SIM" "$APP"
sleep 2                                   # let SpringBoard finish the install banner
xcrun simctl launch "$SIM" com.facepong.app >/dev/null
sleep 3                                   # let the app actually draw before first shot
for i in $(seq 1 "$SHOTS"); do
  xcrun simctl io "$SIM" screenshot "${PREFIX}_${i}.png" >/dev/null 2>&1
  echo "shot ${PREFIX}_${i}.png"
  sleep "$DELAY"
done
