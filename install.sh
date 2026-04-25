#!/bin/bash

cd /home/pi

mkdir -p tavla
cd tavla

apt update
apt install -y python3-pip chromium-browser unclutter xserver-xorg xinit

pip3 install requests

cat <<EOF > status_kiosk.env
SERVER_BASE_URL=https://status.vantrum.se
DEVICE_ID=$(cat /sys/class/net/eth0/address | tr ':' '-')
DEVICE_TOKEN=REPLACE_TOKEN
VIEW_URL=https://status.vantrum.se/view
EOF

cat <<EOF > start_kiosk.sh
#!/bin/bash
export \$(grep -v '^#' /home/pi/tavla/status_kiosk.env | xargs)
xset -dpms
xset s off
xset s noblank
unclutter &
chromium-browser --kiosk "\$VIEW_URL"
EOF

chmod +x start_kiosk.sh

cat <<EOF > ota_client.py
import requests, time
while True:
    try:
        requests.post("https://status.vantrum.se/api/device/heartbeat")
    except:
        pass
    time.sleep(30)
EOF

reboot