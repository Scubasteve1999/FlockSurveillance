# Mid-South mapped ALPR pins

**Snapshot date:** 2026-08-14  
**OSM base timestamp:** ~2026-08-14T23:18Z  
**License:** [OpenStreetMap ODbL](https://www.openstreetmap.org/copyright)

Counts below are from a 2026-08-14 Overpass pull. A 2026-08-15 verification pull (OSM base 2026-08-15T01:39:51Z) still had **845** nodes and the same city / county split. The Flock-tag heuristic was 817 / 28 other (the 2026-08-14 table is 819 / 26). The published east-Memphis seed still had 52 nodes within 1 mile. If you regenerate and the numbers differ, keep the script output and say so in the summary JSON `notes` field.

## Query

```
node["surveillance:type"="ALPR"](34.80,-90.25,35.26,-89.60);
```

Bbox: south 34.80, west −90.25, north 35.26, east −89.60 (Memphis / DeSoto / east Arkansas fringe).

DeFlock’s public map / CDN is the **same OSM data** — the same `surveillance:type=ALPR` nodes — not an independent coordinate database. This repo does not edit OSM or DeFlock.

The live iOS app uses a broader Overpass expression (case-insensitive `surveillance:type`, `camera:type`, ways/relations). This research snapshot uses the exact node query above so the published table stays reproducible.

## City assignment

City and county are assigned with **admin polygons** (OSM `boundary=administrative`, `admin_level=8` place and `admin_level=6` county), not sloppy bounding boxes. A pin inside the Olive Branch polygon counts as Olive Branch even if a bbox would also cover Southaven. Unincorporated means inside a county polygon and outside every place polygon in the pull.

Olive Branch uses relation [1832800](https://www.openstreetmap.org/relation/1832800) (TIGER 2008 place shapefile; annexation can lag).

## Counts (2026-08-14)

Total nodes in bbox: **845**.

### By city / place

| Place | ALPR nodes |
|---|---|
| Memphis | 424 |
| Germantown | 80 |
| Collierville | 74 |
| unincorporated MS | 53 |
| unincorporated TN | 52 |
| Olive Branch | 31 |
| Southaven | 29 |
| Bartlett | 24 |
| Lakeland | 21 |
| Marion AR | 16 |
| Horn Lake | 12 |
| West Memphis | 9 |
| Arlington | 6 |
| Hernando | 5 |
| Piperton | 5 |
| unincorporated AR | 4 |

### By county

| County | ALPR nodes |
|---|---|
| Shelby County, TN | 679 |
| DeSoto County, MS | 127 |
| Crittenden County, AR | 29 |
| Fayette County, TN | 7 |
| Marshall County, MS | 3 |

### By vendor tag

| Tag heuristic | Nodes |
|---|---|
| Flock Safety (`manufacturer` / `brand` / `operator` / `name` / `ref` contains “flock”) | ~819 |
| Other vendors | 26 |

Same “contains flock” heuristic as `ALPRIdentity.isFlock` in the app.

### Clusters

- Densest cluster: **~52** ALPRs within 1 mile of **35.10284, −89.85706** (east Memphis / Germantown).
- Southaven–Horn Lake Goodman / I-55 cluster: **~19**.

## Confidence

OSM / DeFlock pins are crowdsourced candidates. **Confirmed** only means the *agency* has a public Flock / ALPR record, not that a specific coordinate was field-verified.

Olive Branch Flock-tagged pins are candidates because official 2022 hardware is Utility / Coreforce. See [public-records.md](public-records.md) and [olive-branch-entrances.md](olive-branch-entrances.md).

News figures and OSM counts are different datasets. FOX13’s ~200 Memphis citywide figure (2026-07-29) is an agency / press number; the Memphis *polygon* in this pull has 424 tagged nodes.

## Regenerating

Count-only JSON (committed): [`alpr-snapshot-summary.json`](alpr-snapshot-summary.json).

```bash
python3 Scripts/build_midsouth_alpr_snapshot.py
```

Optional full pin dump (not committed; ODbL — do not publish without OSM attribution):

```bash
python3 Scripts/build_midsouth_alpr_snapshot.py --geojson /tmp/midsouth-alpr.geojson
```

The script talks to public Overpass mirrors only. It does not call Flock vendor APIs and does not write to OSM.
