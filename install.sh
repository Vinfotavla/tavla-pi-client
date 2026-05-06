#!/bin/bash
set -euo pipefail

APP_DIR="/home/pi/tavla"
REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/Vinfotavla/tavla-pi-client/main}"
SERVER_BASE_URL="${SERVER_BASE_URL:-https://status.vantrum.se}"

echo "========================================"
echo " VäV Pi Client - ren installation v3"
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
echo "1/7 Stoppar gamla tjänster om de finns..."
systemctl stop vav-kiosk.service >/dev/null 2>&1 || true
systemctl stop vav-ota-client.service >/dev/null 2>&1 || true
systemctl stop vav-command-client.service >/dev/null 2>&1 || true
systemctl stop status-kiosk.service >/dev/null 2>&1 || true
systemctl disable status-kiosk.service >/dev/null 2>&1 || true

echo ""
echo "2/7 Installerar paket..."
apt-get update -y
apt-get install -y curl git python3 python3-requests xserver-xorg xinit x11-xserver-utils openbox unclutter cec-utils libraspberrypi-bin || true

if ! command -v chromium >/dev/null 2>&1 && ! command -v chromium-browser >/dev/null 2>&1; then
  apt-get install -y chromium || apt-get install -y chromium-browser
fi

echo ""
echo "3/7 Skapar katalog..."
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
echo "4/7 Hämtar klientfiler..."
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
echo "5/7 Sätter rättigheter för X från systemd..."
# Tillåt lokal användare att starta X utan aktiv GUI-session
if [ -f /etc/X11/Xwrapper.config ]; then
  sed -i 's/^allowed_users=.*/allowed_users=anybody/' /etc/X11/Xwrapper.config || true
  sed -i 's/^needs_root_rights=.*/needs_root_rights=yes/' /etc/X11/Xwrapper.config || true
else
  cat > /etc/X11/Xwrapper.config <<XWRAP
allowed_users=anybody
needs_root_rights=yes
XWRAP
fi

# Städa gamla X-lås om Pi tidigare hängt sig
rm -f /tmp/.X0-lock >/dev/null 2>&1 || true
rm -rf /tmp/.X11-unix/X0 >/dev/null 2>&1 || true

echo ""
echo "6/7 Skapar systemd-tjänster..."

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
Conflicts=getty@tty1.service

[Service]
Type=simple
User=$PI_USER
Group=$PI_USER
WorkingDirectory=$APP_DIR
Environment=HOME=$PI_HOME
Environment=XAUTHORITY=$PI_HOME/.Xauthority
Environment=DISPLAY=:0
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
StandardInput=tty
StandardOutput=journal
StandardError=journal
ExecStartPre=/bin/bash -lc 'rm -f /tmp/.X0-lock; rm -rf /tmp/.X11-unix/X0; pkill -f "Xorg.*:0" || true; pkill chromium || true; pkill chromium-browser || true'
ExecStart=/bin/bash -lc 'cd /home/pi/tavla && exec startx /home/pi/tavla/start_kiosk.sh -- :0 vt1 -keeptty -nocursor -s 0 -dpms'
Restart=always
RestartSec=7

[Install]
WantedBy=multi-user.target
SERVICE

echo ""
echo "7/7 Aktiverar och startar..."
systemctl daemon-reload
systemctl disable getty@tty1.service >/dev/null 2>&1 || true
systemctl enable vav-ota-client.service
systemctl enable vav-command-client.service
systemctl enable vav-kiosk.service
raspi-config nonint do_boot_behaviour B2 >/dev/null 2>&1 || true
systemctl set-default multi-user.target >/dev/null 2>&1 || true

systemctl restart vav-ota-client.service
systemctl restart vav-command-client.service
systemctl restart vav-kiosk.service

echo ""
echo "========================================"
echo " KLART v3"
echo " Pi ska nu visa VäV pairing-kod på skärmen."
echo " Koppla i: https://status.vantrum.se/superadmin?tab=devices"
echo ""
echo "Felsök vid behov:"
echo "  journalctl -u vav-kiosk -n 80 --no-pager"
echo "  journalctl -u vav-ota-client -n 80 --no-pager"
echo "========================================"
