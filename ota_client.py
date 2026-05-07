#!/usr/bin/env python3
import random, socket, string, subprocess, time
from pathlib import Path
import requests

APP_DIR=Path("/home/pi/tavla")
ENV_FILE=APP_DIR/"status_kiosk.env"
PAIRING_HTML=APP_DIR/"pairing.html"
VERSION_FILE=APP_DIR/"version.txt"
LOG_FILE=APP_DIR/"vav.log"
CLIENT_VERSION="7.0-lightdm-auto-switch"

def log(*args):
    msg=" ".join(str(a) for a in args)
    print("[VäV OTA]", msg, flush=True)
    try:
        with LOG_FILE.open("a", encoding="utf-8") as f: f.write(time.strftime("%F %T")+" [ota] "+msg+"\n")
    except Exception: pass

def run(cmd): return subprocess.call(cmd, shell=True)

def read_env():
    cfg={}
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
            line=line.strip()
            if line and "=" in line and not line.startswith("#"):
                k,v=line.split("=",1); cfg[k.strip()]=v.strip()
    return cfg

def write_env(cfg):
    keys=["SERVER_BASE_URL","OTA_INTERVAL","DEVICE_ID","DEVICE_TOKEN","VIEW_URL","PAIRING_CODE","LAST_VIEW_URL"]
    out=[]
    for k in keys:
        if k in cfg: out.append((k,cfg[k]))
    for k,v in cfg.items():
        if k not in keys: out.append((k,v))
    ENV_FILE.write_text("".join(f"{k}={v}\n" for k,v in out), encoding="utf-8")

def restart_kiosk(reason=""):
    log("Startar om Chromium", reason)
    run("pkill chromium >/dev/null 2>&1 || true")
    run("pkill chromium-browser >/dev/null 2>&1 || true")

def device_id():
    cfg=read_env()
    if cfg.get("DEVICE_ID"): return cfg["DEVICE_ID"]
    mac=""
    for iface in ("eth0","wlan0"):
        try:
            mac=Path(f"/sys/class/net/{iface}/address").read_text().strip().replace(":","")
            if mac: break
        except Exception: pass
    if not mac: mac="".join(random.choice("0123456789abcdef") for _ in range(12))
    did="vav-"+mac[-8:]
    cfg["DEVICE_ID"]=did; write_env(cfg); return did

def code():
    cfg=read_env()
    if cfg.get("PAIRING_CODE"): return cfg["PAIRING_CODE"]
    c="".join(random.choice(string.digits) for _ in range(6))
    cfg["PAIRING_CODE"]=c; write_env(cfg); return c

def pairing_html(c, server, did):
    html=f'''<!DOCTYPE html><html lang="sv"><head><meta charset="UTF-8"><meta http-equiv="refresh" content="15"><style>
html,body{{margin:0;width:100%;height:100%;background:#07101f;color:white;font-family:Arial,system-ui;display:flex;align-items:center;justify-content:center;overflow:hidden}}
.box{{text-align:center;background:#111b31;border-radius:34px;padding:60px 90px;border:1px solid rgba(255,255,255,.15);box-shadow:0 25px 90px rgba(0,0,0,.45)}}
.logo{{font-size:54px;font-weight:900;margin-bottom:20px}}.label{{font-size:30px;color:#b8c7e0}}.code{{font-size:118px;font-weight:900;letter-spacing:14px;color:#8ab4ff;margin:22px 0}}.small{{font-size:18px;color:#7f91ad;margin-top:24px}}
</style></head><body><div class="box"><div class="logo">VäV</div><div class="label">Ny skärm väntar på koppling</div><div class="code">{c}</div><div class="label">Superadmin → Skärmar → koppla koden</div><div class="small">{did}<br>{server}</div></div></body></html>'''
    PAIRING_HTML.write_text(html, encoding="utf-8")

def set_url(url, force_restart=False):
    cfg=read_env()
    old=cfg.get("VIEW_URL") or ""
    last=cfg.get("LAST_VIEW_URL") or ""
    changed = old != url or last != url
    cfg["VIEW_URL"]=url; cfg["LAST_VIEW_URL"]=url
    write_env(cfg)
    if changed or force_restart: restart_kiosk("VIEW_URL="+url)

def display_state(on):
    if on:
        run("vcgencmd display_power 1 >/dev/null 2>&1 || true")
        run("DISPLAY=:0 xset dpms force on >/dev/null 2>&1 || true")
        run("echo 'on 0' | cec-client -s -d 1 >/dev/null 2>&1 || true")
        run("echo 'as' | cec-client -s -d 1 >/dev/null 2>&1 || true")
    else:
        run("DISPLAY=:0 xset dpms force off >/dev/null 2>&1 || true")
        run("vcgencmd display_power 0 >/dev/null 2>&1 || true")
        run("echo 'standby 0' | cec-client -s -d 1 >/dev/null 2>&1 || true")

def main():
    APP_DIR.mkdir(parents=True, exist_ok=True)
    VERSION_FILE.write_text(CLIENT_VERSION, encoding="utf-8")
    log("Start", CLIENT_VERSION)
    while True:
        try:
            cfg=read_env()
            server=cfg.get("SERVER_BASE_URL","https://status.vantrum.se").rstrip("/")
            interval=int(cfg.get("OTA_INTERVAL","10") or "10")
            did=device_id()
            if not cfg.get("DEVICE_TOKEN"):
                c=code(); pairing_html(c,server,did); set_url(f"file://{PAIRING_HTML}")
                try:
                    requests.post(f"{server}/api/device/register", json={"device_id":did,"pairing_code":c,"hostname":socket.gethostname(),"name":socket.gethostname(),"version":CLIENT_VERSION}, timeout=10)
                except Exception as e: log("register-fel", e)
                try:
                    r=requests.get(f"{server}/api/device/pairing-status/{did}", timeout=10).json()
                except Exception as e:
                    log("pairing-status-fel", e); r={}
                if r.get("status")=="paired":
                    cfg=read_env()
                    cfg["DEVICE_TOKEN"]=r.get("device_token") or did
                    cfg["VIEW_URL"]=r.get("view_url") or ""
                    cfg["LAST_VIEW_URL"]=""
                    cfg.pop("PAIRING_CODE",None)
                    write_env(cfg)
                    log("Kopplad VIEW_URL", cfg.get("VIEW_URL"))
                    restart_kiosk("pairing klar")
            else:
                token=cfg["DEVICE_TOKEN"]
                try:
                    r=requests.get(f"{server}/ota/check", headers={"Authorization":f"Bearer {token}"}, timeout=15).json()
                except Exception as e:
                    log("ota/check-fel", e); r={}
                if r.get("view_url"): set_url(r["view_url"])
                if "display_on" in r: display_state(bool(r["display_on"]))
            time.sleep(interval)
        except Exception as e:
            log("oväntat fel", e); time.sleep(10)

if __name__=="__main__":
    main()
