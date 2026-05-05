#!/usr/bin/env python3
import time, socket, random, string, subprocess
from pathlib import Path
import requests

APP_DIR = Path("/home/pi/tavla")
ENV_FILE = APP_DIR / "status_kiosk.env"
PAIRING_HTML = APP_DIR / "pairing.html"
VERSION = "1.4-pairing-fullscreen"

def log(*args):
    print("[VäV OTA]", *args, flush=True)

def run(cmd):
    return subprocess.call(cmd, shell=True)

def read_env():
    cfg = {}
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
            if line.strip() and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                cfg[k.strip()] = v.strip()
    return cfg

def write_env(cfg):
    ENV_FILE.write_text("".join(f"{k}={v}\n" for k, v in cfg.items()), encoding="utf-8")

def restart_kiosk():
    run("sudo systemctl restart vav-kiosk.service || true")

def get_device_id(cfg):
    if cfg.get("DEVICE_ID"):
        return cfg["DEVICE_ID"]
    mac = ""
    for nic in ["eth0", "wlan0"]:
        try:
            mac = Path(f"/sys/class/net/{nic}/address").read_text().strip().replace(":", "")
            if mac and mac != "000000000000":
                break
        except Exception:
            pass
    if not mac:
        mac = "".join(random.choice("0123456789abcdef") for _ in range(12))
    device_id = "vav-" + mac[-8:]
    cfg["DEVICE_ID"] = device_id
    write_env(cfg)
    return device_id

def get_pairing_code(cfg):
    if cfg.get("PAIRING_CODE"):
        return cfg["PAIRING_CODE"]
    code = "".join(random.choice(string.digits) for _ in range(6))
    cfg["PAIRING_CODE"] = code
    write_env(cfg)
    return code

def pairing_screen(code, server, device_id):
    html = f'''<!DOCTYPE html>
<html lang="sv"><head><meta charset="UTF-8"><meta http-equiv="refresh" content="15">
<style>
html,body{{margin:0;width:100%;height:100%;background:#07101f;color:white;font-family:Arial,sans-serif;display:flex;align-items:center;justify-content:center;overflow:hidden}}
.box{{text-align:center;background:#111b31;border:1px solid rgba(255,255,255,.16);border-radius:32px;padding:60px 80px;box-shadow:0 22px 90px rgba(0,0,0,.45)}}
.logo{{font-size:48px;font-weight:900;margin-bottom:22px}}.code{{font-size:116px;font-weight:900;letter-spacing:14px;color:#8ab4ff;margin:22px 0}}
p{{font-size:28px;color:#b8c7e0;margin:14px 0}}.small{{font-size:18px;color:#7c8ca8;margin-top:24px}}
</style></head><body><div class="box"><div class="logo">VäV</div><p>Ny skärm väntar på koppling</p><div class="code">{code}</div><p>Superadmin → Skärmar → koppla koden</p><div class="small">{device_id} · {server}</div></div></body></html>'''
    PAIRING_HTML.write_text(html, encoding="utf-8")

def apply_display_state(display_on):
    if display_on:
        run("vcgencmd display_power 1 || true")
        run("DISPLAY=:0 xset dpms force on || true")
        run("echo 'on 0' | cec-client -s -d 1 >/dev/null 2>&1 || true")
    else:
        run("DISPLAY=:0 xset dpms force off || true")
        run("vcgencmd display_power 0 || true")
        run("echo 'standby 0' | cec-client -s -d 1 >/dev/null 2>&1 || true")

def main():
    while True:
        try:
            cfg = read_env()
            server = (cfg.get("SERVER_BASE_URL") or "https://status.vantrum.se").rstrip("/")
            device_id = get_device_id(cfg)

            if not cfg.get("DEVICE_TOKEN"):
                code = get_pairing_code(cfg)
                pairing_screen(code, server, device_id)
                local_url = f"file://{PAIRING_HTML}"
                if cfg.get("VIEW_URL") != local_url:
                    cfg["VIEW_URL"] = local_url
                    write_env(cfg)
                    restart_kiosk()

                try:
                    requests.post(f"{server}/api/device/register", json={
                        "device_id": device_id, "pairing_code": code,
                        "hostname": socket.gethostname(), "name": socket.gethostname(),
                        "version": VERSION
                    }, timeout=12)
                except Exception as e:
                    log("register failed:", e)

                status = requests.get(f"{server}/api/device/pairing-status/{device_id}", timeout=12).json()
                if status.get("status") == "paired":
                    cfg["DEVICE_TOKEN"] = status.get("device_token") or device_id
                    cfg["VIEW_URL"] = status.get("view_url") or ""
                    cfg.pop("PAIRING_CODE", None)
                    write_env(cfg)
                    restart_kiosk()
            else:
                data = requests.get(f"{server}/ota/check", headers={"Authorization": f"Bearer {cfg['DEVICE_TOKEN']}"}, timeout=15).json()
                if data.get("view_url") and data.get("view_url") != cfg.get("VIEW_URL"):
                    cfg["VIEW_URL"] = data["view_url"]
                    write_env(cfg)
                    restart_kiosk()
                if "display_on" in data:
                    apply_display_state(bool(data["display_on"]))

            time.sleep(int(read_env().get("OTA_INTERVAL", "15")))
        except Exception as e:
            log("loop error:", e)
            time.sleep(15)

if __name__ == "__main__":
    main()
