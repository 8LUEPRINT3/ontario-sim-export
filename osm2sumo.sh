#!/usr/bin/env bash
set -euo pipefail

# osm2sumo.sh — convert an exported .osm into a runnable SUMO simulation.
# Usage: ./osm2sumo.sh [input.osm] [prefix]
#   input.osm  (default: ontario_map.osm)
#   prefix     (default: ontario)  → produces <prefix>.net.xml, .rou.xml, .sumocfg

OSM="${1:-ontario_map.osm}"
PREFIX="${2:-ontario}"
export SUMO_HOME="${SUMO_HOME:-/usr/share/sumo}"
TOOLS="$SUMO_HOME/tools"
TYPEMAP="$SUMO_HOME/data/typemap/osmPolyconvert.typ.xml"

if [ ! -f "$OSM" ]; then
  echo "❌ $OSM not found. Export the roads first:"
  echo "   python3 ontario-osm-export.py --city \"Barrie\" --radius 1.0"
  exit 1
fi

echo "🛣️  1/4  Building road network (netconvert)..."
# Use the BARE command — the "guessing" flags (--roundabouts.guess,
# --ramps.guess, --junctions.join, --tls.*) trigger a known netconvert
# assertion crash (angle >= 0 && angle < 360) on real OSM data.
# Bare is the most reliable form and still imports the full road network.
netconvert --osm-files "$OSM" -o "$PREFIX.net.xml"

echo "🏘️  2/4  Extracting buildings/polygons (polyconvert)..."
if [ -f "$TYPEMAP" ]; then
  polyconvert --net-file "$PREFIX.net.xml" --osm-files "$OSM" \
    --type-file "$TYPEMAP" -o "$PREFIX.poly.xml" || echo "   (polyconvert skipped — non-fatal)"
else
  echo "   (no typemap found at $TYPEMAP — skipping polygons)"
fi

echo "🚗  3/4  Generating traffic (randomTrips)..."
if ! python3 "$TOOLS/randomTrips.py" -n "$PREFIX.net.xml" -r "$PREFIX.rou.xml" \
     -e 200 -p 1.5 --fringe-factor 5 2>/dev/null; then
  python3 "$TOOLS/randomTrips.py" -n "$PREFIX.net.xml" -r "$PREFIX.rou.xml" -e 200
fi

echo "📝  4/4  Writing config..."
cat > "$PREFIX.sumocfg" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <input>
    <net-file value="$PREFIX.net.xml"/>
    <route-files value="$PREFIX.rou.xml"/>
EOF
if [ -f "$PREFIX.poly.xml" ]; then
  printf '    <additional-files value="%s.poly.xml"/>\n' "$PREFIX" >> "$PREFIX.sumocfg"
fi
cat >> "$PREFIX.sumocfg" <<EOF
  </input>
  <time>
    <begin value="0"/>
    <end value="200"/>
  </time>
</configuration>
EOF

echo ""
echo "✅ Done. Created: $PREFIX.net.xml · $PREFIX.rou.xml · $PREFIX.sumocfg"
echo "   Run locally:     sumo-gui -c $PREFIX.sumocfg"
echo "   Serve to browser: ./sumo-web.sh $PREFIX.sumocfg"
