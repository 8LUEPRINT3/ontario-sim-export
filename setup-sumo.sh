#!/usr/bin/env bash
set -euo pipefail

# setup-sumo.sh — install everything needed to run SUMO headless and view it
# in a browser. Run ONCE on the Ubuntu machine (needs sudo).

echo "📦 Installing SUMO + noVNC web stack..."
sudo apt update
sudo apt install -y sumo sumo-tools sumo-doc xvfb x11vnc novnc websockify

echo ""
echo "✅ Installed. Next steps:"
echo "   1. Export roads:  python3 ontario-osm-export.py --city \"Barrie\" --radius 1.0"
echo "   2. Build sim:     ./osm2sumo.sh ontario_map.osm ontario"
echo "   3. Serve:         ./sumo-web.sh ontario.sumocfg"
echo "   4. Open the printed URL in your Windows browser."
echo ""
echo "   (Optional) public link from anywhere — ./sumo-tunnel.sh"
