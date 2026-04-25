import os
import time
import socket
import requests
import subprocess

CONFIG = "/home/pi/tavla/status_kiosk.env"
VERSION_FILE = "/home/pi/tavla/version.txt"

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

def local_version():
    if os.path.exists(VERSION_FILE):
        return open(VERSION_FILE).read().strip()
    return "1.0.0"

def write_version(v):
    with open(VERSION_FILE, "w") as f:
        f.write(v)

def heartbeat(cfg):
    requests.post(
        cfg["SERVER_BASE_URL"].rstrip("/") + "/api/device/heartbeat",
        json={
            "device_id": cfg.get("DEVICE_ID", socket.gethostname()),
            "token": cfg.get("DEVICE_TOKEN", ""),
            "version": local_version(),
            "hostname": socket.gethostname(),
        },
        timeout=10,
    )

def ota_check(cfg):
    r = requests.post(
        cfg["SERVER_BASE_URL"].rstrip("/") + "/api/device/ota/check",
        json={
            "device_id": cfg.get("DEVICE_ID", socket.gethostname()),
            "token": cfg.get("DEVICE_TOKEN", ""),
            "version": local_version(),
        },
        timeout=10,
    )
    return r.json()

def install_package(cfg, url, version):
    full_url = url if url.startswith("http") else cfg["SERVER_BASE_URL"].rstrip("/") + url
    pkg = "/tmp/tavla_ota_package.tar.gz"
    with requests.get(full_url, stream=True, timeout=60) as r:
        r.raise_for_status()
        with open(pkg, "wb") as f:
            for chunk in r.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
    subprocess.run(["sudo", "systemctl", "stop", "status-kiosk.service"], check=False)
    subprocess.run(["tar", "-xzf", pkg, "-C", "/home/pi/tavla"], check=False)
    subprocess.run(["sudo", "systemctl", "start", "status-kiosk.service"], check=False)
    write_version(version)

while True:
    try:
        cfg = load_config()
        if "SERVER_BASE_URL" not in cfg:
            print("Saknar SERVER_BASE_URL")
            time.sleep(30)
            continue
        heartbeat(cfg)
        print("heartbeat ok")
        try:
            data = ota_check(cfg)
            if data.get("update") and data.get("url") and data.get("version"):
                print("OTA update:", data["version"])
                install_package(cfg, data["url"], data["version"])
        except Exception as e:
            print("ota check error:", e)
    except Exception as e:
        print("heartbeat error:", e)
    time.sleep(30)
