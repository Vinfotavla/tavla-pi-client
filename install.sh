#!/bin/bash
set -e

APP_DIR="/home/pi/tavla"
SERVER_BASE_URL="https://status.vantrum.se"

echo "Installerar VäV Pi-klient..."

sudo apt-get update -y
sudo apt-get install -y chromium unclutter x11-xserver-utils cec-utils curl python3-requests

mkdir -p "$APP_DIR"

# OTA klient
curl -fsSL https://raw.githubusercontent.com/Vinfotavla/tavla-pi-client/main/ota_client_pairing.py -o "$APP_DIR/ota_client.py"

# Kiosk script (FIXED chromium)
cat > "$APP_DIR/start_kiosk.sh" << 'EOF'
#!/bin/bash

export DISPLAY=:0
export XAUTHORITY=/home/pi/.Xauthority

xset s off || true
xset -dpms || true
xset s noblank || true

pkill unclutter || true
unclutter -idle 0.2 -root &

VIEW_URL=""
[ -f /home/pi/tavla/status_kiosk.env ] && source /home/pi/tavla/status_kiosk.env

pkill chromium || true
sleep 2

chromium \
  --kiosk \
  --start-fullscreen \
  --window-position=0,0 \
  --window-size=1920,1080 \
  --force-device-scale-factor=1 \
  --no-first-run \
  "$VIEW_URL"
EOF

chmod +x "$APP_DIR/start_kiosk.sh"

cat > "$APP_DIR/status_kiosk.env" << ENV
SERVER_BASE_URL=$SERVER_BASE_URL
OTA_INTERVAL=15
DEVICE_ID=
DEVICE_TOKEN=
VIEW_URL=
ENV

# systemd
sudo tee /etc/systemd/system/vav-ota-client.service > /dev/null << SERVICE
[Unit]
Description=VäV OTA Client
After=network-online.target

[Service]
User=pi
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/python3 $APP_DIR/ota_client.py
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

sudo tee /etc/systemd/system/vav-kiosk.service > /dev/null << SERVICE
[Unit]
Description=VäV Kiosk
After=graphical.target

[Service]
User=pi
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/start_kiosk.sh
Restart=always

[Install]
WantedBy=graphical.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable vav-ota-client
sudo systemctl enable vav-kiosk
sudo systemctl restart vav-ota-client
sudo systemctl restart vav-kiosk

echo "KLART"