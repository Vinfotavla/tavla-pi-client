#!/bin/bash
set -e

APP_DIR="/home/pi/tavla"
ENV_FILE="$APP_DIR/status_kiosk.env"
BOOT_HTML="$APP_DIR/boot.html"
PAIRING_HTML="$APP_DIR/pairing.html"

export DISPLAY=:0
export XAUTHORITY="${XAUTHORITY:-/home/pi/.Xauthority}"

openbox >/dev/null 2>&1 &

xset s off || true
xset -dpms || true
xset s noblank || true

pkill unclutter >/dev/null 2>&1 || true
unclutter -idle 0.2 -root >/dev/null 2>&1 &

cat > "$BOOT_HTML" <<'HTML'
<!DOCTYPE html>
<html lang="sv"><head><meta charset="UTF-8"><style>
html,body{margin:0;width:100%;height:100%;background:#07101f;color:white;font-family:system-ui;display:flex;align-items:center;justify-content:center;overflow:hidden}
.box{text-align:center;background:#111b31;border-radius:30px;padding:55px 75px;border:1px solid rgba(255,255,255,.14)}
.logo{font-size:52px;font-weight:950;margin-bottom:18px}
p{font-size:28px;color:#b8c7e0}.small{font-size:18px;color:#7f91ad}
</style></head><body><div class="box"><div class="logo">VäV</div><p>Startar skärmen...</p><div class="small">Väntar på pairing/OTA</div></div></body></html>
HTML

VIEW_URL="file://$BOOT_HTML"

if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
fi

if [ -z "${VIEW_URL:-}" ]; then
  if [ -f "$PAIRING_HTML" ]; then
    VIEW_URL="file://$PAIRING_HTML"
  else
    VIEW_URL="file://$BOOT_HTML"
  fi
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
  --disable-dev-shm-usage \
  --no-first-run \
  --noerrdialogs \
  --autoplay-policy=no-user-gesture-required \
  "$VIEW_URL"
