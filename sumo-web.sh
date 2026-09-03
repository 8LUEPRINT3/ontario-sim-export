#!/usr/bin/env bash
set -euo pipefail

# sumo-web.sh — run sumo-gui headlessly and serve it to ANY browser via noVNC.
# Usage: ./sumo-web.sh [config.sumocfg]
# Then open the printed URL (e.g. http://<ubuntu-ip>:6080/vnc.html) in your
# Windows browser to see and control the simulation. No GPU required.

CFG="${1:-ontario.sumocfg}"
if [ ! -f "$CFG" ]; then
  echo "❌ $CFG not found. Run ./osm2sumo.sh first."
  exit 1
fi

VNCPORT="${VNCPORT:-5900}"
WEBPORT="${WEBPORT:-6080}"

# 1. Virtual display (Xvfb — no GPU needed)
if ! pgrep -x Xvfb >/dev/null; then
  Xvfb :99 -screen 0 1280x800x24 &
  sleep 1
fi
export DISPLAY=:99

# 2. sumo-gui on the virtual display
echo "🖥️  Launching sumo-gui on virtual display :99..."
sumo-gui -c "$CFG" &
sleep 3

# 3. VNC server on the virtual display
echo "📡 Starting VNC server on port $VNCPORT..."
x11vnc -display :99 -forever -shared -nopw -quiet -rfbport "$VNCPORT" &

# 4. noVNC (web bridge) on port $WEBPORT
echo "🌐 Starting noVNC web server on port $WEBPORT..."
websockify --web /usr/share/novnc/ "$WEBPORT" localhost:"$VNCPORT" &
sleep 2

IP="$(hostname -I | awk '{print $1}')"
echo ""
echo "=================================================="
echo "  🎮 SUMO is live — open this in your browser:"
echo ""
echo "     http://$IP:$WEBPORT/vnc.html"
echo ""
echo "  Click 'Connect' (no password)."
echo "  Press Ctrl+C here to stop everything."
echo "=================================================="
echo ""

wait
