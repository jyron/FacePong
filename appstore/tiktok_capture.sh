#!/bin/bash
# Captures each FacePong matchup as a SILENT promo rally (FP_PROMO storm) PLUS its exact
# hit-event log (FPEVT lines streamed via --console-pty) and a one-frame sync flash, so the
# ad builder can reconstruct frame-/sample-accurate ASMR audio. Output per <key>:
#   gameplay/<key>_capture.mov   gameplay/<key>_events.log
# Usage: bash appstore/tiktok_capture.sh
set -e
cd "$(dirname "$0")/.."
APP=ios/.build-promo/Build/Products/Debug-iphonesimulator/FacePong.app
G=appstore/promo_video/tiktok/gameplay
BUNDLE=com.facepong.app
DUR="${DUR:-14}"
mkdir -p "$G"
xcrun simctl install booted "$APP"

cap () { # $1=key  $2=p1 rival id (blank = keep bundled char_player)  $3=p2 rival id
  local key=$1 OUT=$G/$1_capture.mov LOG=$G/$1_events.log
  rm -f "$OUT" "$LOG"
  xcrun simctl io booted recordVideo --codec=h264 --force "$OUT" & local REC=$!
  sleep 2
  local p1env=""; [ -n "$2" ] && p1env="SIMCTL_CHILD_FP_P1RIVAL=$2"
  env SIMCTL_CHILD_FP_ROUTE=play SIMCTL_CHILD_FP_PROMO=1 $p1env SIMCTL_CHILD_FP_RIVAL=$3 \
    xcrun simctl launch --console-pty --terminate-running-process booted "$BUNDLE" > "$LOG" 2>&1 &
  local LP=$!
  sleep "$DUR"
  kill -INT $REC 2>/dev/null || true; wait $REC 2>/dev/null || true
  xcrun simctl terminate booted "$BUNDLE" >/dev/null 2>&1 || true
  kill $LP 2>/dev/null || true
  sleep 1
  echo "captured $key: $(grep -c FPEVT "$LOG" 2>/dev/null || echo 0) events"
}

cap war        president dictator
cap trumpxi    tycoon    chairman
cap elvishogan king      wrestler
cap champsinger champ    singer

# yourface: a REAL selfie as the player paddle (swap the bundled char_player coin)
cp "$APP/char_player.png" /tmp/cp_backup.png
cp appstore/faces/fp_girl_cutout.png "$APP/char_player.png"
xcrun simctl install booted "$APP"
cap yourface "" president
cp /tmp/cp_backup.png "$APP/char_player.png"
xcrun simctl install booted "$APP" >/dev/null 2>&1
echo "ALL CAPTURES DONE"
