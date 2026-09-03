#!/usr/bin/env python3
"""
ontario-osm-export.py — Pull a real Ontario road network from OpenStreetMap
as a .osm file, ready for CARLA (config.py --osm-path) or BeamNG.drive (MapNG).

What it does (replaces the manual OSM.org Export + Overpass fallback):
  1. Geocodes a place name (e.g. "Barrie") to a bounding box via Nominatim.
  2. Queries the Overpass API for the drivable road network (highway ways).
  3. Writes a standard .osm XML file.
  4. Reports node/way counts + approximate area so you know if it's under the
     simulator's "memory blow-up" threshold.

Usage:
  python3 ontario-osm-export.py --city "Barrie" --radius 1.0
  python3 ontario-osm-export.py --city "Downtown Toronto" --out toronto.osm
  python3 ontario-osm-export.py --bbox 44.385,-79.700,44.395,-79.685
  python3 ontario-osm-export.py --lat 44.3894 --lon -79.6903 --radius 0.8

Notes:
  - Keep areas small initially (~1–4 km²). Whole metros will blow up procedural
    road generation in CARLA / MapNG.
  - The default --road-types filter keeps only drivable highways. Use
    --all-ways to include paths/cycleways too.
"""

import argparse
import math
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

NOMINATIM = "https://nominatim.openstreetmap.org/search"
OVERPASS = "https://overpass-api.de/api/interpreter"

ROAD_TYPES = (
    "motorway|motorway_link|trunk|trunk_link|primary|primary_link|"
    "secondary|secondary_link|tertiary|tertiary_link|unclassified|"
    "residential|living_street|service|road"
)

UA = "ontario-osm-export/1.0 (personal use; contact: none)"


def geocode(place):
    """Resolve a place name to (lat, lon, display_name)."""
    params = urllib.parse.urlencode({
        "q": f"{place}, Ontario, Canada",
        "format": "json",
        "limit": 1,
    })
    req = urllib.request.Request(f"{NOMINATIM}?{params}", headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = r.read().decode("utf-8")
    import json
    results = json.loads(data)
    if not results:
        sys.exit(f"❌ Could not geocode '{place}' (try a more specific name).")
    r = results[0]
    return float(r["lat"]), float(r["lon"]), r.get("display_name", place)


def bbox_from_center(lat, lon, radius_km):
    """Rough bounding box for a center point + radius (in km)."""
    dlat = radius_km / 110.574
    dlon = radius_km / (111.320 * math.cos(math.radians(lat)))
    return lat - dlat, lon - dlon, lat + dlat, lon + dlon


def area_km2(s, w, n, e):
    lat_km = (n - s) * 110.574
    lon_km = (e - w) * 111.320 * math.cos(math.radians((s + n) / 2))
    return abs(lat_km * lon_km)


def build_query(s, w, n, e, all_ways):
    if all_ways:
        way_filter = 'way["highway"]({s},{w},{n},{e});'
    else:
        way_filter = (
            f'way["highway"~"^({ROAD_TYPES})$"]({s},{w},{n},{e});'
        )
    return (
        "[out:xml][timeout:180];"
        f"{way_filter}"
        "(._;>;);"
        "out body;"
    )


def fetch_osm(query):
    data = urllib.parse.urlencode({"data": query}).encode("utf-8")
    req = urllib.request.Request(OVERPASS, data=data, headers={
        "User-Agent": UA,
        "Content-Type": "application/x-www-form-urlencoded",
    })
    with urllib.request.urlopen(req, timeout=300) as r:
        return r.read()


def summarize(osm_bytes):
    """Count nodes and ways, return (nodes, ways)."""
    root = ET.fromstring(osm_bytes)
    nodes = ways = 0
    for el in root:
        if el.tag == "node":
            nodes += 1
        elif el.tag == "way":
            ways += 1
    return nodes, ways


def main():
    ap = argparse.ArgumentParser(description="Export an Ontario road network from OSM.")
    ap.add_argument("--city", help="Place name, e.g. 'Barrie' or 'Downtown Toronto'")
    ap.add_argument("--lat", type=float, help="Center latitude")
    ap.add_argument("--lon", type=float, help="Center longitude")
    ap.add_argument("--radius", type=float, default=1.0,
                    help="Radius around center in km (default 1.0)")
    ap.add_argument("--bbox", help="south,west,north,east (decimal degrees)")
    ap.add_argument("--out", default="ontario_map.osm", help="Output .osm path")
    ap.add_argument("--all-ways", action="store_true",
                    help="Include all highway types (paths, cycleways, etc.)")
    args = ap.parse_args()

    # Resolve bounding box
    if args.bbox:
        try:
            s, w, n, e = [float(x) for x in args.bbox.split(",")]
        except ValueError:
            sys.exit("❌ --bbox must be south,west,north,east (4 comma-separated numbers).")
        label = f"bbox {s:.4f},{w:.4f},{n:.4f},{e:.4f}"
    elif args.lat is not None and args.lon is not None:
        s, w, n, e = bbox_from_center(args.lat, args.lon, args.radius)
        label = f"{args.lat:.4f},{args.lon:.4f} ±{args.radius} km"
    elif args.city:
        lat, lon, disp = geocode(args.city)
        s, w, n, e = bbox_from_center(lat, lon, args.radius)
        label = f"'{args.city}' ({lat:.4f},{lon:.4f} ±{args.radius} km)"
        print(f"📍 Geocoded: {disp}")
    else:
        ap.error("Provide one of --city, --lat/--lon, or --bbox.")

    area = area_km2(s, w, n, e)
    print(f"🗺️  Area: {label}")
    print(f"📐 Approx area: {area:.2f} km²")
    if area > 4.0:
        print(f"⚠️  > 4 km² — simulators may run out of memory. Consider a smaller radius.")

    print("⬇️  Querying Overpass API for road network...")
    t0 = time.time()
    query = build_query(s, w, n, e, args.all_ways)
    osm_bytes = fetch_osm(query)
    dt = time.time() - t0

    nodes, ways = summarize(osm_bytes)
    with open(args.out, "wb") as f:
        f.write(osm_bytes)

    print(f"✅ Done in {dt:.1f}s → {args.out}")
    print(f"   Nodes: {nodes:,}   Ways: {ways:,}   Size: {len(osm_bytes)/1024:.0f} KB")

    if ways == 0:
        print("⚠️  No roads found — try a larger radius or a more central location.")

    print("\nNext steps:")
    print("  CARLA:   python3 config.py --osm-path=" + args.out)
    print("  BeamNG:  upload to mapng.com → Export → BeamNG Level Package (.zip)")


if __name__ == "__main__":
    main()
