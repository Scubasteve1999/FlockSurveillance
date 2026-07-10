# App Store Optimization — Flock Surveillance v1.3

## Title & subtitle

| Field | Recommendation | Notes |
|---|---|---|
| Name (30 chars) | `Flock Surveillance: ALPR Map` | Brand + highest-value keyword in the name |
| Subtitle (30 chars) | `Camera alerts & safe routes` | Covers the two headline features |

## Keyword field (100 chars)

```
alpr,license plate reader,flock,camera map,surveillance,privacy,deflock,route,speed camera,tracker
```

Notes:
- Don't repeat words already in the title/subtitle (Apple indexes those separately).
- "speed camera" is high-volume adjacent intent; the map genuinely answers it for ALPR-style cameras.
- Revisit quarterly with App Store Connect search-terms data.

## Promotional text (170 chars, editable without review)

> NEW: Background ALPR alerts — get a heads-up near a mapped camera even with the app closed. Plus Siri shortcuts, lock-screen widgets, and one-tap camera reporting.

## Description opener (first 3 lines matter most)

> Thousands of automated license plate readers photograph cars every day. Flock Surveillance shows you exactly where they are — and warns you before you pass one.
>
> Built on OpenStreetMap community data. No accounts. No tracking. Your location never leaves your device.

Then feature bullets in this order: Alerts, Map + FOV cones, Route exposure + Drive Mode, Place Score, Widgets/Siri, Community reporting.

## Screenshot storyboard (6.7" set, in order)

1. **Map with pins + FOV cones** — caption: "See every mapped camera"
2. **Alert notification on lock screen** — caption: "Warned before you pass one"
3. **Drive Mode HUD + Dynamic Island** — caption: "Live countdown while you drive"
4. **Route comparison** — caption: "Pick the low-exposure route"
5. **Place Score card** — caption: "Grade any neighborhood"
6. **Report a camera sheet** — caption: "Help map what's missing"

Style: device frames on near-black (#0F1217) background, orange (#F26B47) captions, consistent with the app's dark theme.

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
