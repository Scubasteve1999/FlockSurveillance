# App Store Optimization — Flock Surveillance v1.5

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

> NEW: Track camera reports until they land on the map, denser OSM coverage, pending pins, and contribution history — help map the cameras watching you.

## Description opener (first 3 lines matter most)

> How watched is your life right now? Open the app and get a personal grade for your block — then share a beautiful card or tap once for the drive home with fewer cameras.
>
> Built on OpenStreetMap community data. No accounts. No tracking. Your location never leaves your device.

Then feature bullets in this order: Instant Place Score, Share cards, Safest drive Home↔Work, Map + FOV cones, Background alerts, Coverage reporting loop, City rankings, Widgets/Siri.

## Screenshot storyboard (6.7" set, in order)

1. **Map with pins + FOV cones** — caption: "See every mapped camera"
2. **Instant How Watched? card** — caption: "Your block, graded in seconds"
3. **Place Score share card (PNG)** — caption: "Share how watched you are"
4. **Home → Work / Work → Home commute** — caption: "One-tap safest drive"
5. **Drive Mode HUD + Dynamic Island** — caption: "Live countdown while you drive"
6. **Pending report pin + contributions** — caption: "Report a camera. Watch it land."
7. **Drive report share card** — caption: "Fewer cameras. Same destination."
8. **Alert notification on lock screen** — caption: "Warned before you pass one"

Style: device frames on near-black (#0F1217) background, orange (#F26B47) captions, consistent with the app's dark theme. Prefer exporting the in-app `ShareCardRenderer` PNGs for frames 3 and 7 so App Store art matches what users actually share.

## Privacy nutrition label (App Store Connect answers)

| Question | Answer |
|---|---|
| Data collected | **None** — select "Data Not Collected" |
| Location | Used on-device only; never transmitted to developer servers |
| Third-party | Overpass/OSM queries contain map bounding boxes only, no identifiers |

"Data Not Collected" badge is a major conversion asset for this audience — feature it in the description too.

## Review-prompt strategy (implemented in code)

- Trigger: 3+ high-signal events (completed drive, shared Place Score)
- Guard: max one prompt per 30 days (`ReviewPrompter.swift`); Apple caps at 3/year

## Category & age

- Primary: Navigation. Secondary: Utilities.
- Age 4+. Not a radar-detector (those get rejected); position as civic-transparency mapping in the review notes.

## App Review notes (paste into the review-notes field)

> Flock Surveillance displays community-documented ALPR camera locations from OpenStreetMap (the same public dataset as deflock.me). It is a civic-transparency tool: it does not detect police, defeat enforcement, or use any vendor's private data. Background location powers optional proximity notifications only; location data never leaves the device.
