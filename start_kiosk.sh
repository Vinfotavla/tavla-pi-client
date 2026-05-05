#!/bin/bash
set -e
APP_DIR="/home/pi/tavla"
ENV_FILE="$APP_DIR/status_kiosk.env"

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-/home/pi/.Xauthority}"

xset s off || true
xset -dpms || true
xset s noblank || true

pkill unclutter || true
unclutter -idle 0.2 -root &

VIEW_URL=""
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
fi
[ -z "${VIEW_URL:-}" ] && VIEW_URL="about:blank"

pkill chromium || true
pkill chromium-browser || true
sleep 2

BROWSER="$(command -v chromium || command -v chromium-browser || true)"
if [ -z "$BROWSER" ]; then
  echo "FEL: Hittar varken chromium eller chromium-browser"
  exit 1
fi

exec "$BROWSER" \
  --kiosk \
  --start-fullscreen \
  --window-position=0,0 \
  --window-size=1920,1080 \
  --force-device-scale-factor=1 \
  --high-dpi-support=1 \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-features=TranslateUI \
  --no-first-run \
  --noerrdialogs \
  --autoplay-policy=no-user-gesture-required \
  "$VIEW_URL"
