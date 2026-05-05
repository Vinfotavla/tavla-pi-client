#!/bin/bash
set -euo pipefail
APP_DIR="/home/pi/tavla"
REPO_RAW="https://raw.githubusercontent.com/Vinfotavla/tavla-pi-client/main"
SERVER_BASE_URL="https://status.vantrum.se"

echo "Installerar VäV Pi-klient..."

if [ "$(id -u)" -ne 0 ]; then
  echo "Kör med sudo: curl ... | sudo bash"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y git curl ca-certificates python3 python3-requests xserver-xorg xinit openbox x11-xserver-utils unclutter cec-utils libraspberrypi-bin || true

if ! command -v chromium >/dev/null 2>&1 && ! command -v chromium-browser >/dev/null 2>&1; then
  apt-get install -y chromium || apt-get install -y chromium-browser || true
fi

if ! command -v chromium >/dev/null 2>&1 && ! command -v chromium-browser >/dev/null 2>&1; then
  echo "FEL: Hittar varken chromium eller chromium-browser efter installation."
  exit 1
fi

mkdir -p "$APP_DIR"

curl -fsSL "$REPO_RAW/start_kiosk.sh" -o "$APP_DIR/start_kiosk.sh"
curl -fsSL "$REPO_RAW/ota_client.py" -o "$APP_DIR/ota_client.py"
curl -fsSL "$REPO_RAW/command_client.py" -o "$APP_DIR/command_client.py"

python3 - <<'PY'
from pathlib import Path
for p in [Path("/home/pi/tavla/start_kiosk.sh"), Path("/home/pi/tavla/ota_client.py"), Path("/home/pi/tavla/command_client.py")]:
    if p.exists():
        data = p.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
        p.write_bytes(data)
PY

chmod +x "$APP_DIR/start_kiosk.sh" "$APP_DIR/ota_client.py" "$APP_DIR/command_client.py"
chown -R pi:pi "$APP_DIR"

if [ ! -f "$APP_DIR/status_kiosk.env" ]; then
  cat > "$APP_DIR/status_kiosk.env" <<ENV
SERVER_BASE_URL=$SERVER_BASE_URL
OTA_INTERVAL=15
DEVICE_ID=
DEVICE_TOKEN=
VIEW_URL=
ENV
  chown pi:pi "$APP_DIR/status_kiosk.env"
fi

cat > /etc/systemd/system/vav-ota-client.service <<SERVICE
[Unit]
Description=VäV OTA and pairing client
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=pi
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/python3 $APP_DIR/ota_client.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

cat > /etc/systemd/system/vav-command-client.service <<SERVICE
[Unit]
Description=VäV command client
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=pi
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/python3 $APP_DIR/command_client.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

cat > /etc/systemd/system/vav-kiosk.service <<SERVICE
[Unit]
Description=VäV Chromium kiosk
After=network-online.target vav-ota-client.service
Wants=network-online.target

[Service]
Type=simple
User=pi
WorkingDirectory=$APP_DIR
Environment=HOME=/home/pi
ExecStart=/usr/bin/startx $APP_DIR/start_kiosk.sh -- :0 -nocursor
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

systemctl set-default multi-user.target >/dev/null 2>&1 || true
systemctl daemon-reload
systemctl enable vav-ota-client.service
systemctl enable vav-command-client.service
systemctl enable vav-kiosk.service
systemctl restart vav-ota-client.service
systemctl restart vav-command-client.service || true
systemctl restart vav-kiosk.service

echo "KLART. Om inget visas inom 60 sek:"
echo "journalctl -u vav-ota-client -n 80 --no-pager"
echo "journalctl -u vav-kiosk -n 80 --no-pager"
