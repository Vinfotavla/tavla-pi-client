#!/bin/bash
set -e

CONFIG="/home/pi/tavla/status_kiosk.env"

if [ -f "$CONFIG" ]; then
  set -a
  . "$CONFIG"
  set +a
fi

VIEW_URL="${VIEW_URL:-https://status.vantrum.se/view}"

xset -dpms || true
xset s off || true
xset s noblank || true

unclutter -idle 0.5 -root &

CHROME_BIN="$(command -v chromium || command -v chromium-browser || true)"
if [ -z "$CHROME_BIN" ]; then
  echo "ERROR: Chromium hittades inte."
  exit 1
fi

exec "$CHROME_BIN" \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-features=TranslateUI \
  --autoplay-policy=no-user-gesture-required \
  --kiosk \
  --incognito \
  "$VIEW_URL"
