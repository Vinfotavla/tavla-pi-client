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
