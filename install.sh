#!/bin/bash
set -e

echo "=== Tavla Pi Client installer ==="

APP_DIR="/home/pi/tavla"
REPO_DIR="/home/pi/tavla-pi-client"

sudo mkdir -p "$APP_DIR"
sudo chown -R pi:pi "$APP_DIR"

echo "Installerar paket..."
sudo apt update
sudo apt install -y python3 python3-requests chromium unclutter xserver-xorg xinit x11-xserver-utils

echo "Kopierar filer..."
cp "$REPO_DIR/start_kiosk.sh" "$APP_DIR/start_kiosk.sh"
cp "$REPO_DIR/ota_client.py" "$APP_DIR/ota_client.py"
cp "$REPO_DIR/command_client.py" "$APP_DIR/command_client.py"

if [ ! -f "$APP_DIR/status_kiosk.env" ]; then
  cp "$REPO_DIR/status_kiosk.env.example" "$APP_DIR/status_kiosk.env"
fi

chmod +x "$APP_DIR/start_kiosk.sh"

echo "Sätter timezone..."
sudo timedatectl set-timezone Europe/Stockholm || true
sudo timedatectl set-ntp true || true

echo "Skapar .xinitrc..."
cat > /home/pi/.xinitrc <<'EOF'
#!/bin/bash
exec /home/pi/tavla/start_kiosk.sh
EOF
chmod +x /home/pi/.xinitrc

echo "Installerar services..."
sudo cp "$REPO_DIR/services/status-kiosk.service" /etc/systemd/system/status-kiosk.service
sudo cp "$REPO_DIR/services/status-ota-client.service" /etc/systemd/system/status-ota-client.service
sudo cp "$REPO_DIR/services/status-command-client.service" /etc/systemd/system/status-command-client.service

sudo systemctl daemon-reload
sudo systemctl enable status-kiosk.service
sudo systemctl enable status-ota-client.service
sudo systemctl enable status-command-client.service

echo "Startar services..."
sudo systemctl restart status-ota-client.service || true
sudo systemctl restart status-command-client.service || true
sudo systemctl restart status-kiosk.service || true

echo "=== KLART ==="
echo "Kolla admin: https://status.vantrum.se/admin/devices"
