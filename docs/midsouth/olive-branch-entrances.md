# Olive Branch entranceway match

**Research date:** 2026-08-14  
**Method:** classified OSM highways that pierce Olive Branch relation [1832800](https://www.openstreetmap.org/relation/1832800).

Official sources never named the 24 intersections. This is a **geographic reconstruction**, not a leaked install list and not official Utility Associates / Coreforce locations.

A mapped Flock pin at an entrance is **not** a confirmed 2022 Utility camera. Utility (2022) ≠ Flock (2024 SaaS). Absence of a pin is not evidence the city skipped that road.

## Caveats

- The OSM city polygon is a **TIGER 2008** place shapefile. Later annexation can shift what counts as “city limit.”
- Crossing = highway ∩ city boundary, not a field-verified pole.
- Match windows: **match** ≤150 m, **near-miss** 150–250 m, **no pin** otherwise. Same windows as `EntranceMatchQuality` in the app.
- These sites never feed proximity alerts.

The same table ships in [`FlockSurveillance/Resources/OliveBranchEntranceBundle.json`](../../FlockSurveillance/Resources/OliveBranchEntranceBundle.json) for the GATES overlay. The bundle stores Nail Rd and Malone Rd as two road rows that share one physical site (`W3-W4`). Do not recompute the published distances from a later Overpass pull and overwrite that snapshot.

Public-record citations: [public-records.md](public-records.md).

## Summary

23 unique crossings (Nail / Malone = one SW corner). 11 have a pin within 250 m (8 match ≤150 m, 3 near-miss). 12 gaps.

Of 31 Olive Branch city-polygon pins, 11 sit on an entrance; 20 are leftover interior / HOA.

For a strict 24 named roads, count Nail and Malone separately and drop **S2** or **E3**. The in-app forced-24 helper drops S2 (`includeInForced24: false`).

## Entrance table

Crossing = highway ∩ city boundary. OSM node links are `https://www.openstreetmap.org/node/{id}`.

| ID | Road | Crossing | Pin node | Dist | Quality |
|---|---|---|---|---|---|
| N1 | Pleasant Hill Rd @ State Line | 34.994632, -89.901471 | — | 763 m | no pin |
| N2 | Davidson Rd @ State Line | 34.994358, -89.883774 | [12856671911](https://www.openstreetmap.org/node/12856671911) | 9 m | match |
| N3 | US 78 / Lamar north | 34.994324, -89.878533 | — | 483 m | no pin |
| N4 | Old Hwy 78 (MS 178) north | 34.994255, -89.871380 | [13162178977](https://www.openstreetmap.org/node/13162178977) | 19 m | match |
| N5 | Mineral Wells Rd @ State Line | 34.994207, -89.861813 | [14056099801](https://www.openstreetmap.org/node/14056099801) | 167 m | near-miss |
| N6 | Crumpler Rd @ State Line | 34.994374, -89.848385 | [13702433531](https://www.openstreetmap.org/node/13702433531) | 24 m | match |
| N7 | Germantown Rd (MS 305) / Riverdale | 34.994470, -89.830784 | [13283750863](https://www.openstreetmap.org/node/13283750863) | 30 m | match |
| N8 | Alexander Rd @ State Line | 34.994478, -89.813074 | — | 1.6 km | no pin |
| N9 | Hacks Cross Rd @ State Line | 34.994530, -89.795375 | [13736738240](https://www.openstreetmap.org/node/13736738240) | 15 m | match |
| W1 | State Line Rd west (into Southaven) | 34.991488, -89.919001 | [12856639536](https://www.openstreetmap.org/node/12856639536) | 196 m | near-miss |
| W2 | Goodman Rd (MS 302) west | 34.962358, -89.919027 | — | 1.6 km | no pin |
| W3/W4 | Nail Rd / Malone Rd SW (one site) | 34.94782, -89.91901 | [12856624768](https://www.openstreetmap.org/node/12856624768) | 79 m | match |
| W5 | Church Rd west | 34.933188, -89.921098 | — | — | no pin |
| S1 | Pleasant Hill Rd south | 34.933116, -89.901422 | — | — | no pin |
| S2 | Church Rd south (optional dup of S1) | 34.933116, -89.892392 | — | — | no pin |
| S3 | Craft Rd south | 34.933032, -89.865674 | — | — | no pin |
| S4 | MS 305 / Cockrum south | 34.919169, -89.830365 | [13398210201](https://www.openstreetmap.org/node/13398210201) | 32 m | match |
| S5 | Bethel / College SE | 34.918675, -89.794929 | — | 817 m | no pin |
| S6 | Old Hwy 78 south | 34.927975, -89.789028 | [14001246101](https://www.openstreetmap.org/node/14001246101) | 201 m | near-miss |
| S7 | US 78 south | 34.924595, -89.790105 | [13311201780](https://www.openstreetmap.org/node/13311201780) | 127 m | match |
| E1 | Goodman Rd (MS 302) east | 34.961779, -89.795051 | — | — | no pin |
| E2 | Polk Lane NE | 34.988063, -89.777769 | — | — | no pin |
| E3 | Forest Hill-Irene NE (weak) | 34.989394, -89.759538 | — | — | no pin |

## Dropped (not major entranceways)

Unnamed TIGER tracks on the north line; Ross Rd / Annandale (TN-only); South Distribution Cove; Progress Way; ramps.

## Leftover interior pins

Not at a city-limit crossing. Of 31 city-polygon pins, these 20 are leftover interior / HOA.

**Goodman Rd near Pleasant Hill cluster**

- [12478863940](https://www.openstreetmap.org/node/12478863940)
- [13648184904](https://www.openstreetmap.org/node/13648184904)
- [13648202101](https://www.openstreetmap.org/node/13648202101) (same coords as 13648184904)
- [12478859726](https://www.openstreetmap.org/node/12478859726)
- [13648080016](https://www.openstreetmap.org/node/13648080016)
- [13570376049](https://www.openstreetmap.org/node/13570376049) Muirfield / HOA

**Craft Goodman**

- [12925919873](https://www.openstreetmap.org/node/12925919873)
- [13357789401](https://www.openstreetmap.org/node/13357789401)
- [12925920963](https://www.openstreetmap.org/node/12925920963)

**On a corridor but not at the line**

- [13929760503](https://www.openstreetmap.org/node/13929760503) Pleasant Hill, 763 m south of N1
- [13140263269](https://www.openstreetmap.org/node/13140263269)
- [13283707063](https://www.openstreetmap.org/node/13283707063) Germantown / Plantation
- [13702462965](https://www.openstreetmap.org/node/13702462965)
- [13790859601](https://www.openstreetmap.org/node/13790859601) Airport / Hacks Cross
- [13283746163](https://www.openstreetmap.org/node/13283746163) Longwood

**Subdivision / HOA**

- [13936641503](https://www.openstreetmap.org/node/13936641503) Alexander & Fox Run
- [12478849328](https://www.openstreetmap.org/node/12478849328) Goodman & Dogwood Manor
- [14031340902](https://www.openstreetmap.org/node/14031340902)
- [14002451801](https://www.openstreetmap.org/node/14002451801) Trinity Park HOA
- [13920361501](https://www.openstreetmap.org/node/13920361501) Motorola at Hacks Cross & Bethel (only non-Flock pin in the city-polygon set)
