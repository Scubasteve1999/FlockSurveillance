# Mid-South Flock / ALPR research

Research date: **2026-08-14**. Inventory and citations only. Not affiliated with Flock Safety.

This folder is the human-readable research record for Olive Branch, Memphis, and DeSoto County. It does **not** change live OpenStreetMap, DeFlock, or the in-app Overpass map. It does not add vendor APIs.

| Doc | What it is |
|---|---|
| [public-records.md](public-records.md) | Agency / contract brief with sources |
| [olive-branch-entrances.md](olive-branch-entrances.md) | Reconstruction of the unnamed 2022 “entranceway” sites |
| [mapped-pins.md](mapped-pins.md) | OSM / DeFlock pin counts for the Mid-South bbox |
| [alpr-snapshot-summary.json](alpr-snapshot-summary.json) | Count-only snapshot (no pin dump) |

Olive Branch city-limit crossings also ship in the app as [`FlockSurveillance/Resources/OliveBranchEntranceBundle.json`](../../FlockSurveillance/Resources/OliveBranchEntranceBundle.json) (GATES overlay). That JSON is the same reconstruction, not an official install list.

Refresh the count snapshot from Overpass (stdlib only; does not edit OSM):

```bash
python3 Scripts/build_midsouth_alpr_snapshot.py
```

A full 800+ pin GeoJSON is optional (`--geojson`) and is **not** committed. Sharing Network and Sensor Atlas vendor on-device JSON because the app reads them at runtime. This Mid-South pull is research; the live map still comes from Overpass.

## Confidence

OSM / DeFlock pins are crowdsourced candidates. **Confirmed** in these notes means only that an *agency* has a public Flock / ALPR record — not that a specific coordinate was field-verified. Olive Branch pins tagged Flock Safety are candidates: the 2022 hardware on the public record is Utility / Coreforce.
