# VäV Tavla Pi Client v3

## Ny installation på Pi

Kör en rad:

```bash
curl -fsSL https://raw.githubusercontent.com/Vinfotavla/tavla-pi-client/main/install.sh | sudo bash
```

Pi:n ska visa en 6-siffrig pairing-kod.

Koppla skärmen i:

```text
https://status.vantrum.se/superadmin?tab=devices
```

## v3 fixar

- säkrare startx från systemd
- TTY1/getty-konflikt
- gamla X-lås
- chromium/chromium-browser fallback
- openbox startas före Chromium
- pairing + OTA
- fullscreen 1920x1080
