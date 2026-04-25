#!/usr/bin/env python3
import time
import subprocess
import requests

ENV_FILE = "/home/pi/tavla/status_kiosk.env"

def load_env():
    cfg = {}
    with open(ENV_FILE, "r") as f:
        for line in f:
            line = line.strip()
            if line and "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                cfg[k] = v
    return cfg

def save_env(cfg):
    with open(ENV_FILE, "w") as f:
        for k, v in cfg.items():
            f.write(f"{k}={v}\n")

def main():
    while True:
        try:
            cfg = load_env()
            server = cfg.get("SERVER_BASE_URL", "").rstrip("/")
            device_id = cfg.get("DEVICE_ID")

            if server and device_id:
                r = requests.get(
                    f"{server}/ota/check",
                    headers={"Authorization": f"Bearer {device_id}"},
                    timeout=15
                )

                data = r.json()
                new_url = data.get("view_url")

                if new_url and cfg.get("VIEW_URL") != new_url:
                    print("🔄 Uppdaterar VIEW_URL:", new_url)
                    cfg["VIEW_URL"] = new_url
                    save_env(cfg)

                    subprocess.run(
                        ["sudo", "systemctl", "restart", "status-kiosk.service"],
                        check=False
                    )

        except Exception as e:
            print("OTA error:", e)

        time.sleep(int(load_env().get("OTA_INTERVAL", "60")))

if __name__ == "__main__":
    main()