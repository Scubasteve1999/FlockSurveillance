# App Store Optimization — Flock Surveillance v1.8

## Title & subtitle

| Field | Recommendation | Notes |
|---|---|---|
| Name (30 chars) | `Flock Surveillance: ALPR Map` | Brand + highest-value keyword in the name |
| Subtitle (30 chars) | `How watched is your life?` | Mainstream hook; fits the Watched Life thesis |

## Keyword field (100 chars)

```
alpr,license plate reader,flock,camera map,surveillance,privacy,deflock,route,speed camera,tracker
```

Notes:
- Don't repeat words already in the title/subtitle (Apple indexes those separately).
- "speed camera" is high-volume adjacent intent; the map genuinely answers it for ALPR-style cameras.
- Revisit quarterly with App Store Connect search-terms data.

## Promotional text (170 chars, editable without review)

> NEW: Sharing Network — FOIA hub-and-spoke map plus partner search. Public records only. No Flock vendor APIs.

## Description opener (first 3 lines matter most)

> How watched is your life right now? Open the app and get a personal grade for your block on a coverage dial — then raise your phone to see mapped cameras in AR, or open Sharing Network to see who FOIA-disclosed hubs share with.
>
> Built on OpenStreetMap community data plus a DeFlock Dane FOIA snapshot. No accounts. No tracking. Your location never leaves your device.

Then feature bullets in this order: Sharing Network Map, Coverage Confidence + Radar Shell, AR Camera Sight, Instant Place Score dial, Share cards, Safest drive Home↔Work, Map + FOV cones, Background alerts, Coverage reporting loop, City rankings, Widgets/Siri.

## App Store Connect paste pack

Copy these into App Store Connect → app version → App Information / Previews and Screenshots.

### Name (30)

```
Flock Surveillance: ALPR Map
```

### Subtitle (30)

```
How watched is your life?
```

### Keywords (100)

```
alpr,license plate reader,flock,camera map,surveillance,privacy,deflock,route,speed camera,tracker
```

### Promotional Text (170)

```
NEW: Sharing Network — FOIA hub-and-spoke map plus partner search. Public records only. No Flock vendor APIs.
```

### Description (full)

```
How watched is your life right now? Open the app and get a personal grade for your block on a coverage dial — then raise your phone to see mapped cameras in AR, or open Sharing Network to see who FOIA-disclosed hubs share with.

Built on OpenStreetMap community data plus a DeFlock Dane FOIA snapshot. No accounts. No tracking. Your location never leaves your device. Data Not Collected.

• Sharing Network Map — FOIA hub-and-spoke partners; search any agency beyond the map sample
• Coverage Confidence — fetch state, facing %, freshness; soft-clears stale pins after a trusted OSM refresh
• AR Camera Sight — overlay mapped ALPR locations on the street (not a live feed)
• Instant Place Score — grade your block in seconds; share Instagram-ready cards
• Safest Drive Home ↔ Work — compare routes by mapped camera exposure
• Drive Mode — live countdown HUD + Lock Screen Live Activity while you drive
• Map + FOV cones — clusters, Flock filter, optional approach haptics
• Background alerts — optional geofenced notifications near mapped cameras
• Community reporting — flag unmapped cameras as anonymous OSM notes
• City rankings, widgets, and Siri Shortcuts

Not affiliated with Flock Safety. Civic transparency mapping — not a radar detector.
```

### What's New (this release)

```
• Sensor Atlas — optional WisDOT traffic cams for Madison & Milwaukee (not ALPR; not Flock)
• Honest watched-zone copy — alerts mean near mapped ALPR pins, not plate reads
• Find any Sharing Network partner by name or state (beyond the map’s 250-arc sample)
• Drive Mode stays alive when you dismiss the HUD — Live Activity until End Drive
```

## Screenshot capture checklist

Capture order matches the storyboard above. Prefer **iPhone 16 Pro Max / 6.7"** simulator (or shipping 6.7" device). Dark appearance. Location set near a dense mapped metro (e.g. Madison WI or Atlanta) for map frames.

| # | Screen | How to get there | Caption | Notes |
|---|--------|------------------|---------|-------|
| 1 | Sharing Network | Map → Sharing Network control, or Learn → Sharing Network CTA; pick **Waunakee** | See who they share with | Offline OK (bundled FOIA). Optional: open Find partners briefly for a second crop |
| 2 | Radar HUD | Map tab, after a successful viewport fetch | Fetched. Facing. Honest. | Wait until instrument shows Fetched, not Loading |
| 3 | Place Score dial | Map → How Watched? / Place Score | Your block, graded in seconds | Settled score after covering fetch |
| 4 | Place Score share PNG | Share from Place Score → save image | Share how watched you are | Prefer `ShareCardRenderer` output, not a UI screenshot |
| 5 | AR Camera Sight | Map → AR | Point at the street — see the cameras | **Physical device outdoors** near mapped pins; sim is weak |
| 6 | Map + FOV | Map with Flock filter off, FOV cones visible | See every mapped camera | Zoom so several cones read |
| 7 | Safest Drive | Route tab → set Home/Work → Home→Work | One-tap safest drive | Show alternatives card if available |
| 8 | Drive Mode | Start Drive from a route result | Live countdown while you drive | Device for Dynamic Island; sim can show HUD only |

**Export style:** device frames on `#0F1217`, captions in `#F26B47`. Keep chrome consistent across the set.

**Skip / defer:** CarPlay until entitlement ships.

### Draft simulator captures

Low-res reference JPEGs from the iPhone 17 simulator live in [`docs/aso-captures/`](aso-captures/). Use them for layout/caption planning only — **not** for App Store upload (need full-resolution 6.7" frames + device frames).

| File | Storyboard # |
|------|----------------|
| `01-sharing-network.jpg` | 1 |
| `02-radar-map.jpg` | 2 |
| `03-place-score.jpg` | 3 |

## Screenshot storyboard (6.7" set, in order)

1. **Sharing Network hub-and-spoke map** — caption: "See who they share with"
2. **Radar instrument HUD + confidence line** — caption: "Fetched. Facing. Honest."
3. **Place Score bloom dial** — caption: "Your block, graded in seconds"
4. **Place Score share card (PNG dial)** — caption: "Share how watched you are"
5. **AR Camera Sight** — caption: "Point at the street — see the cameras"
6. **Map with pins + FOV cones** — caption: "See every mapped camera"
7. **Home → Work / Work → Home commute** — caption: "One-tap safest drive"
8. **Drive Mode HUD + Dynamic Island** — caption: "Live countdown while you drive"

Style: device frames on near-black (#0F1217) background, orange (#F26B47) captions, consistent with the app's dark theme. Prefer exporting the in-app `ShareCardRenderer` PNGs for frame 4 so App Store art matches what users actually share. Capture AR on a physical device outdoors near mapped pins. Capture Sharing Network offline with Waunakee selected.

## Privacy nutrition label (App Store Connect answers)

| Question | Answer |
|---|---|
| Data collected | **None by the developer** — select "Data Not Collected" if ASC still fits (no developer analytics, accounts, or server). Re-check if Apple treats optional third-party image loads as collected data. |
| Location | Used on-device only; never transmitted to developer servers |
| Camera | Used on-device for AR overlay only; video is not recorded or uploaded |
| Third-party | (1) Overpass/OSM: map bounding boxes only, no user identifiers. (2) **Optional:** when the user opens a Sensor Atlas traffic-cam detail, a traveler still may load from allowlisted WisDOT hosts (`content.dot.wi.gov`, `www.dot.wi.gov`) — device IP reaches that host; not ALPR, not Flock, not developer-collected. |

Feature the on-device / no-developer-tracking story in the description. Do **not** claim “no network” if Sensor Atlas stills are shipped.

## Review-prompt strategy (implemented in code)

- Trigger: 3+ high-signal events (completed drive, shared Place Score)
- Guard: max one prompt per 30 days (`ReviewPrompter.swift`); Apple caps at 3/year

## Category & age

- Primary: Navigation. Secondary: Utilities.
- Age 4+. Not a radar-detector (those get rejected); position as civic-transparency mapping in the review notes.

## App Review notes (paste into the review-notes field)

> Flock Surveillance displays community-documented ALPR camera locations from OpenStreetMap (the same public dataset as deflock.me). Sharing Network shows agency-to-agency sharing links from a public FOIA snapshot (DeFlock Dane / Wisconsin hubs) bundled on-device — not live vendor data and not which cameras feed which agency. Optional Sensor Atlas layer shows municipal WisDOT traffic CCTV locations (Madison/Milwaukee inventory snapshot). Pins are not ALPR and do not feed proximity alerts. Opening a traffic-cam detail may load a public traveler still from WisDOT hosts only (allowlisted); these are not live Flock/ALPR feeds and are not recorded by the app. It is a civic-transparency tool: it does not detect police, defeat enforcement, or use any ALPR vendor's private APIs. Coverage Confidence soft-clears pins after a successful Overpass refresh no longer returns them. AR Camera Sight overlays mapped OSM ALPR locations on the device camera for awareness only — it does not show live camera feeds or record video. Background location powers optional proximity notifications when the phone is near mapped OSM ALPR pins (not plate-read detection); location data never leaves the device to developer servers.
