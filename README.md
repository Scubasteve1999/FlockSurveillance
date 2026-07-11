# Flock Surveillance

Civic transparency iOS app that answers: **how watched is your life right now?**

Maps community-documented ALPR cameras from OpenStreetMap, with proximity radar, route exposure, and a Home Screen widget. Not affiliated with Flock Safety. No private vendor APIs.

## Features (v1.7)

- **Coverage Confidence** — radar instrument shows fetch state, facing %, and freshness; ghost pins soft-clear after a successful OSM refresh
- **Surveillance Radar Shell** — compact control rail + proximity dial HUD; Place Score bloom dial matches the share PNG
- **AR Camera Sight** — raise your phone and see mapped ALPR pins (and FOV wedges when direction is tagged) in the street; on-device only, not a live feed
- **Coverage Engine** — tracked OSM reports with pending map pins, note status checks, and a notification when your camera lands
- **Your contributions** — Settings list of open / landed reports with “check again” and map focus
- **Denser Overpass ingest** — alternate ALPR tag schemes (`camera:type`, case-insensitive `surveillance:type`) plus stronger Flock detection from operator/brand/name
- **Instant How Watched?** — auto Place Score on first map open + onboarding teaser grade
- **Visual share cards** — Instagram-ready Place Score and drive-report PNGs with deep links
- **Safest drive Home ↔ Work** — set Work in Settings; one-tap commute buttons + Siri “Safest drive home”
- **City rankings** — most-mapped metros from seed cities + local cache (map strip + Learn)
- **Background camera alerts** — geofenced notifications near mapped cameras, even with the app closed (Always location, opt-in, quiet hours)
- **Siri + Shortcuts** — nearby cameras, how watched, Drive Mode, safest drive home
- **Lock-screen widgets** — accessory circular / rectangular / inline families plus the Home Screen widget (“Cameras near Home”)
- **Community reporting** — flag unmapped or changed cameras as anonymous OpenStreetMap notes; tracked until mapped
- **CarPlay Drive Mode** — driving-task template mirroring the HUD (code ready; awaits Apple's CarPlay entitlement). Do **not** add the CarPlay scene manifest to Info.plist until the entitlement is approved — declaring it early freezes iPad scene transitions.
- **Map + Proximity Radar** — viewport-scoped clusters, Flock-only filter, coverage heat, freshness label, optional approach haptics
- **Live Watch Mode** — pulsing radar ring + stronger haptic cadence while watching
- **Camera FOV cones** — short map wedges + detail preview when OSM `camera:direction` / `direction` is tagged
- **Safest Drive** — MapKit driving directions + alternates, per-route camera fetch, shareable drive report, Start Drive + Live Activity tip
- **Drive Mode** — Start Drive HUD with next camera distance, remaining count, approach haptics, Live Activity / Dynamic Island when available
- **Camera Intel 2.0** — OSM tags, copy coords, OpenStreetMap deep link, distance from you
- **Settings** — haptics/heat/filter defaults, Set Home + Work, contributions, clear cache
- **Learn** — short explainers + metro rankings + links to EFF, OSM tagging, DeFlock
- **Widget** — cameras within 1 mile of Home; tap opens `flocksurveillance://map`

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

Location permission is required for radar and “use my location” routing. Camera permission is required only for AR Camera Sight (overlay stays on-device; nothing is recorded). Camera data requires network access to Overpass.

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
