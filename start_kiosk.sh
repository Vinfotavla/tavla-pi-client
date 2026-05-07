#!/bin/bash
APP_DIR="/home/pi/tavla"
ENV_FILE="$APP_DIR/status_kiosk.env"
BOOT_HTML="$APP_DIR/boot.html"
PAIRING_HTML="$APP_DIR/pairing.html"
LOG_FILE="$APP_DIR/vav.log"

log(){ echo "$(date '+%F %T') [kiosk] $*" >> "$LOG_FILE"; }

cat > "$BOOT_HTML" <<'HTML'
<!DOCTYPE html><html lang="sv"><head><meta charset="UTF-8"><meta http-equiv="refresh" content="10"><style>
html,body{margin:0;width:100%;height:100%;background:#07101f;color:white;font-family:Arial,system-ui;display:flex;align-items:center;justify-content:center;overflow:hidden}
.box{text-align:center;background:#111b31;border-radius:32px;padding:60px 80px;border:1px solid rgba(255,255,255,.15);box-shadow:0 25px 90px rgba(0,0,0,.45)}
.logo{font-size:64px;font-weight:900;margin-bottom:20px}.text{font-size:28px;color:#b8c7e0}.small{font-size:18px;color:#7f91ad;margin-top:22px}
</style></head><body><div class="box"><div class="logo">VäV</div><div class="text">Startar skärmen...</div><div class="small">Väntar på pairing/OTA</div></div></body></html>
HTML

VIEW_URL="file://$BOOT_HTML"
if [ -f "$ENV_FILE" ]; then source "$ENV_FILE"; fi
if [ -z "${VIEW_URL:-}" ]; then
  if [ -f "$PAIRING_HTML" ]; then VIEW_URL="file://$PAIRING_HTML"; else VIEW_URL="file://$BOOT_HTML"; fi
fi

log "startar chromium med VIEW_URL=$VIEW_URL"
pkill chromium >/dev/null 2>&1 || true
pkill chromium-browser >/dev/null 2>&1 || true
sleep 1
BROWSER="$(command -v chromium || command -v chromium-browser || true)"
if [ -z "$BROWSER" ]; then log "Hittar inte Chromium"; exit 1; fi
exec "$BROWSER" --kiosk --start-fullscreen --window-position=0,0 --window-size=1920,1080 --force-device-scale-factor=1 --disable-infobars --disable-session-crashed-bubble --disable-translate --disable-features=TranslateUI --noerrdialogs --no-first-run --autoplay-policy=no-user-gesture-required "$VIEW_URL"
