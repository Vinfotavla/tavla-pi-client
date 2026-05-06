#!/usr/bin/env python3
import time
from pathlib import Path

env = Path("/home/pi/tavla/status_kiosk.env")

if not env.exists():
    env.write_text("""SERVER_BASE_URL=https://status.vantrum.se
OTA_INTERVAL=15
DEVICE_ID=
DEVICE_TOKEN=
VIEW_URL=
PAIRING_CODE=
""")

while True:
    time.sleep(30)
