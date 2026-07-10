# Flock Surveillance

Civic transparency iOS app that answers: **how watched is your life right now?**

Maps community-documented ALPR cameras from OpenStreetMap, with proximity radar, route exposure, and a Home Screen widget. Not affiliated with Flock Safety. No private vendor APIs.

## Features (v1.2)

- **Map + Proximity Radar** — viewport-scoped clusters, Flock-only filter, coverage heat, freshness label, optional approach haptics
- **Live Watch Mode** — pulsing radar ring + stronger haptic cadence while watching
- **Place Score** — one-tap watchedness grade for your location / viewport, with share card
- **Camera FOV cones** — short map wedges + detail preview when OSM `camera:direction` / `direction` is tagged
- **Route Exposure** — MapKit driving directions + alternates, per-route camera fetch (no under-fetch on long drives), shareable drive report
- **Drive Mode** — Start Drive HUD with next ALPR distance, remaining count, approach haptics, Live Activity / Dynamic Island when available
- **Camera Intel 2.0** — OSM tags, copy coords, OpenStreetMap deep link, distance from you
- **Settings** — haptics/heat/filter defaults, Set Home for widget, clear cache
- **Learn** — short explainers + links to EFF, OSM tagging, DeFlock
- **Widget** — ALPRs within 1 mile of Home; tap opens `flocksurveillance://map`

## Requirements

- Xcode 16+
- iOS 17+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Setup

```bash
cd ~/Projects/FlockSurveillance
xcodegen generate
open FlockSurveillance.xcodeproj
```

Select a Development Team in Signing & Capabilities for the app and widget targets, then run on a simulator or device.

Location permission is required for radar and “use my location” routing. Camera data requires network access to Overpass.

## Data

Queries OpenStreetMap via Overpass for:

```
node["man_made"="surveillance"]["surveillance:type"="ALPR"]
```

Coverage reflects what volunteers have mapped. It is incomplete by nature.

## Brand / domain

Product brand: **Flock Surveillance** · [flocksurveillance.com](https://flocksurveillance.com)

## License

Use and modify for civic / educational purposes. Respect OpenStreetMap [license](https://www.openstreetmap.org/copyright) when redistributing map data.
