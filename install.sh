#!/bin/bash
set -e

APP_DIR="/home/pi/tavla"

echo "====================================="
echo " VäV Pi Client v5"
echo " Stabil kiosk-start för Pi OS 13"
echo "====================================="

sudo apt update

sudo apt install -y \
  chromium \
  openbox \
  unclutter \
  xserver-xorg \
  x11-xserver-utils \
  xinit \
  curl \
  python3 \
  python3-requests \
  raspi-utils-core \
  raspi-utils-dt

mkdir -p $APP_DIR

curl -fsSL https://raw.githubusercontent.com/Vinfotavla/tavla-pi-client/main/start_kiosk.sh -o $APP_DIR/start_kiosk.sh
curl -fsSL https://raw.githubusercontent.com/Vinfotavla/tavla-pi-client/main/ota_client.py -o $APP_DIR/ota_client.py
curl -fsSL https://raw.githubusercontent.com/Vinfotavla/tavla-pi-client/main/command_client.py -o $APP_DIR/command_client.py

chmod +x $APP_DIR/start_kiosk.sh

cat > $APP_DIR/status_kiosk.env <<ENV
SERVER_BASE_URL=https://status.vantrum.se
OTA_INTERVAL=15
DEVICE_ID=
DEVICE_TOKEN=
VIEW_URL=
PAIRING_CODE=
ENV

mkdir -p /home/pi/.config/openbox

cat > /home/pi/.config/openbox/autostart <<AUTO
xset s off
xset -dpms
xset s noblank
unclutter -idle 0 &
/home/pi/tavla/start_kiosk.sh &
AUTO

cat > /etc/systemd/system/vav-ota-client.service <<SERVICE
[Unit]
Description=VäV OTA Client
After=network-online.target

[Service]
User=pi
WorkingDirectory=/home/pi/tavla
ExecStart=/usr/bin/python3 /home/pi/tavla/ota_client.py
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable vav-ota-client.service
sudo systemctl restart vav-ota-client.service

sudo raspi-config nonint do_boot_behaviour B4

if ! grep -q "openbox-session" /home/pi/.bash_profile 2>/dev/null; then
cat >> /home/pi/.bash_profile <<BASH

if [ -z "\$DISPLAY" ] && [ "\$(tty)" = "/dev/tty1" ]; then
  startx /usr/bin/openbox-session -- :0
fi
BASH
fi

echo "KLART"
echo "Starta om Pi:"
echo "sudo reboot"
