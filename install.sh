#!/bin/bash
set -euo pipefail

APP_DIR="/home/pi/tavla"
REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/Vinfotavla/tavla-pi-client/main}"
SERVER_BASE_URL="${SERVER_BASE_URL:-https://status.vantrum.se}"

echo "========================================"
echo " VäV Pi Client - ren installation v2"
echo "========================================"
echo "Server: $SERVER_BASE_URL"
echo "Repo:   $REPO_RAW_BASE"
echo ""

if [ "$(id -u)" -ne 0 ]; then
  echo "Kör med sudo:"
  echo "curl -fsSL $REPO_RAW_BASE/install.sh | sudo bash"
  exit 1
fi

PI_USER="${SUDO_USER:-pi}"
PI_HOME="$(getent passwd "$PI_USER" | cut -d: -f6 || true)"
if [ -z "$PI_HOME" ]; then
  PI_USER="pi"
  PI_HOME="/home/pi"
fi

echo "Använder Pi-användare: $PI_USER ($PI_HOME)"

export DEBIAN_FRONTEND=noninteractive

echo ""
echo "1/6 Installerar paket..."
apt-get update -y
apt-get install -y curl git python3 python3-requests xserver-xorg xinit x11-xserver-utils openbox unclutter cec-utils libraspberrypi-bin || true

if ! command -v chromium >/dev/null 2>&1 && ! command -v chromium-browser >/dev/null 2>&1; then
  apt-get install -y chromium || apt-get install -y chromium-browser
fi

echo ""
echo "2/6 Skapar katalog..."
mkdir -p "$APP_DIR"

download_or_copy() {
  local name="$1"
  if [ -f "./$name" ]; then
    cp "./$name" "$APP_DIR/$name"
  else
    curl -fsSL "$REPO_RAW_BASE/$name" -o "$APP_DIR/$name"
  fi
}

echo ""
echo "3/6 Hämtar klientfiler..."
download_or_copy "ota_client.py"
download_or_copy "start_kiosk.sh"
download_or_copy "command_client.py"

chmod +x "$APP_DIR/start_kiosk.sh" "$APP_DIR/ota_client.py" "$APP_DIR/command_client.py" || true

if [ ! -f "$APP_DIR/status_kiosk.env" ]; then
cat > "$APP_DIR/status_kiosk.env" <<ENV
SERVER_BASE_URL=$SERVER_BASE_URL
OTA_INTERVAL=15
DEVICE_ID=
DEVICE_TOKEN=
VIEW_URL=
PAIRING_CODE=
ENV
fi

chown -R "$PI_USER:$PI_USER" "$APP_DIR"

echo ""
echo "4/6 Skapar systemd-tjänster..."

cat > /etc/systemd/system/vav-ota-client.service <<SERVICE
[Unit]
Description=VäV OTA och pairing-klient
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$PI_USER
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
User=$PI_USER
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
User=$PI_USER
WorkingDirectory=$APP_DIR
Environment=HOME=$PI_HOME
Environment=XAUTHORITY=$PI_HOME/.Xauthority
ExecStart=/usr/bin/startx $APP_DIR/start_kiosk.sh -- :0 -nocursor -s 0 -dpms
Restart=always
RestartSec=5
TTYPath=/dev/tty1
StandardInput=tty
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE

echo ""
echo "5/6 Sätter startläge..."
systemctl daemon-reload
systemctl enable vav-ota-client.service
systemctl enable vav-command-client.service
systemctl enable vav-kiosk.service
raspi-config nonint do_boot_behaviour B2 >/dev/null 2>&1 || true
systemctl set-default multi-user.target >/dev/null 2>&1 || true

echo ""
echo "6/6 Startar tjänster..."
systemctl restart vav-ota-client.service
systemctl restart vav-command-client.service
systemctl restart vav-kiosk.service

echo ""
echo "========================================"
echo " KLART"
echo " Pi ska nu visa VäV pairing-kod på skärmen."
echo " Koppla i: https://status.vantrum.se/superadmin?tab=devices"
echo "========================================"
