# App Store Optimization — Flock Surveillance v1.7

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

> NEW: Surveillance radar with coverage confidence — see fetch honesty, facing %, and a Place Score dial that matches what you share.

## Description opener (first 3 lines matter most)

> How watched is your life right now? Open the app and get a personal grade for your block on a coverage dial — then raise your phone to see mapped cameras in AR, or tap once for the drive home with fewer cameras.
>
> Built on OpenStreetMap community data. No accounts. No tracking. Your location never leaves your device. The map shows what was fetched — and soft-clears pins OSM no longer returns.

Then feature bullets in this order: Coverage Confidence + Radar Shell, AR Camera Sight, Instant Place Score dial, Share cards, Safest drive Home↔Work, Map + FOV cones, Background alerts, Coverage reporting loop, City rankings, Widgets/Siri.

## Screenshot storyboard (6.7" set, in order)

1. **Radar instrument HUD + confidence line** — caption: "Fetched. Facing. Honest."
2. **Place Score bloom dial** — caption: "Your block, graded in seconds"
3. **Place Score share card (PNG dial)** — caption: "Share how watched you are"
4. **AR Camera Sight** — caption: "Point at the street — see the cameras"
5. **Map with pins + FOV cones** — caption: "See every mapped camera"
6. **Home → Work / Work → Home commute** — caption: "One-tap safest drive"
7. **Drive Mode HUD + Dynamic Island** — caption: "Live countdown while you drive"
8. **Pending report pin + contributions** — caption: "Report a camera. Watch it land."

Style: device frames on near-black (#0F1217) background, orange (#F26B47) captions, consistent with the app's dark theme. Prefer exporting the in-app `ShareCardRenderer` PNGs for frame 3 so App Store art matches what users actually share. Capture AR on a physical device outdoors near mapped pins.

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

> Flock Surveillance displays community-documented ALPR camera locations from OpenStreetMap (the same public dataset as deflock.me). It is a civic-transparency tool: it does not detect police, defeat enforcement, or use any vendor's private data. Coverage Confidence soft-clears pins after a successful Overpass refresh no longer returns them. AR Camera Sight overlays mapped OSM locations on the device camera for awareness only — it does not show live camera feeds or record video. Background location powers optional proximity notifications only; location data never leaves the device.
