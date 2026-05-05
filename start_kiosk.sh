#!/bin/bash
set -e

APP_DIR="/home/pi/tavla"
ENV_FILE="$APP_DIR/status_kiosk.env"

export DISPLAY=:0
export XAUTHORITY="${XAUTHORITY:-/home/pi/.Xauthority}"

xset s off || true
xset -dpms || true
xset s noblank || true

pkill unclutter >/dev/null 2>&1 || true
unclutter -idle 0.2 -root >/dev/null 2>&1 &

VIEW_URL="about:blank"
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
fi

if [ -z "${VIEW_URL:-}" ]; then
  VIEW_URL="about:blank"
fi

pkill chromium >/dev/null 2>&1 || true
pkill chromium-browser >/dev/null 2>&1 || true
sleep 2

BROWSER="$(command -v chromium || command -v chromium-browser || true)"
if [ -z "$BROWSER" ]; then
  echo "Hittar varken chromium eller chromium-browser"
  sleep 30
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
  --disable-translate \
  --disable-features=TranslateUI \
  --no-first-run \
  --autoplay-policy=no-user-gesture-required \
  "$VIEW_URL"
