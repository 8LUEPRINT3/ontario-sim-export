# Ontario Road Geometry → Driving Simulator

Pull real-world Ontario road networks from OpenStreetMap and drive them in
**CARLA** (autonomous-research simulator) or **BeamNG.drive** (soft-body physics).

This repo automates the fiddly part — the OSM export — and documents the two
simulator ingestion paths.

---

## What you need

| Tool | Purpose | Notes |
| :--- | :--- | :--- |
| Python 3.6+ | Run the export script | stdlib only, no pip installs |
| Internet | Nominatim + Overpass API | free, no API key |
| CARLA (0.9.x) · BeamNG.drive · **SUMO** | The simulator itself | CARLA/BeamNG need GPU · **SUMO runs on CPU only** |

---

## Step 1 — Export the road network (automated)

```bash
# By city name (geocoded to Ontario, Canada automatically)
python3 ontario-osm-export.py --city "Barrie" --radius 1.0

# By exact coordinates (downtown Barrie ≈ 44.3894, -79.6903)
python3 ontario-osm-export.py --lat 44.3894 --lon -79.6903 --radius 0.7

# By a manual bounding box (south,west,north,east)
python3 ontario-osm-export.py --bbox 44.385,-79.700,44.395,-79.685
```

Output: a `.osm` file (default `ontario_map.osm`), plus a summary of nodes,
ways, area (km²), and file size.

**Area rule of thumb:** keep it under ~4 km² to start. Whole metros will blow
up procedural road generation in CARLA / MapNG.

**Why this beats the manual OSM.org Export button:** it hits the Overpass API
directly, so there's no "too many nodes" size error, and it filters to just
the drivable `highway` network (no buildings/POIs bloat).

---

## Step 2 — SUMO (free · CPU-only · runs on your GPU-less Ubuntu box)

SUMO is the best fit when you have **no GPU**: it's free, open-source, and
natively reads the `.osm` file your export tool just produced. It gives you
the real Ontario street layout with AI traffic flowing on it.

```bash
# One-time install
./setup-sumo.sh

# Convert your .osm → SUMO network + traffic + config (one command)
./osm2sumo.sh ontario_map.osm ontario

# Run it locally (sumo-gui uses software rendering, no GPU needed)
sumo-gui -c ontario.sumocfg
```

### 🌐 Run on Ubuntu, view in your Windows browser (noVNC)

This is the "set up on the Ubuntu box, drive it from your Windows browser" path.
`sumo-web.sh` starts a virtual display + VNC + noVNC web bridge, then prints a
link you open in any browser.

```bash
./sumo-web.sh ontario.sumocfg
```

It prints something like:

```
🎮 SUMO is live — open this in your browser:

   http://192.168.1.42:6080/vnc.html
```

Click that link in Chrome/Edge/Firefox on your Windows machine, hit **Connect**
(no password), and you get the full sumo-gui — pan/zoom the map, press **Play**
to start traffic, and drive a vehicle with the keyboard. Everything runs on the
Ubuntu CPU; the browser just shows the picture.

> **One-time firewall note:** if you can't reach the link from Windows, allow
> the port on Ubuntu: `sudo ufw allow 6080/tcp` (and `5900/tcp` if you use a
> native VNC client instead of the browser).

---

## Step 3A — Import into CARLA

CARLA has a built-in OpenDRIVE (`.xodr`) converter that turns OSM road vectors
into drivable asphalt meshes, traffic signals, and junction waypoints.

```bash
# 1. Launch the CARLA server
./CarlaUE4.sh

# 2. Ingest the .osm map directly
cd PythonAPI/util
python3 config.py --osm-path=/path/to/ontario_map.osm

# 3. Drive it
cd PythonAPI/examples
python3 manual_control.py
```

What CARLA does: reads the GPS coordinates, flattens them into a local metric
frame, extrudes road surfaces with correct lane widths, and spawns the world.

---

## Step 3B — Import into BeamNG.drive (MapNG)

1. Go to [mapng.com](https://mapng.com/)
2. Navigate to your Ontario city and select your bounding area
3. Elevation: **1m / standard terrain**, enable **"OSM features" / "Decal Roads"**
4. Click **Generate Data** → name it (e.g. `ontario_test_route`) → **Export → BeamNG Level Package (.zip)**
5. Move the `.zip` into your mods folder:
   - `%LOCALAPPDATA%\BeamNG.drive\current\mods\`
6. BeamNG → **Freeroam** → select the custom map → load with any car

The roads follow the exact GPS layout and turns from OpenStreetMap.

> MapNG reference: https://www.youtube.com/watch?v=kvjyySxpZNE

---

## Tips for realistic Ontario driving practice

- **Traffic in BeamNG:** press **Radial Menu (E) → AI → Spawn Traffic** (Normal / Rush Hour)
- **Metric check:** set your in-game speedo to **km/h** to match Ontario limits
  (50 urban · 80 rural · 100 on 400-series expressways)
- **Practice targets:** following distance, mirror checks, right-of-way at
  unsigned intersections, lane discipline through multi-lane junctions.

---

## Troubleshooting

| Symptom | Fix |
| :--- | :--- |
| `Could not geocode` | Use a more specific name, or pass `--lat` / `--lon` directly |
| `No roads found` | Increase `--radius` or move closer to a town center |
| Simulator runs out of memory | Shrink the area (< 4 km²); re-export |
| CARLA map looks flat/wrong | Check you used a small area; CARLA flattens GPS → local metric |
| BeamNG roads missing | Re-enable "OSM features / Decal Roads" in MapNG before export |
| SUMO browser link won't open | `sudo ufw allow 6080/tcp` on Ubuntu, then retry |
| SUMO framerate chugs (no GPU) | Shrink the area (< 2 km²); re-export |
