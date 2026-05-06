#!/bin/bash

APP_DIR="/home/pi/tavla"
ENV_FILE="$APP_DIR/status_kiosk.env"
BOOT_HTML="$APP_DIR/boot.html"
PAIRING_HTML="$APP_DIR/pairing.html"

cat > "$BOOT_HTML" <<'HTML'
<!DOCTYPE html>
<html lang="sv">
<head>
<meta charset="UTF-8">
<style>
html,body{margin:0;width:100%;height:100%;background:#07101f;color:white;font-family:Arial,system-ui;display:flex;align-items:center;justify-content:center;overflow:hidden}
.box{text-align:center;background:#111b31;border-radius:32px;padding:60px 80px;border:1px solid rgba(255,255,255,.15)}
.logo{font-size:64px;font-weight:900;margin-bottom:20px}
.text{font-size:28px;color:#b8c7e0}
</style>
</head>
<body><div class="box"><div class="logo">VäV</div><div class="text">Startar skärmen...</div></div></body>
</html>
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
sleep 1

BROWSER="$(command -v chromium || command -v chromium-browser || true)"
if [ -z "$BROWSER" ]; then
  echo "Hittar varken chromium eller chromium-browser"
  exit 1
fi

exec "$BROWSER" \
  --kiosk \
  --start-fullscreen \
  --window-position=0,0 \
  --window-size=1920,1080 \
  --force-device-scale-factor=1 \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --noerrdialogs \
  --no-first-run \
  --autoplay-policy=no-user-gesture-required \
  "$VIEW_URL"
