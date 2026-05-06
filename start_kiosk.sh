#!/bin/bash

ENV_FILE="/home/pi/tavla/status_kiosk.env"

cat > /tmp/vav_boot.html <<HTML
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
html,body{
margin:0;
width:100%;
height:100%;
background:#07101f;
display:flex;
align-items:center;
justify-content:center;
font-family:Arial;
color:white;
overflow:hidden;
}
.box{
background:#111b31;
padding:60px;
border-radius:30px;
text-align:center;
}
.logo{
font-size:64px;
font-weight:bold;
margin-bottom:20px;
}
</style>
</head>
<body>
<div class="box">
<div class="logo">VäV</div>
<div>Startar skärmen...</div>
</div>
</body>
</html>
HTML

VIEW_URL="file:///tmp/vav_boot.html"

if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
fi

BROWSER=$(command -v chromium || command -v chromium-browser)

exec $BROWSER \
  --kiosk \
  --start-fullscreen \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  "$VIEW_URL"
