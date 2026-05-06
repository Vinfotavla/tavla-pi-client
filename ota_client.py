#!/usr/bin/env python3
import random
import socket
import string
import subprocess
import time
from pathlib import Path

import requests

APP_DIR = Path("/home/pi/tavla")
ENV_FILE = APP_DIR / "status_kiosk.env"
PAIRING_HTML = APP_DIR / "pairing.html"
VERSION_FILE = APP_DIR / "version.txt"

CLIENT_VERSION = "3.0-pairing-clean"

def log(*args):
    print("[VäV OTA]", *args, flush=True)

def run(cmd):
    return subprocess.call(cmd, shell=True)

def read_env():
    cfg = {}
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            cfg[k.strip()] = v.strip()
    return cfg

def write_env(cfg):
    ENV_FILE.write_text("".join(f"{k}={v}\n" for k, v in cfg.items()), encoding="utf-8")

def restart_kiosk():
    run("sudo systemctl restart vav-kiosk.service >/dev/null 2>&1 || true")

def get_device_id():
    cfg = read_env()
    if cfg.get("DEVICE_ID"):
        return cfg["DEVICE_ID"]

    mac = ""
    for iface in ("eth0", "wlan0"):
        try:
            mac = Path(f"/sys/class/net/{iface}/address").read_text().strip().replace(":", "")
            if mac:
                break
        except Exception:
            pass

    if not mac:
        mac = "".join(random.choice("0123456789abcdef") for _ in range(12))

    device_id = "vav-" + mac[-8:]
    cfg["DEVICE_ID"] = device_id
    write_env(cfg)
    return device_id

def get_pairing_code():
    cfg = read_env()
    if cfg.get("PAIRING_CODE"):
        return cfg["PAIRING_CODE"]

    code = "".join(random.choice(string.digits) for _ in range(6))
    cfg["PAIRING_CODE"] = code
    write_env(cfg)
    return code

def write_pairing_screen(code, server, device_id):
    html = f'''<!DOCTYPE html>
<html lang="sv">
<head>
<meta charset="UTF-8">
<meta http-equiv="refresh" content="15">
<style>
html,body {{
  margin:0;width:100%;height:100%;background:#07101f;color:white;
  font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
  display:flex;align-items:center;justify-content:center;overflow:hidden;
}}
.box {{
  text-align:center;background:linear-gradient(145deg,#111b31,#1a1232);
  border:1px solid rgba(255,255,255,.14);border-radius:34px;
  padding:60px 90px;box-shadow:0 25px 90px rgba(0,0,0,.45);
}}
.logo {{font-size:48px;font-weight:950;letter-spacing:.04em;margin-bottom:18px}}
.label {{font-size:30px;color:#b8c7e0;margin:10px 0}}
.code {{font-size:118px;font-weight:1000;letter-spacing:14px;color:#8ab4ff;margin:18px 0}}
.small {{font-size:18px;color:#7f91ad;margin-top:24px}}
</style>
</head>
<body>
<div class="box">
  <div class="logo">VäV</div>
  <div class="label">Ny skärm väntar på koppling</div>
  <div class="code">{code}</div>
  <div class="label">Superadmin → Skärmar → koppla koden</div>
  <div class="small">{device_id}<br>{server}</div>
</div>
</body>
</html>'''
    PAIRING_HTML.write_text(html, encoding="utf-8")

def set_view_url(url):
    cfg = read_env()
    if cfg.get("VIEW_URL") != url:
        cfg["VIEW_URL"] = url
        write_env(cfg)
        restart_kiosk()

def apply_display_state(display_on):
    if display_on:
        run("vcgencmd display_power 1 >/dev/null 2>&1 || true")
        run("DISPLAY=:0 xset dpms force on >/dev/null 2>&1 || true")
        run("echo 'on 0' | cec-client -s -d 1 >/dev/null 2>&1 || true")
        run("echo 'as' | cec-client -s -d 1 >/dev/null 2>&1 || true")
    else:
        run("DISPLAY=:0 xset dpms force off >/dev/null 2>&1 || true")
        run("vcgencmd display_power 0 >/dev/null 2>&1 || true")
        run("echo 'standby 0' | cec-client -s -d 1 >/dev/null 2>&1 || true")

def run_update(update_url):
    if not update_url:
        return
    log("Hämtar update:", update_url)
    run(f"curl -fsSL '{update_url}' -o /tmp/vav_update.sh && chmod +x /tmp/vav_update.sh && sudo bash /tmp/vav_update.sh")

def main():
    APP_DIR.mkdir(parents=True, exist_ok=True)
    VERSION_FILE.write_text(CLIENT_VERSION, encoding="utf-8")

    while True:
        try:
            cfg = read_env()
            server = cfg.get("SERVER_BASE_URL", "https://status.vantrum.se").rstrip("/")
            interval = int(cfg.get("OTA_INTERVAL", "15") or "15")
            device_id = get_device_id()

            if not cfg.get("DEVICE_TOKEN"):
                code = get_pairing_code()
                write_pairing_screen(code, server, device_id)
                set_view_url(f"file://{PAIRING_HTML}")

                requests.post(
                    f"{server}/api/device/register",
                    json={
                        "device_id": device_id,
                        "pairing_code": code,
                        "hostname": socket.gethostname(),
                        "name": socket.gethostname(),
                        "version": CLIENT_VERSION,
                    },
                    timeout=10,
                )

                status = requests.get(f"{server}/api/device/pairing-status/{device_id}", timeout=10).json()
                if status.get("status") == "paired":
                    cfg = read_env()
                    cfg["DEVICE_TOKEN"] = status.get("device_token") or device_id
                    cfg["VIEW_URL"] = status.get("view_url") or ""
                    cfg.pop("PAIRING_CODE", None)
                    write_env(cfg)
                    restart_kiosk()
            else:
                token = cfg["DEVICE_TOKEN"]
                data = requests.get(
                    f"{server}/ota/check",
                    headers={"Authorization": f"Bearer {token}"},
                    timeout=15,
                ).json()

                if data.get("view_url"):
                    set_view_url(data["view_url"])

                if "display_on" in data:
                    apply_display_state(bool(data["display_on"]))

                if data.get("update_url") and data.get("version") and str(data.get("version")) not in CLIENT_VERSION:
                    run_update(data["update_url"])

            time.sleep(interval)

        except Exception as e:
            log("Fel:", e)
            time.sleep(10)

if __name__ == "__main__":
    main()
