import os
import time
import socket
import requests
import subprocess

CONFIG = "/home/pi/tavla/status_kiosk.env"

def load_config():
    cfg = {}
    if os.path.exists(CONFIG):
        with open(CONFIG) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                cfg[k.strip()] = v.strip()
    return cfg

def run_command(cmd):
    if cmd in ("reload_view", "restart_kiosk"):
        subprocess.run(["sudo", "systemctl", "restart", "status-kiosk.service"], check=False)
    elif cmd == "reboot":
        subprocess.run(["sudo", "reboot"], check=False)
    elif cmd == "force_ota":
        subprocess.run(["sudo", "systemctl", "restart", "status-ota-client.service"], check=False)

while True:
    try:
        cfg = load_config()
        if "SERVER_BASE_URL" not in cfg:
            time.sleep(30)
            continue
        r = requests.post(
            cfg["SERVER_BASE_URL"].rstrip("/") + "/api/device/commands",
            json={
                "device_id": cfg.get("DEVICE_ID", socket.gethostname()),
                "token": cfg.get("DEVICE_TOKEN", ""),
            },
            timeout=10,
        )
        data = r.json()
        for item in data.get("commands", []):
            cmd = item.get("command") or item.get("type")
            if cmd:
                print("command:", cmd)
                run_command(cmd)
    except Exception as e:
        print("command error:", e)
    time.sleep(20)
