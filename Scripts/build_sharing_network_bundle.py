#!/usr/bin/env python3
"""Build SharingNetworkBundle.json from DeFlock Dane FOIA dataset.

Usage:
  python3 Scripts/build_sharing_network_bundle.py
  python3 Scripts/build_sharing_network_bundle.py --input /path/to/dataset.json

Downloads https://deflockdane.org/shared-networks/dataset.json when --input is omitted.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

DATASET_URL = "https://deflockdane.org/shared-networks/dataset.json"
ATTRIBUTION_URL = "https://deflockdane.org/shared-networks/"

HUBS = {
    "waunakee": {
        "id": "waunakee",
        "name": "Waunakee WI PD",
        "shortName": "Waunakee",
        "latitude": 43.1919,
        "longitude": -89.4557,
    },
    "middleton": {
        "id": "middleton",
        "name": "Middleton WI PD",
        "shortName": "Middleton",
        "latitude": 43.0972,
        "longitude": -89.5043,
    },
    "grand-chute": {
        "id": "grand-chute",
        "name": "Grand Chute WI PD",
        "shortName": "Grand Chute",
        "latitude": 44.2786,
        "longitude": -88.4162,
    },
}

# Approximate geographic centroids for US states / DC.
STATE_CENTROIDS: dict[str, tuple[float, float]] = {
    "AL": (32.806671, -86.791130),
    "AK": (61.370716, -152.404419),
    "AZ": (33.729759, -111.431221),
    "AR": (34.969704, -92.373123),
    "CA": (36.116203, -119.681564),
    "CO": (39.059811, -105.311104),
    "CT": (41.597782, -72.755371),
    "DE": (39.318523, -75.507141),
    "DC": (38.897438, -77.026817),
    "FL": (27.766279, -81.686783),
    "GA": (33.040619, -83.643074),
    "HI": (21.094318, -157.498337),
    "ID": (44.240459, -114.478828),
    "IL": (40.349457, -88.986137),
    "IN": (39.849426, -86.258278),
    "IA": (42.011539, -93.210526),
    "KS": (38.526600, -96.726486),
    "KY": (37.668140, -84.670067),
    "LA": (31.169546, -91.867805),
    "ME": (44.693947, -69.381927),
    "MD": (39.063946, -76.802101),
    "MA": (42.230171, -71.530106),
    "MI": (43.326618, -84.536095),
    "MN": (45.694454, -93.900192),
    "MS": (32.741646, -89.678696),
    "MO": (38.456085, -92.288368),
    "MT": (46.921925, -110.454353),
    "NE": (41.125370, -98.268082),
    "NV": (38.313515, -117.055374),
    "NH": (43.452492, -71.563896),
    "NJ": (40.298904, -74.521011),
    "NM": (34.840515, -106.248482),
    "NY": (42.165726, -74.948051),
    "NC": (35.630066, -79.806419),
    "ND": (47.528912, -99.784012),
    "OH": (40.388783, -82.764915),
    "OK": (35.565342, -96.928917),
    "OR": (44.572021, -122.070938),
    "PA": (40.590752, -77.209755),
    "RI": (41.680893, -71.511780),
    "SC": (33.856892, -80.945007),
    "SD": (44.299782, -99.438828),
    "TN": (35.747845, -86.692345),
    "TX": (31.054487, -97.563461),
    "UT": (40.150032, -111.862434),
    "VT": (44.045876, -72.710686),
    "VA": (37.769337, -78.169968),
    "WA": (47.400902, -121.490494),
    "WV": (38.491226, -80.954453),
    "WI": (44.268543, -89.616508),
    "WY": (42.755966, -107.302490),
    "UNKNOWN": (39.8283, -98.5795),
}

DIRECTION_MAP = {
    "outgoing": "hubOut",
    "incoming": "hubIn",
    "bidirectional": "bidirectional",
}


def jittered_coordinate(state: str, partner_id: str) -> tuple[float, float]:
    lat, lon = STATE_CENTROIDS.get(state.upper(), STATE_CENTROIDS["UNKNOWN"])
    digest = hashlib.sha256(partner_id.encode("utf-8")).digest()
    # Deterministic ~±0.6° spread so arcs don't stack on one centroid.
    dlat = (digest[0] / 255.0 - 0.5) * 1.2
    dlon = (digest[1] / 255.0 - 0.5) * 1.2
    # Keep WI partners from sitting on hub cities.
    if state.upper() == "WI":
        dlat *= 1.4
        dlon *= 1.4
    return (round(lat + dlat, 5), round(lon + dlon, 5))


def load_dataset(path: Path | None) -> dict:
    if path is not None:
        with path.open() as f:
            return json.load(f)
    with urllib.request.urlopen(DATASET_URL, timeout=60) as resp:
        return json.load(resp)


def build_bundle(dataset: dict) -> dict:
    sources = []
    for src in dataset.get("sources", []):
        sources.append(
            {
                "key": src["key"],
                "label": src["label"],
                "releaseDate": src.get("release_date"),
                "shape": src.get("shape"),
                "rowCount": src.get("row_count"),
            }
        )

    hubs = []
    for key, hub in HUBS.items():
        src = next((s for s in dataset.get("sources", []) if s["key"] == key), None)
        hubs.append(
            {
                **hub,
                "releaseDate": src.get("release_date") if src else None,
                "sourceRowCount": src.get("row_count") if src else 0,
            }
        )

    partners = []
    for rec in dataset.get("records", []):
        state = (rec.get("state") or "UNKNOWN").upper()
        pid = str(rec.get("id") or rec.get("canonical") or rec.get("name"))
        lat, lon = jittered_coordinate(state, pid)
        hub_links = []
        for j in rec.get("jurisdictions") or []:
            if not j.get("present"):
                continue
            key = j.get("key")
            if key not in HUBS:
                continue
            direction = DIRECTION_MAP.get(j.get("direction") or "", "hubOut")
            hub_links.append(
                {
                    "hubId": key,
                    "direction": direction,
                    "inactive": bool(j.get("inactive")),
                }
            )
        if not hub_links:
            continue
        partners.append(
            {
                "id": pid,
                "name": rec.get("canonical") or rec.get("name") or "Unknown agency",
                "state": state,
                "entityType": rec.get("type") or "unknown",
                "latitude": lat,
                "longitude": lon,
                "inactive": bool(rec.get("inactive_any") or rec.get("inactive")),
                "membership": rec.get("membership") or "",
                "hubLinks": hub_links,
            }
        )

    # Stable order for diffs / testing.
    partners.sort(key=lambda p: (p["state"], p["name"], p["id"]))

    for hub in hubs:
        hub["partnerCount"] = sum(
            1
            for p in partners
            if not p["inactive"]
            and any(
                link["hubId"] == hub["id"] and not link["inactive"]
                for link in p["hubLinks"]
            )
        )

    return {
        "schemaVersion": "1.0.0",
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "sourceGeneratedAt": dataset.get("generated_at"),
        "attribution": {
            "title": "DeFlock Dane Shared Networks",
            "url": ATTRIBUTION_URL,
            "note": "Public FOIA / transparency-portal releases. Agency sharing links only — not which cameras feed which agency. Partner map positions are approximate (state-level).",
        },
        "sources": sources,
        "hubs": hubs,
        "partners": partners,
        "stats": {
            "partnerCount": len(partners),
            "hubCount": len(hubs),
        },
    }


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, help="Local dataset.json path")
    parser.add_argument(
        "--output",
        type=Path,
        default=root / "FlockSurveillance" / "Resources" / "SharingNetworkBundle.json",
    )
    args = parser.parse_args()

    dataset = load_dataset(args.input)
    bundle = build_bundle(dataset)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w") as f:
        json.dump(bundle, f, separators=(",", ":"), ensure_ascii=False)
        f.write("\n")

    size_kb = args.output.stat().st_size / 1024
    print(
        f"Wrote {args.output} ({size_kb:.0f} KB) — "
        f"{bundle['stats']['partnerCount']} partners, {bundle['stats']['hubCount']} hubs"
    )


if __name__ == "__main__":
    main()
