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

> NEW: Sharing Network — see FOIA-documented agency partners as a national hub-and-spoke map. Public records only. No Flock vendor APIs.

## Description opener (first 3 lines matter most)

> How watched is your life right now? Open the app and get a personal grade for your block on a coverage dial — then raise your phone to see mapped cameras in AR, or open Sharing Network to see who FOIA-disclosed hubs share with.
>
> Built on OpenStreetMap community data plus a DeFlock Dane FOIA snapshot. No accounts. No tracking. Your location never leaves your device.

Then feature bullets in this order: Sharing Network Map, Coverage Confidence + Radar Shell, AR Camera Sight, Instant Place Score dial, Share cards, Safest drive Home↔Work, Map + FOV cones, Background alerts, Coverage reporting loop, City rankings, Widgets/Siri.

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
| Data collected | **None** — select "Data Not Collected" |
| Location | Used on-device only; never transmitted to developer servers |
| Camera | Used on-device for AR overlay only; video is not recorded or uploaded |
| Third-party | Overpass/OSM queries contain map bounding boxes only, no identifiers |

"Data Not Collected" badge is a major conversion asset for this audience — feature it in the description too.

## Review-prompt strategy (implemented in code)

- Trigger: 3+ high-signal events (completed drive, shared Place Score)
- Guard: max one prompt per 30 days (`ReviewPrompter.swift`); Apple caps at 3/year

## Category & age

- Primary: Navigation. Secondary: Utilities.
- Age 4+. Not a radar-detector (those get rejected); position as civic-transparency mapping in the review notes.

## App Review notes (paste into the review-notes field)

> Flock Surveillance displays community-documented ALPR camera locations from OpenStreetMap (the same public dataset as deflock.me). Sharing Network shows agency-to-agency sharing links from a public FOIA snapshot (DeFlock Dane / Wisconsin hubs) bundled on-device — not live vendor data and not which cameras feed which agency. It is a civic-transparency tool: it does not detect police, defeat enforcement, or use any vendor's private APIs. Coverage Confidence soft-clears pins after a successful Overpass refresh no longer returns them. AR Camera Sight overlays mapped OSM locations on the device camera for awareness only — it does not show live camera feeds or record video. Background location powers optional proximity notifications only; location data never leaves the device.
