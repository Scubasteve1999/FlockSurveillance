#!/usr/bin/env python3
"""Rebuild the Mid-South ALPR *count* snapshot from Overpass.

Does not edit OpenStreetMap or DeFlock. Does not call Flock vendor APIs.

Usage:
  python3 Scripts/build_midsouth_alpr_snapshot.py
  python3 Scripts/build_midsouth_alpr_snapshot.py --geojson /tmp/midsouth-alpr.geojson

City assignment uses OSM admin polygons (admin_level 8 / 6), not bounding boxes.
A full 800+ pin dump is optional and should not be committed; this repo vendors
runtime bundles (Sharing Network, Sensor Atlas, Olive Branch GATES), not research
camera dumps.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
import urllib.error
import urllib.request
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SUMMARY_PATH = ROOT / "docs" / "midsouth" / "alpr-snapshot-summary.json"

BBOX = (34.80, -90.25, 35.26, -89.60)  # south, west, north, east
QUERY = 'node["surveillance:type"="ALPR"](34.80,-90.25,35.26,-89.60);'

ENDPOINTS = (
    "https://overpass.openstreetmap.fr/api/interpreter",
    "https://overpass-api.de/api/interpreter",
    "https://overpass.osm.ch/api/interpreter",
)

USER_AGENT = "FlockSurveillance/1.5 (civic transparency; contact: flocksurveillance.com)"

# Display labels for the published table. Keys are (normalized name, admin_level, state).
PLACE_LABELS = {
    ("memphis", "8", "TN"): "Memphis",
    ("germantown", "8", "TN"): "Germantown",
    ("collierville", "8", "TN"): "Collierville",
    ("bartlett", "8", "TN"): "Bartlett",
    ("lakeland", "8", "TN"): "Lakeland",
    ("arlington", "8", "TN"): "Arlington",
    ("piperton", "8", "TN"): "Piperton",
    ("olive branch", "8", "MS"): "Olive Branch",
    ("southaven", "8", "MS"): "Southaven",
    ("horn lake", "8", "MS"): "Horn Lake",
    ("hernando", "8", "MS"): "Hernando",
    ("marion", "8", "AR"): "Marion AR",
    ("west memphis", "8", "AR"): "West Memphis",
}

COUNTY_LABELS = {
    ("shelby", "TN"): "Shelby County, TN",
    ("desoto", "MS"): "DeSoto County, MS",
    ("de soto", "MS"): "DeSoto County, MS",
    ("crittenden", "AR"): "Crittenden County, AR",
    ("fayette", "TN"): "Fayette County, TN",
    ("marshall", "MS"): "Marshall County, MS",
}

COUNTY_STATE = {
    "shelby": "TN",
    "desoto": "MS",
    "de soto": "MS",
    "crittenden": "AR",
    "fayette": "TN",
    "marshall": "MS",
    "tunica": "MS",
}

PLACE_STATE = {
    "memphis": "TN",
    "germantown": "TN",
    "collierville": "TN",
    "bartlett": "TN",
    "lakeland": "TN",
    "arlington": "TN",
    "piperton": "TN",
    "oakland": "TN",
    "hickory withe": "TN",
    "olive branch": "MS",
    "southaven": "MS",
    "horn lake": "MS",
    "hernando": "MS",
    "byhalia": "MS",
    "walls": "MS",
    "marion": "AR",
    "west memphis": "AR",
    "sunset": "AR",
    "clarkedale": "AR",
}

STATE_FROM_IS_IN = {
    "tennessee": "TN",
    "mississippi": "MS",
    "arkansas": "AR",
}

# Published 2026-08-14 densest-cluster seed (east Memphis / Germantown).
PUBLISHED_DENSEST = (35.10284, -89.85706)
# Goodman Rd (MS 302) / I-55 interchange, Southaven–Horn Lake.
GOODMAN_I55 = (34.9623, -89.9935)


def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return 2 * r * math.asin(min(1.0, math.sqrt(a)))


def point_in_ring(lat: float, lon: float, ring: list[tuple[float, float]]) -> bool:
    """Ray casting. ring is [(lat, lon), ...]; not necessarily closed."""
    if len(ring) < 3:
        return False
    inside = False
    x, y = lon, lat
    pts = ring + [ring[0]]
    for (y1, x1), (y2, x2) in zip(pts, pts[1:]):
        if (y1 > y) != (y2 > y):
            denom = (y2 - y1) or 1e-18
            xints = (x2 - x1) * (y - y1) / denom + x1
            if x < xints:
                inside = not inside
    return inside


def point_in_multipolygon(lat: float, lon: float, outers: list, inners: list) -> bool:
    if not any(point_in_ring(lat, lon, ring) for ring in outers):
        return False
    if any(point_in_ring(lat, lon, ring) for ring in inners):
        return False
    return True


def normalize_name(name: str) -> str:
    text = (name or "").strip().lower()
    for suffix in (
        " county",
        " parish",
        " city",
        " town",
        " township",
        " village",
    ):
        if text.endswith(suffix):
            text = text[: -len(suffix)].strip()
    return text


def is_flock(tags: dict[str, str]) -> bool:
    for key in ("manufacturer", "brand", "operator", "name", "ref"):
        if "flock" in (tags.get(key) or "").lower():
            return True
    return False


def overpass_post(query: str) -> dict:
    body = query.encode("utf-8")
    last_error: Exception | None = None
    for endpoint in ENDPOINTS:
        request = urllib.request.Request(
            endpoint,
            data=body,
            method="POST",
            headers={
                "Accept": "application/json",
                "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
                "User-Agent": USER_AGENT,
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=180) as resp:
                payload = json.loads(resp.read().decode("utf-8"))
            elements = payload.get("elements") or []
            if not elements:
                last_error = RuntimeError(f"{endpoint} returned no elements")
                continue
            return payload
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            last_error = exc
            continue
    raise RuntimeError(f"All Overpass mirrors failed: {last_error}")


def fetch_alpr_nodes() -> tuple[list[dict], str | None]:
    south, west, north, east = BBOX
    query = f"""
[out:json][timeout:180];
node["surveillance:type"="ALPR"]({south},{west},{north},{east});
out body;
"""
    payload = overpass_post(query)
    osm3s = payload.get("osm3s") or {}
    timestamp = osm3s.get("timestamp_osm_base")
    nodes = [
        el
        for el in payload.get("elements", [])
        if el.get("type") == "node" and el.get("lat") is not None
    ]
    return nodes, timestamp


def _coords_from_geom(geom: list[dict]) -> list[tuple[float, float]]:
    return [(float(pt["lat"]), float(pt["lon"])) for pt in geom if "lat" in pt and "lon" in pt]


def _endpoint_key(pt: tuple[float, float], ndigits: int = 7) -> tuple[float, float]:
    return (round(pt[0], ndigits), round(pt[1], ndigits))


def assemble_rings(lines: list[list[tuple[float, float]]]) -> list[list[tuple[float, float]]]:
    """Join OSM multipolygon ways that share endpoints into closed rings."""
    unused = [list(line) for line in lines if len(line) >= 2]
    rings: list[list[tuple[float, float]]] = []
    while unused:
        chain = unused.pop()
        progressed = True
        while progressed:
            progressed = False
            start = _endpoint_key(chain[0])
            end = _endpoint_key(chain[-1])
            if start == end and len(chain) >= 4:
                rings.append(chain)
                break
            for i, other in enumerate(unused):
                o_start = _endpoint_key(other[0])
                o_end = _endpoint_key(other[-1])
                if o_start == end:
                    chain.extend(other[1:])
                elif o_end == end:
                    chain.extend(reversed(other[:-1]))
                elif o_end == start:
                    chain = other + chain[1:]
                elif o_start == start:
                    chain = list(reversed(other)) + chain[1:]
                else:
                    continue
                unused.pop(i)
                progressed = True
                break
        else:
            if _endpoint_key(chain[0]) == _endpoint_key(chain[-1]) and len(chain) >= 4:
                rings.append(chain)
    return rings


def parse_admin_relation(el: dict) -> dict | None:
    tags = el.get("tags") or {}
    name = tags.get("name")
    level = tags.get("admin_level")
    if not name or level not in {"6", "8"}:
        return None
    outer_lines: list[list[tuple[float, float]]] = []
    inner_lines: list[list[tuple[float, float]]] = []
    for member in el.get("members") or []:
        role = member.get("role") or "outer"
        if role not in {"outer", "inner", ""}:
            continue
        ring = _coords_from_geom(member.get("geometry") or [])
        if len(ring) < 2:
            continue
        if role == "inner":
            inner_lines.append(ring)
        else:
            outer_lines.append(ring)
    outers = assemble_rings(outer_lines)
    inners = assemble_rings(inner_lines)
    if not outers:
        return None
    norm = normalize_name(name)
    is_in = (tags.get("is_in:state") or tags.get("addr:state") or "").upper()
    if len(is_in) != 2:
        for key in ("is_in",):
            raw = (tags.get(key) or "").lower()
            for word, abbr in STATE_FROM_IS_IN.items():
                if word in raw:
                    is_in = abbr
                    break
    if len(is_in) != 2:
        is_in = COUNTY_STATE.get(norm) or PLACE_STATE.get(norm) or ""
    return {
        "id": el.get("id"),
        "name": name,
        "norm": norm,
        "admin_level": level,
        "state": is_in,
        "outers": outers,
        "inners": inners,
    }


def fetch_admin_polygons() -> list[dict]:
    south, west, north, east = BBOX
    query = f"""
[out:json][timeout:180];
(
  relation["boundary"="administrative"]["admin_level"="8"]({south},{west},{north},{east});
  relation["boundary"="administrative"]["admin_level"="6"]({south},{west},{north},{east});
);
out geom;
"""
    payload = overpass_post(query)
    areas = []
    for el in payload.get("elements", []):
        if el.get("type") != "relation":
            continue
        parsed = parse_admin_relation(el)
        if parsed:
            areas.append(parsed)
    return areas


def containing_areas(lat: float, lon: float, areas: list[dict]) -> list[dict]:
    hits = []
    for area in areas:
        if point_in_multipolygon(lat, lon, area["outers"], area["inners"]):
            hits.append(area)
    return hits


def infer_state(hits: list[dict]) -> str | None:
    for area in hits:
        if area["admin_level"] == "6":
            st = area["state"] or COUNTY_STATE.get(area["norm"])
            if st in {"TN", "MS", "AR"}:
                return st
    for area in hits:
        st = area["state"] or PLACE_STATE.get(area["norm"])
        if st in {"TN", "MS", "AR"}:
            return st
    return None


def place_label(area: dict, state: str | None) -> str | None:
    if area["admin_level"] != "8":
        return None
    key = (area["norm"], "8", state or area["state"])
    if key in PLACE_LABELS:
        return PLACE_LABELS[key]
    if state:
        return f"{area['name']} {state}"
    return area["name"]


def county_label(area: dict, state: str | None) -> str | None:
    if area["admin_level"] != "6":
        return None
    st = state or area["state"]
    key = (area["norm"], st)
    if key in COUNTY_LABELS:
        return COUNTY_LABELS[key]
    if st:
        return f"{area['name']}, {st}"
    return area["name"]


def assign(node: dict, areas: list[dict]) -> tuple[str, str]:
    lat, lon = float(node["lat"]), float(node["lon"])
    hits = containing_areas(lat, lon, areas)
    state = infer_state(hits)
    places = [a for a in hits if a["admin_level"] == "8"]
    counties = [a for a in hits if a["admin_level"] == "6"]
    city = None
    if places:
        # Prefer a labeled core-city over a leftover incorporated place name.
        labeled = [place_label(a, state) for a in places]
        preferred = [label for label in labeled if label in PLACE_LABELS.values()]
        city = preferred[0] if preferred else labeled[0]
    if not city:
        city = f"unincorporated {state}" if state else "unincorporated"
    county = None
    if counties:
        county = county_label(counties[0], state)
    if not county:
        county = f"unincorporated {state}" if state else "unknown county"
    return city, county


def densest_cluster(nodes: list[dict], radius_m: float = 1609.34) -> tuple[dict, int]:
    best = nodes[0]
    best_count = 0
    coords = [(float(n["lat"]), float(n["lon"])) for n in nodes]
    for i, (lat, lon) in enumerate(coords):
        count = sum(1 for alat, alon in coords if haversine_m(lat, lon, alat, alon) <= radius_m)
        if count > best_count:
            best_count = count
            best = nodes[i]
    return best, best_count


def count_near(nodes: list[dict], lat: float, lon: float, radius_m: float = 1609.34) -> int:
    return sum(
        1
        for n in nodes
        if haversine_m(lat, lon, float(n["lat"]), float(n["lon"])) <= radius_m
    )


def build_summary(nodes: list[dict], areas: list[dict], osm_timestamp: str | None) -> dict:
    city_counts: Counter[str] = Counter()
    county_counts: Counter[str] = Counter()
    flock = 0
    assigned = []
    for node in nodes:
        city, county = assign(node, areas)
        city_counts[city] += 1
        county_counts[county] += 1
        tags = node.get("tags") or {}
        vendor = "Flock Safety" if is_flock(tags) else "other"
        if vendor == "Flock Safety":
            flock += 1
        assigned.append((node, city, county, vendor))

    densest_node, densest_count = densest_cluster(nodes)
    published_seed_count = count_near(nodes, *PUBLISHED_DENSEST)
    goodman_count = count_near(nodes, *GOODMAN_I55)

    by_city = dict(city_counts.most_common())
    by_county = dict(county_counts.most_common())

    notes = [
        "Count-only snapshot. Full pin GeoJSON is not committed.",
        "City assignment uses OSM admin polygons, not bounding boxes.",
    ]
    if osm_timestamp and not osm_timestamp.startswith("2026-08-14"):
        notes.append(
            f"Fresh pull osm_timestamp={osm_timestamp} differs from the 2026-08-14T23:18Z research pull."
        )

    return {
        "version": 1,
        "research_date": "2026-08-14",
        "snapshot_date": datetime.now(timezone.utc).date().isoformat(),
        "osm_timestamp": osm_timestamp,
        "query": QUERY,
        "bbox": {
            "south": BBOX[0],
            "west": BBOX[1],
            "north": BBOX[2],
            "east": BBOX[3],
        },
        "license": "ODbL",
        "attribution": (
            "Map data © OpenStreetMap contributors. DeFlock renders the same "
            "surveillance:type=ALPR nodes; it is not an independent coordinate database."
        ),
        "city_assignment": "OSM admin polygons (admin_level=8 place, admin_level=6 county), not bounding boxes.",
        "notes": notes,
        "total": len(nodes),
        "by_city": by_city,
        "by_county": by_county,
        "by_vendor": {
            "Flock Safety": flock,
            "other": len(nodes) - flock,
        },
        "clusters": {
            "densest_1mi": {
                "latitude": float(densest_node["lat"]),
                "longitude": float(densest_node["lon"]),
                "count": densest_count,
                "label": "recomputed densest 1-mile cluster (node-centered)",
            },
            "published_2026_08_14_seed": {
                "latitude": PUBLISHED_DENSEST[0],
                "longitude": PUBLISHED_DENSEST[1],
                "count": published_seed_count,
                "label": "east Memphis / Germantown (2026-08-14 published seed)",
            },
            "southaven_horn_lake_goodman_i55": {
                "latitude": GOODMAN_I55[0],
                "longitude": GOODMAN_I55[1],
                "count": goodman_count,
            },
        },
        "_assigned": assigned,
    }


def write_geojson(path: Path, assigned: list) -> None:
    features = []
    for node, city, county, vendor in assigned:
        tags = node.get("tags") or {}
        features.append(
            {
                "type": "Feature",
                "geometry": {
                    "type": "Point",
                    "coordinates": [float(node["lon"]), float(node["lat"])],
                },
                "properties": {
                    "osm_id": node.get("id"),
                    "city": city,
                    "county": county,
                    "vendor": vendor,
                    "manufacturer": tags.get("manufacturer"),
                    "operator": tags.get("operator"),
                    "name": tags.get("name"),
                },
            }
        )
    path.write_text(
        json.dumps(
            {
                "type": "FeatureCollection",
                "license": "ODbL",
                "attribution": "© OpenStreetMap contributors",
                "features": features,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--geojson",
        type=Path,
        help="Optional path for a full pin GeoJSON dump (do not commit).",
    )
    parser.add_argument(
        "--summary",
        type=Path,
        default=SUMMARY_PATH,
        help="Count-only JSON output path.",
    )
    args = parser.parse_args()

    print("Fetching ALPR nodes from Overpass…", file=sys.stderr)
    nodes, osm_timestamp = fetch_alpr_nodes()
    print(f"  {len(nodes)} nodes  osm_timestamp={osm_timestamp}", file=sys.stderr)
    print("Fetching admin polygons…", file=sys.stderr)
    areas = fetch_admin_polygons()
    print(f"  {len(areas)} admin relations with geometry", file=sys.stderr)

    summary = build_summary(nodes, areas, osm_timestamp)
    assigned = summary.pop("_assigned")
    args.summary.parent.mkdir(parents=True, exist_ok=True)
    args.summary.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {args.summary}", file=sys.stderr)
    print(json.dumps({"total": summary["total"], "by_city": summary["by_city"]}, indent=2))

    if args.geojson:
        write_geojson(args.geojson, assigned)
        print(f"Wrote {args.geojson} ({len(assigned)} features) — do not commit", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
