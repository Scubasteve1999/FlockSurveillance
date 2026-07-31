# Flock Surveillance — agent guide

SwiftUI iOS app. Civic transparency: **"how watched is this road while driving?"**
Maps community-documented ALPR cameras from OpenStreetMap. Not affiliated with Flock Safety.

## Build

**`project.yml` is the source of truth for the Xcode project.** `FlockSurveillance.xcodeproj` is
generated. Never edit project settings, targets, or file membership in Xcode's UI or by hand — run:

```bash
cd ~/Projects/FlockSurveillance && xcodegen generate
```

Adding a `.swift` file under `FlockSurveillance/` or `Shared/` needs no config change (sources are
path-globbed), but regenerate after adding a directory.

Build and test (Cursor has XcodeBuildMCP; from a plain terminal use):

```bash
xcodebuild test -project FlockSurveillance.xcodeproj -scheme FlockSurveillance -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max'
```

- Scheme `FlockSurveillance`, simulator **iPhone 16 Pro Max**, iOS 17+ deployment target
- Targets: app, `NearbyCamerasWidgetExtension`, `FlockSurveillanceTests`
- `SWIFT_STRICT_CONCURRENCY: complete` on every target — new code must be actor-correct.
  Publish UI state on `@MainActor`; don't silence warnings with `@unchecked Sendable`.
- App group `group.com.flocksurveillance.shared` bridges app ↔ widget (`Services/WidgetBridge.swift`)

## Layout

```
FlockSurveillance/
  App/          entry point, root tabs
  Features/     Map, Route, Learn, Settings, AR, Network, Onboarding
  Services/     ~24 single-purpose services (see below)
  Models/       ALPRCamera, PublicSensor, PendingReport, SharingNetworkModels
  Theme/        AppTheme.swift, OverwatchChrome.swift
  CarPlay/      inert until Apple grants the entitlement
  Intents/      Siri / App Shortcuts
Shared/         code compiled into both app and widget
NearbyCamerasWidget/
Scripts/        frame_aso_screenshots.py (ASO screenshot framing)
docs/           ASO.md, LAUNCH.md, aso-captures/
```

Services worth knowing: `OverpassClient` (OSM fetch), `CameraRepository` (cache + viewport scoping),
`DriveSession` (drive lifecycle — `stop()` ends a drive), `ProximityRadar` + `AlertsEngine`
(geofenced alerts), `RouteExposureService`, `SensorAtlasStore` + `SensorAtlasAutoPolicy` (municipal
CCTV layer, auto-enables in Madison/Milwaukee), `SharingNetworkStore` (bundled FOIA hub↔spoke graph).

## Design system — use these, don't reinvent

`Theme/AppTheme.swift` holds every color and metric. **No hardcoded hex or magic radii in views.**

| Token | Value |
|---|---|
| `AppTheme.cornerRadius` | 16 — cards |
| `AppTheme.buttonCornerRadius` | 12 — CTAs |
| `AppTheme.cardPadding` | 16 |
| `AppTheme.primary` | coral — Flock markers, high density |
| `AppTheme.accent` | cyan — other markers |
| `AppTheme.trafficSensorMarker` | gold — Sensor Atlas pins |

Components: `OverwatchPrimaryButton`, `OverwatchSecondaryButton`, `SectionCard`, `StatusBadge`,
`DataSourcePill`, `MapKitSizeGate`.
Chrome (`Theme/OverwatchChrome.swift`): `OverwatchPageHeader`, `OverwatchBootBanner`,
`OverwatchScanlines`, `OverwatchThreatTicker`.

**Locked UI decisions — don't relitigate without being asked:**
- Page header: mono coral eyebrow `OVERWATCH · {TAB}`, title 28 `.black`
- Map is decluttered: no brand band, city rankings off by default (opt-in via the **METROS** chip),
  keeps the threat ticker + RadarHUD
- Every pulse / glow / scanline animation is gated on Reduce Motion. Any new ambient animation must
  be too — check `@Environment(\.accessibilityReduceMotion)` like `MapRadarView` and `DriveModeView` do.

## Product boundaries — hard limits

This app knows **phone GPS proximity to a mapped OSM pin**. Nothing more. Never build, and push back
if asked for:

- Live ALPR/Flock camera video, or any vendor/agency private API
- "A camera just read your plate" alerts — the app cannot observe plate reads, and claiming it can
  is a false claim to users
- Scraping or reverse-engineering vendor systems

All camera data comes from OpenStreetMap via Overpass, plus bundled FOIA public records. Copy must
stay honest: "near mapped pins," not "detected."

## Invariants — regressing these is a bug, not a preference

- **Drive Mode session lifetime.** Dismissing the HUD ("Hide Overwatch") only calls `dismiss()`.
  Only END DRIVE calls `DriveSession.stop()` and ends the Live Activity. Never merge the two.
  Location→session updates live at the app root while a drive is active; background GPS is enabled
  only via `LocationManager.setDriveTrackingEnabled` during a drive.
- **Coverage soft-clear.** An empty Overpass tile may soft-clear cached pins *only* when the tile is
  sparse (1–3 cached) **and** ≥2 mirrors confirm empty. A dense empty result must refuse to clear.
  When marking cameras absent, protect batch-returned IDs (`seen`) so neighbor-tile edge cameras
  aren't hidden. See `CameraRepository.swift` / `CoverageConfidence.swift`.
- **Sharing Network render cap.** Markers and arcs are capped at
  `SharingNetworkStore.maxRenderedPartners` (250). Don't raise it without an accessibility re-check.

## Gotchas

- **CarPlay:** do not add the CarPlay scene manifest to `Info.plist` until Apple grants the
  driving-task entitlement. Declaring `CPTemplateApplicationSceneSessionRoleApplication` early
  freezes iPad onboarding and scene transitions. Scene code is inert without it. See `project.yml`.
- Version lives in `project.yml` (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`), not in Xcode.
- Overpass/OSM `User-Agent` still reports `1.5` — known stale, low priority.

## Working agreements

- **Don't commit unless Stephen asks.** The tree is often intentionally dirty.
- Out of scope unless explicitly requested: splitting `MapRadarView`, custom fonts, Dynamic Type
  overhaul, more chrome polish.
- Build green on the simulator before calling UI work done.
