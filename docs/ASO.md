# App Store Optimization — Flock Surveillance v1.8

**Live listing:** [Flock Surveillance: ALPR Map](https://apps.apple.com/us/app/flock-surveillance-alpr-map/id6789356933) · Apple ID `6789356933`

**Positioning:** DeFlock owns “see cameras + report.” Flock Surveillance owns **“how watched is this road right now, while I’m driving.”** Map, Sharing Network, and Sensor Atlas are infrastructure — not the lead story.

**Framed screenshots:** Figma is the source of truth (SpotterCast pattern). See [Screenshot storyboard](#screenshot-storyboard-69-set-in-order). Python [`Scripts/frame_aso_screenshots.py`](../Scripts/frame_aso_screenshots.py) is legacy/backup only.

---

## Title & subtitle

| Field | Recommendation | Notes |
|---|---|---|
| Name (30 chars) | `Flock Surveillance: ALPR Map` | Brand + highest-value keyword in the name |
| Subtitle (30 chars) | `How watched is this road?` | Drive-leaning; keeps “watched” language from Place Score / share cards |

## Keyword field (100 chars)

```
alpr,license plate reader,flock,camera map,surveillance,privacy,deflock,route,speed camera,tracker
```

Notes:
- Don't repeat words already in the title/subtitle (Apple indexes those separately).
- "speed camera" is high-volume adjacent intent; the map genuinely answers it for ALPR-style cameras.
- Revisit quarterly with App Store Connect search-terms data.

## Promotional text (170 chars, editable without review)

> NEW: Drive Mode + Live Activity — how watched is this road while you drive. Mapped OSM pins only. Not plate reads. No Flock vendor APIs.

## Description opener (first 3 lines matter most)

> How watched is this road right now? Start Drive Mode for a live countdown HUD and Lock Screen Live Activity near mapped ALPR pins — then compare Home ↔ Work routes by camera exposure, or grade your block with Place Score.
>
> Built on OpenStreetMap community data (the same public dataset as DeFlock) plus a DeFlock Dane FOIA snapshot. Differentiation is the drive: route exposure, proximity radar, and Live Activity — not a bigger map. No accounts. No tracking. Your location never leaves your device.

Then feature bullets in this order: Drive Mode, Safest Drive, Radar/alerts, Place Score, AR, Map + FOV, Sharing Network, reporting/widgets.

## App Store Connect paste pack

Copy these into App Store Connect → app version → App Information / Previews and Screenshots.

### Name (30)

```
Flock Surveillance: ALPR Map
```

### Subtitle (30)

```
How watched is this road?
```

### Keywords (100)

```
alpr,license plate reader,flock,camera map,surveillance,privacy,deflock,route,speed camera,tracker
```

### Promotional Text (170)

```
NEW: Drive Mode + Live Activity — how watched is this road while you drive. Mapped OSM pins only. Not plate reads. No Flock vendor APIs.
```

### Description (full)

```
How watched is this road right now? Start Drive Mode for a live countdown HUD and Lock Screen Live Activity near mapped ALPR pins — then compare Home ↔ Work routes by camera exposure, or grade your block with Place Score.

Built on OpenStreetMap community data (the same public dataset as DeFlock) plus a DeFlock Dane FOIA snapshot. Differentiation is the drive: route exposure, proximity radar, and Live Activity — not a bigger map. No accounts. No tracking. Your location never leaves your device. Data Not Collected.

• Drive Mode — live countdown HUD + Lock Screen / Dynamic Island Live Activity while you drive
• Safest Drive Home ↔ Work — compare routes by mapped camera exposure; share a drive report
• Watched-zone radar — optional geofenced alerts when your phone is near mapped OSM pins (not plate reads)
• Instant Place Score — grade your block in seconds; share Instagram-ready cards
• AR Camera Sight — overlay mapped ALPR locations on the street (not a live feed)
• Map + FOV cones — clusters, Flock filter, Coverage Confidence, optional approach haptics
• Sharing Network — FOIA hub-and-spoke partners from public records; search any agency beyond the map sample
• Community reporting — flag unmapped cameras as anonymous OSM notes
• City rankings, widgets, and Siri Shortcuts

Not affiliated with Flock Safety. Civic transparency mapping — not a radar detector.
```

### What's New (this release)

```
• Place Score says “Your block” only for GPS or Home — map previews say “This area”
• End Drive now clears a stuck Live Activity; Hide Overwatch still keeps the drive going
• Alerts follow Home and the city on your map, not only the first city you cached
• Traffic cams stay off if you turned them off before location was available
```

## Screenshot capture checklist

Capture order matches the storyboard below. Prefer **iPhone 16 Pro Max / 6.9"** simulator for full-res raw PNGs (`xcrun simctl io <udid> screenshot` — do **not** use downscaled MCP screenshots for ASC). Dark appearance. Location near a dense mapped metro (e.g. Madison WI) for map/radar frames.

| # | Stem | Screen | How to get there | Caption | Notes |
|---|------|--------|------------------|---------|-------|
| 1 | `01-drive-mode` | Drive Mode HUD | Route → directions → Start Drive | How watched is this road | Sim OK for HUD; **device** for Dynamic Island composite |
| 2 | `02-safest-drive` | Safest Drive / route compare | Route → Home↔Work | Pick the quieter route | Show alternatives card if available |
| 3 | `03-radar-hud` | Radar HUD / watched zone | Map tab after successful fetch | Near mapped pins — honest | Wait until instrument shows Fetched |
| 4 | `04-place-score` | Place Score dial | Map → How Watched? / Place Score | Your block, graded | Settled score after covering fetch |
| 5 | `05-share-card` | Place Score share PNG | Share from Place Score → save image | Share how watched you are | Prefer `ShareCardRenderer` output |
| 6 | `06-map-fov` | Map + FOV | Map, Flock filter off, FOV cones visible | See every mapped camera | Zoom so several cones read |
| 7 | `07-ar-camera` | AR Camera Sight | Map → AR | Point at the street | **Physical device outdoors**; do not fake |
| 8 | `08-sharing-network` | Sharing Network | Map → Sharing Network; pick **Waunakee** | See who they share with | Offline OK (bundled FOIA) |

**Raw path:** `docs/aso-captures/raw/<stem>.png`  
**Figma export path:** `docs/aso-captures/figma-export/<stem>.png` (1320×2868)

**Skip / defer:** CarPlay until entitlement ships.

### Legacy draft captures

Older low-res JPEGs and pre-reorder raw PNGs may still exist under [`docs/aso-captures/`](aso-captures/). Remap or re-shoot to the stems above before uploading to Figma. Not ASC-ready until Figma-framed.

## Screenshot storyboard (6.9" set, in order)

Marketing frames are composed in Figma: [Flock Surveillance App Store Screenshots](https://www.figma.com/design/rJp6KGfLHbxRHWyHvSExrC). Canvas **1320×2868**. Brand **FLOCK SURVEILLANCE**, background `#0F1217`, headlines `#F26B47`.

1. **Drive Mode HUD** — `01-drive-mode` — "How watched is this road"
2. **Safest Drive / route compare** — `02-safest-drive` — "Pick the quieter route"
3. **Radar HUD / watched zone** — `03-radar-hud` — "Near mapped pins — honest"
4. **Place Score dial** — `04-place-score` — "Your block, graded"
5. **Place Score share card** — `05-share-card` — "Share how watched you are"
6. **Map + FOV cones** — `06-map-fov` — "See every mapped camera"
7. **AR Camera Sight** — `07-ar-camera` — "Point at the street"
8. **Sharing Network (Waunakee)** — `08-sharing-network` — "See who they share with"

Export PNG @1x from Figma into `docs/aso-captures/figma-export/`. Upload those to App Store Connect (6.9" iPhone slot).

## Privacy nutrition label (App Store Connect answers)

Paste / select these in **App Store Connect → App Privacy**.

| ASC question | Answer |
|---|---|
| Data types collected by you / linked to identity | **Data Not Collected** — no developer analytics, accounts, or developer-operated servers |
| Location | Used **on device only**. Powers map, Drive Mode, and optional geofenced proximity alerts. Never transmitted to the developer |
| Camera | Used **on device only** for AR Camera Sight overlay. Video is **not** recorded or uploaded |
| Product interaction / diagnostics / identifiers | Not collected by the developer |
| Third-party / network | (1) **Overpass / OpenStreetMap:** map bounding-box queries only; no user identifiers. (2) **Optional:** when the user opens a Sensor Atlas traffic-cam detail, a public traveler still may load from allowlisted WisDOT hosts (`content.dot.wi.gov`, `www.dot.wi.gov`). Device IP reaches that host. Not ALPR, not Flock, not developer-collected |

Do **not** claim “no network.” Feature the on-device / no-developer-tracking story in the description.

If Apple’s questionnaire forces a choice because of WisDOT image loads, disclose under the closest “browsing” / third-party content category and keep the review notes explicit that loads are user-initiated, allowlisted, and not ALPR feeds.

## Review-prompt strategy (implemented in code)

- Trigger: 3+ high-signal events (completed drive, shared Place Score)
- Guard: max one prompt per 30 days (`ReviewPrompter.swift`); Apple caps at 3/year

## Category & age

- Primary: Navigation. Secondary: Utilities.
- Age 4+. Not a radar-detector (those get rejected); position as civic-transparency mapping in the review notes.

## App Review notes (paste into the review-notes field)

> Flock Surveillance helps drivers understand mapped ALPR exposure on the road: Drive Mode HUD, Live Activity, and route comparison use community-documented camera locations from OpenStreetMap (the same public dataset as deflock.me). Alerts and Live Activity mean the phone is near a mapped OSM pin — not that a plate was read. Sharing Network shows agency-to-agency sharing links from a public FOIA snapshot (DeFlock Dane / Wisconsin hubs) bundled on-device — not live vendor data and not which cameras feed which agency. Optional Sensor Atlas layer shows municipal WisDOT traffic CCTV locations (Madison/Milwaukee inventory snapshot). Those pins are not ALPR and do not feed proximity alerts. Opening a traffic-cam detail may load a public traveler still from WisDOT hosts only (allowlisted); these are not live Flock/ALPR feeds and are not recorded by the app. Civic transparency tool: it does not detect police, defeat enforcement, or use any ALPR vendor's private APIs. AR Camera Sight overlays mapped OSM ALPR locations on the device camera for awareness only — it does not show live camera feeds or record video. Background location powers optional proximity notifications; location data never leaves the device to developer servers.
