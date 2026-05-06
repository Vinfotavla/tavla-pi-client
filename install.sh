#!/bin/bash
set -euo pipefail

APP_DIR="/home/pi/tavla"
REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/Vinfotavla/tavla-pi-client/main}"
SERVER_BASE_URL="${SERVER_BASE_URL:-https://status.vantrum.se}"

echo "========================================"
echo " VäV Pi Client lightdm v6"
echo "========================================"

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

export DEBIAN_FRONTEND=noninteractive

echo "1/8 Stoppar gamla tjänster..."
systemctl stop vav-kiosk.service vav-ota-client.service vav-command-client.service status-kiosk.service lightdm >/dev/null 2>&1 || true
systemctl disable vav-kiosk.service status-kiosk.service >/dev/null 2>&1 || true

echo "2/8 Installerar grafik + Chromium..."
apt-get update -y
apt-get install -y curl git python3 python3-requests xserver-xorg x11-xserver-utils xinit lightdm openbox unclutter chromium cec-utils || true

if ! command -v chromium >/dev/null 2>&1 && ! command -v chromium-browser >/dev/null 2>&1; then
  apt-get install -y chromium-browser || true
fi

echo "3/8 Skapar katalog..."
mkdir -p "$APP_DIR"

download_or_copy() {
  local name="$1"
  if [ -f "./$name" ]; then
    cp "./$name" "$APP_DIR/$name"
  else
    curl -fsSL "$REPO_RAW_BASE/$name" -o "$APP_DIR/$name"
  fi
}

echo "4/8 Hämtar klientfiler..."
download_or_copy "ota_client.py"
download_or_copy "start_kiosk.sh"
download_or_copy "command_client.py"

chmod +x "$APP_DIR/start_kiosk.sh" "$APP_DIR/ota_client.py" "$APP_DIR/command_client.py"

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

echo "5/8 Konfigurerar LightDM autologin..."
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-vav-autologin.conf <<CONF
[Seat:*]
autologin-user=$PI_USER
autologin-user-timeout=0
user-session=openbox
xserver-command=X -s 0 -dpms
CONF

echo "6/8 Konfigurerar Openbox autostart..."
mkdir -p "$PI_HOME/.config/openbox"
cat > "$PI_HOME/.config/openbox/autostart" <<AUTO
xset s off
xset -dpms
xset s noblank
unclutter -idle 0.2 -root &
/home/pi/tavla/start_kiosk.sh &
AUTO
chown -R "$PI_USER:$PI_USER" "$PI_HOME/.config"

echo "7/8 Skapar OTA services..."
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

echo "8/8 Aktiverar..."
systemctl daemon-reload
systemctl enable lightdm
systemctl enable vav-ota-client.service
systemctl enable vav-command-client.service
systemctl set-default graphical.target >/dev/null 2>&1 || true
systemctl restart vav-ota-client.service
systemctl restart vav-command-client.service
systemctl restart lightdm

echo "========================================"
echo " KLART lightdm v6"
echo " Starta om vid behov: sudo reboot"
echo "========================================"
