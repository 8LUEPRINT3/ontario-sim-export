#!/usr/bin/env bash
set -euo pipefail

# sumo-tunnel.sh — run SUMO on Ubuntu and get a PUBLIC web link to open from
# anywhere (your Windows browser, phone, etc.) — no firewall config, no IP
# lookup. Uses Cloudflare's free quick tunnel (no account needed).
#
# Usage: ./sumo-tunnel.sh [config.sumocfg]

CFG="${1:-ontario.sumocfg}"
if [ ! -f "$CFG" ]; then
  echo "❌ $CFG not found. Run ./osm2sumo.sh first."
  exit 1
fi

VNCPORT="${VNCPORT:-5900}"
WEBPORT="${WEBPORT:-6080}"

# 1. Ensure cloudflared is installed
if ! command -v cloudflared >/dev/null 2>&1; then
  echo "📦 Installing cloudflared (free Cloudflare tunnel)..."
  curl -L --fail -o /tmp/cloudflared \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
  sudo install -m 755 /tmp/cloudflared /usr/local/bin/cloudflared
fi

# 2. Virtual display + sumo-gui + VNC + noVNC (same stack as sumo-web.sh)
if ! pgrep -x Xvfb >/dev/null; then
  Xvfb :99 -screen 0 1280x800x24 &
  sleep 1
fi
export DISPLAY=:99

echo "🖥️  Launching sumo-gui on virtual display :99..."
sumo-gui -c "$CFG" &
sleep 3

x11vnc -display :99 -forever -shared -nopw -quiet -rfbport "$VNCPORT" &
websockify --web /usr/share/novnc/ "$WEBPORT" localhost:"$VNCPORT" &
sleep 2

# 3. Public tunnel -> noVNC
echo "🌐 Opening public tunnel to SUMO..."
cloudflared tunnel --url "http://localhost:$WEBPORT" 2>&1 | tee /tmp/sumo-tunnel.log &
sleep 6

URL="$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/sumo-tunnel.log | head -1)"
if [ -n "$URL" ]; then
  echo ""
  echo "=================================================="
  echo "  🎮 SUMO is live on the internet — open this:"
  echo ""
  echo "     $URL/vnc.html"
  echo ""
  echo "  Works from ANY browser, ANY network."
  echo "  Press Ctrl+C here to stop everything."
  echo "=================================================="
  echo ""
else
  echo ""
  echo "  (Tunnel still starting — check the URL printed above, then add /vnc.html)"
  echo ""
fi

wait
