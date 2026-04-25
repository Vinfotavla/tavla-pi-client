import os, time, socket, requests

CONFIG = "/home/pi/tavla/status_kiosk.env"
VERSION_FILE = "/home/pi/tavla/version.txt"

def load_config():
    cfg = {}
    if os.path.exists(CONFIG):
        for line in open(CONFIG):
            line=line.strip()
            if line and not line.startswith("#") and "=" in line:
                k,v=line.split("=",1)
                cfg[k.strip()] = v.strip()
    return cfg

def version():
    return open(VERSION_FILE).read().strip() if os.path.exists(VERSION_FILE) else "1.0.0"

while True:
    try:
        c = load_config()
        requests.post(
            c["SERVER_BASE_URL"].rstrip("/") + "/api/device/heartbeat",
            json={
                "device_id": c.get("DEVICE_ID", socket.gethostname()),
                "token": c.get("DEVICE_TOKEN", ""),
                "version": version(),
                "hostname": socket.gethostname(),
            },
            timeout=10
        )
        print("heartbeat ok")
    except Exception as e:
        print("heartbeat error:", e)
    time.sleep(30)
