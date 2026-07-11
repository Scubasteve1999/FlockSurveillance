# App Store Optimization — Flock Surveillance v1.6

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

> NEW: AR Camera Sight — point at the street and see mapped ALPR cameras around you. Still on-device only. No live feeds. No vendor APIs.

## Description opener (first 3 lines matter most)

> How watched is your life right now? Open the app and get a personal grade for your block — then raise your phone to see mapped cameras in AR, or tap once for the drive home with fewer cameras.
>
> Built on OpenStreetMap community data. No accounts. No tracking. Your location never leaves your device.

Then feature bullets in this order: AR Camera Sight, Instant Place Score, Share cards, Safest drive Home↔Work, Map + FOV cones, Background alerts, Coverage reporting loop, City rankings, Widgets/Siri.

## Screenshot storyboard (6.7" set, in order)

1. **AR Camera Sight** — caption: "Point at the street — see the cameras"
2. **Map with pins + FOV cones** — caption: "See every mapped camera"
3. **Instant How Watched? card** — caption: "Your block, graded in seconds"
4. **Place Score share card (PNG)** — caption: "Share how watched you are"
5. **Home → Work / Work → Home commute** — caption: "One-tap safest drive"
6. **Drive Mode HUD + Dynamic Island** — caption: "Live countdown while you drive"
7. **Pending report pin + contributions** — caption: "Report a camera. Watch it land."
8. **Alert notification on lock screen** — caption: "Warned before you pass one"

Style: device frames on near-black (#0F1217) background, orange (#F26B47) captions, consistent with the app's dark theme. Prefer exporting the in-app `ShareCardRenderer` PNGs for frames 4 so App Store art matches what users actually share. Capture AR on a physical device outdoors near mapped pins.

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

> Flock Surveillance displays community-documented ALPR camera locations from OpenStreetMap (the same public dataset as deflock.me). It is a civic-transparency tool: it does not detect police, defeat enforcement, or use any vendor's private data. AR Camera Sight overlays mapped OSM locations on the device camera for awareness only — it does not show live camera feeds or record video. Background location powers optional proximity notifications only; location data never leaves the device.
