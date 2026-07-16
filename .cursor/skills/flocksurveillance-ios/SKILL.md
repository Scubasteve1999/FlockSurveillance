---
name: flocksurveillance-ios
description: Develop, test, and ship the FlockSurveillance iOS app with XcodeGen and XcodeBuildMCP. Use when working in this repo, building or testing on simulator, changing Overpass/coverage/Drive Mode/Sharing Network, or opening PRs for Flock Surveillance.
---

# FlockSurveillance iOS

Civic transparency ALPR map app (SwiftUI, iOS 17+, Xcode 16+). On-device OSM/Overpass + bundled FOIA Sharing Network. No Flock vendor APIs.

## Tooling

- **Project definition**: [`project.yml`](../../../project.yml) → regenerate with `xcodegen generate` after adding/removing source or test files (pbxproj is generated).
- **Build/test/UI**: XcodeBuildMCP (`user-XcodeBuildMCP`). Before first build/test in a session:
  1. `session_show_defaults`
  2. If project/scheme/sim wrong, `session_set_defaults` with:
     - `projectPath`: absolute `…/FlockSurveillance/FlockSurveillance.xcodeproj`
     - `scheme`: `FlockSurveillance`
     - a current simulator id from `list_sims` (prefer an already-booted iPhone)
  3. `test_sim` / `build_run_sim` — do not assume `.xcodebuildmcp/config.yaml` paths are current (they may point at an old machine path).
- **Ignore**: `.claude/` is local agent config (gitignored). Do not commit it.

## Product constraints (do not regress)

- **Drive Mode**: Dismissing the HUD must not call `DriveSession.stop()`. Only End Drive ends the session/Live Activity. Location → session updates while active live at the app root; background GPS only via `LocationManager.setDriveTrackingEnabled` during a drive.
- **Coverage soft-clear**: Empty Overpass tiles may soft-clear only when sparse (1–3 cached in tile) and Overpass confirmed empty on **≥2 mirrors**. Protect batch-returned IDs (`seen`) when marking absent so neighbor-tile edge cameras are not hidden. Dense empty refuses clear.
- **Sharing Network**: Cap rendered Markers/arcs at `SharingNetworkStore.maxRenderedPartners` (250). Do not raise without accessibility re-check.
- **CarPlay**: Code exists; do **not** add CarPlay scene manifest / entitlement to Info.plist until Apple grants `com.apple.developer.carplay-driving-task` (early declare freezes iPad scenes).

## Change workflow

1. Prefer a feature branch off `main`.
2. Implement + add/extend unit tests under `FlockSurveillanceTests/`.
3. `xcodegen generate` if files were added.
4. Run full suite with XcodeBuildMCP `test_sim`.
5. Commit only product sources/tests/project files; push; `gh pr create` against `main`.

## Key paths

| Area | Path |
|------|------|
| App entry | `FlockSurveillance/App/FlockSurveillanceApp.swift` |
| Map / radar | `FlockSurveillance/Features/Map/` |
| Drive / route | `FlockSurveillance/Features/Route/` |
| Overpass | `FlockSurveillance/Services/OverpassClient.swift` |
| Cache / soft-clear | `FlockSurveillance/Services/CameraRepository.swift`, `CoverageConfidence.swift` |
| Drive session | `FlockSurveillance/Services/DriveSession.swift` |
| Sharing Network | `FlockSurveillance/Services/SharingNetworkStore.swift` |
| ASO notes | `docs/ASO.md` |
