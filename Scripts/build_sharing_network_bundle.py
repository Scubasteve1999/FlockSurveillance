#!/usr/bin/env python3
"""Build or enrich SharingNetworkBundle.json.

Usage:
  python3 Scripts/build_sharing_network_bundle.py --enrich-existing
  python3 Scripts/build_sharing_network_bundle.py --input /path/to/dataset.json

`--enrich-existing` geocodes the already-bundled FOIA names (no DeFlock refetch)
against Census county and place gazetteers. Default path without --input still
downloads DeFlock; prefer --enrich-existing unless the snapshot itself changed.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import re
import urllib.request
import zipfile
from dataclasses import dataclass
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


CENSUS_COUNTY_URL = (
    "https://www2.census.gov/geo/docs/maps-data/data/gazetteer/"
    "2024_Gazetteer/2024_Gaz_counties_national.zip"
)
CENSUS_PLACE_URL = (
    "https://www2.census.gov/geo/docs/maps-data/data/gazetteer/"
    "2024_Gazetteer/2024_Gaz_place_national.zip"
)

COUNTY_EQUIV_SUFFIXES = (
    " county",
    " parish",
    " borough",
    " census area",
    " municipality",
    " city and borough",
)
PLACE_SUFFIXES = (
    " city",
    " village",
    " town",
    " cdp",
    " borough",
    " municipality",
    " township",
    " urban county",
)

COUNTY_NAME_RE = re.compile(
    r"(?P<name>[A-Za-z][A-Za-z .'-]*?)\s+(?:County|Parish)\b",
    re.I,
)
COUNTY_CO_RE = re.compile(
    r"(?P<name>[A-Za-z][A-Za-z .'-]*?)\s+Co\.?(?:\s|$)",
    re.I,
)
CITY_OF_RE = re.compile(
    r"^City of\s+(?P<name>.+?)(?:\s+[A-Z]{2})?$",
    re.I,
)
PLACE_BEFORE_AGENCY_RE = re.compile(
    r"""^(?P<name>.+?)\s+(
        Police\s+Department|
        Police\s+Dept\.?|
        Police|
        PD|
        Sheriff'?s?\s+(?:Office|Dept\.?|Department)|
        Sheriff|
        SO
    )\b""",
    re.I | re.X,
)
UNIV_PLACE_RE = re.compile(
    r"University of[^,-–]+[-–]\s*(?P<name>.+)$",
    re.I,
)
LEADING_STATE_RE = re.compile(r"^[A-Z]{2}\s*[-–:]\s*")
PAREN_STATE_RE = re.compile(r"\s*\([A-Z]{2}\)\s*")
NOISE_SUFFIX_RE = re.compile(
    r"\s*[-–]\s*(New Business|New|OLD|Inactive|Updated).*$",
    re.I,
)
TOWN_OF_RE = re.compile(
    r"\b(?:Village|Town|City|Township|Borough)\s+of\s+",
    re.I,
)

COUNTY_ALIASES = {
    "dade": "miami dade",
    "miami dade": "miami dade",
    "miami-dade": "miami dade",
    "st louis": "st louis",
    "saint louis": "st louis",
    "lasalle": "la salle",
    "dupage": "du page",
    "dekalb": "de kalb",
    "mchenry": "mc henry",
    "mclean": "mc lean",
    "desoto": "de soto",
    "lamoure": "la moure",
}


@dataclass(frozen=True)
class GazetteerRow:
    state: str
    name: str
    key: str
    latitude: float
    longitude: float


@dataclass(frozen=True)
class GeocodeResult:
    latitude: float
    longitude: float
    county: str | None
    place_name: str | None
    method: str


def normalize_key(value: str) -> str:
    text = value.lower().replace("&", " and ")
    text = text.replace("saint ", "st ")
    text = text.replace("st. ", "st ")
    text = text.replace("ft. ", "ft ")
    text = text.replace("fort ", "ft ")
    text = re.sub(r"[^a-z0-9 ]+", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return COUNTY_ALIASES.get(text, text)


def strip_known_suffix(value: str, suffixes: tuple[str, ...]) -> str:
    lower = value.lower()
    for suffix in suffixes:
        if lower.endswith(suffix):
            return value[: -len(suffix)].strip()
    return value


def download_cached(url: str, dest: Path) -> Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size > 0:
        return dest
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "FlockSurveillance/1.8 (civic transparency; gazetteer cache)"},
    )
    with urllib.request.urlopen(request, timeout=120) as resp:
        dest.write_bytes(resp.read())
    return dest


def read_gazetteer_table(zip_path: Path) -> list[dict[str, str]]:
    with zipfile.ZipFile(zip_path) as archive:
        name = next(n for n in archive.namelist() if n.endswith(".txt"))
        raw = archive.read(name)
    text = raw.decode("latin-1")
    reader = csv.DictReader(io.StringIO(text), delimiter="\t")
    rows = []
    for row in reader:
        rows.append({(key or "").strip(): (value or "").strip() for key, value in row.items()})
    return rows


def load_gazetteer(cache_dir: Path) -> tuple[dict[str, list[GazetteerRow]], dict[str, list[GazetteerRow]]]:
    county_zip = download_cached(CENSUS_COUNTY_URL, cache_dir / "2024_Gaz_counties_national.zip")
    place_zip = download_cached(CENSUS_PLACE_URL, cache_dir / "2024_Gaz_place_national.zip")

    counties: dict[str, list[GazetteerRow]] = {}
    for row in read_gazetteer_table(county_zip):
        state = (row.get("USPS") or "").strip().upper()
        name = strip_known_suffix((row.get("NAME") or "").strip(), COUNTY_EQUIV_SUFFIXES)
        if not state or not name:
            continue
        lat = float(row["INTPTLAT"])
        lon = float(row["INTPTLONG"])
        counties.setdefault(state, []).append(
            GazetteerRow(state, name, normalize_key(name), lat, lon)
        )

    places: dict[str, list[GazetteerRow]] = {}
    for row in read_gazetteer_table(place_zip):
        state = (row.get("USPS") or "").strip().upper()
        raw_name = (row.get("NAME") or "").strip()
        name = strip_known_suffix(raw_name, PLACE_SUFFIXES)
        if not state or not name:
            continue
        lat = float(row["INTPTLAT"])
        lon = float(row["INTPTLONG"])
        places.setdefault(state, []).append(
            GazetteerRow(state, name, normalize_key(name), lat, lon)
        )

    return counties, places


def lookup_row(rows: list[GazetteerRow], candidate: str) -> GazetteerRow | None:
    key = normalize_key(candidate)
    if not key:
        return None
    exact = [row for row in rows if row.key == key]
    if len(exact) == 1:
        return exact[0]
    if len(exact) > 1:
        return min(exact, key=lambda row: len(row.name))
    # Prefix only when the candidate is long enough to stay confident.
    if len(key) < 5:
        return None
    prefixed = [row for row in rows if row.key.startswith(key) or key.startswith(row.key)]
    if len(prefixed) == 1:
        return prefixed[0]
    return None


def nearest_county(
    state: str,
    latitude: float,
    longitude: float,
    counties: dict[str, list[GazetteerRow]],
) -> GazetteerRow | None:
    rows = counties.get(state.upper(), [])
    if not rows:
        return None
    return min(
        rows,
        key=lambda row: (row.latitude - latitude) ** 2 + (row.longitude - longitude) ** 2,
    )


def scrub_agency_name(name: str, state: str) -> str:
    text = NOISE_SUFFIX_RE.sub("", name).strip()
    text = PAREN_STATE_RE.sub(" ", text)
    text = LEADING_STATE_RE.sub("", text).strip()
    state_key = (state or "").upper()
    if state_key and len(state_key) == 2:
        text = re.sub(rf"\s+{re.escape(state_key)}\s+", " ", text, flags=re.I)
        text = re.sub(rf"\s+{re.escape(state_key)}$", "", text, flags=re.I)
    return re.sub(r"\s+", " ", text).strip(" -")


def extract_county_candidate(name: str) -> str | None:
    for pattern in (COUNTY_NAME_RE, COUNTY_CO_RE):
        match = pattern.search(name)
        if match:
            candidate = match.group("name").strip(" -")
            if candidate:
                return candidate
    return None


def extract_place_candidate(name: str, entity_type: str) -> str | None:
    city = CITY_OF_RE.match(name)
    if city:
        return city.group("name").strip(" -")
    univ = UNIV_PLACE_RE.search(name)
    if univ:
        return univ.group("name").strip(" -")
    place = PLACE_BEFORE_AGENCY_RE.match(name)
    if place:
        token = place.group("name").strip(" -")
        token = TOWN_OF_RE.sub("", token)
        token = re.sub(
            r"\b(University of|College of|Dept of|Department of)\b",
            "",
            token,
            flags=re.I,
        ).strip(" -")
        if token:
            return token
    if entity_type == "county_sheriff":
        return extract_county_candidate(name) or name.split(",")[0].strip()
    return None


def geocode_partner(
    name: str,
    state: str,
    entity_type: str,
    counties: dict[str, list[GazetteerRow]],
    places: dict[str, list[GazetteerRow]],
) -> GeocodeResult:
    state_key = (state or "UNKNOWN").upper()
    fallback = STATE_CENTROIDS.get(state_key, STATE_CENTROIDS["UNKNOWN"])
    county_rows = counties.get(state_key, [])
    place_rows = places.get(state_key, [])
    cleaned = scrub_agency_name(name, state_key)

    county_candidate = extract_county_candidate(cleaned) or extract_county_candidate(name)
    if county_candidate:
        row = lookup_row(county_rows, county_candidate)
        if row:
            return GeocodeResult(
                latitude=round(row.latitude, 5),
                longitude=round(row.longitude, 5),
                county=row.name,
                place_name=None,
                method="county",
            )

    place_candidate = extract_place_candidate(cleaned, entity_type)
    if place_candidate:
        # Sheriff-style names without "County" still try the county table first.
        if entity_type == "county_sheriff":
            row = lookup_row(county_rows, place_candidate)
            if row:
                return GeocodeResult(
                    latitude=round(row.latitude, 5),
                    longitude=round(row.longitude, 5),
                    county=row.name,
                    place_name=None,
                    method="county",
                )
        row = lookup_row(place_rows, place_candidate)
        if row:
            county = nearest_county(state_key, row.latitude, row.longitude, counties)
            return GeocodeResult(
                latitude=round(row.latitude, 5),
                longitude=round(row.longitude, 5),
                county=county.name if county else None,
                place_name=row.name,
                method="place",
            )

    return GeocodeResult(
        latitude=round(fallback[0], 5),
        longitude=round(fallback[1], 5),
        county=None,
        place_name=None,
        method="none",
    )


def apply_geocode(
    partners: list[dict],
    counties: dict[str, list[GazetteerRow]],
    places: dict[str, list[GazetteerRow]],
) -> dict[str, int]:
    counts = {"county": 0, "place": 0, "none": 0}
    for partner in partners:
        result = geocode_partner(
            partner["name"],
            partner.get("state") or "UNKNOWN",
            partner.get("entityType") or "unknown",
            counties,
            places,
        )
        partner["latitude"] = result.latitude
        partner["longitude"] = result.longitude
        partner["county"] = result.county
        partner["placeName"] = result.place_name
        partner["geocode"] = result.method
        counts[result.method] += 1
    return counts


def attribution_note() -> str:
    return (
        "Public FOIA / transparency-portal releases. Agency sharing links only — "
        "not which cameras feed which agency. Map pins are inferred from the "
        "agency name (Census county or place), not a FOIA address."
    )


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
        fallback = STATE_CENTROIDS.get(state, STATE_CENTROIDS["UNKNOWN"])
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
                "latitude": fallback[0],
                "longitude": fallback[1],
                "county": None,
                "placeName": None,
                "geocode": "none",
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
            "note": attribution_note(),
        },
        "sources": sources,
        "hubs": hubs,
        "partners": partners,
        "stats": {
            "partnerCount": len(partners),
            "hubCount": len(hubs),
        },
    }


def enrich_existing_bundle(path: Path, counties, places) -> dict:
    with path.open() as handle:
        bundle = json.load(handle)
    counts = apply_geocode(bundle["partners"], counties, places)
    bundle["generatedAt"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    bundle["attribution"]["note"] = attribution_note()
    bundle["_geocodeCounts"] = counts
    return bundle


def write_bundle(bundle: dict, path: Path) -> None:
    bundle = dict(bundle)
    counts = bundle.pop("_geocodeCounts", None)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w") as handle:
        json.dump(bundle, handle, separators=(",", ":"), ensure_ascii=False)
        handle.write("\n")
    size_kb = path.stat().st_size / 1024
    extra = ""
    if counts:
        extra = f" — geocode county={counts['county']} place={counts['place']} none={counts['none']}"
    print(
        f"Wrote {path} ({size_kb:.0f} KB) — "
        f"{bundle['stats']['partnerCount']} partners, {bundle['stats']['hubCount']} hubs{extra}"
    )


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, help="Local dataset.json path")
    parser.add_argument(
        "--enrich-existing",
        action="store_true",
        help="Geocode names in the existing bundle; do not download DeFlock.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=root / "FlockSurveillance" / "Resources" / "SharingNetworkBundle.json",
    )
    args = parser.parse_args()
    cache_dir = root / "Scripts" / ".cache"
    counties, places = load_gazetteer(cache_dir)

    if args.enrich_existing:
        bundle = enrich_existing_bundle(args.output, counties, places)
        write_bundle(bundle, args.output)
        return

    dataset = load_dataset(args.input)
    bundle = build_bundle(dataset)
    counts = apply_geocode(bundle["partners"], counties, places)
    bundle["_geocodeCounts"] = counts
    write_bundle(bundle, args.output)


if __name__ == "__main__":
    main()
