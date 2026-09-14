# Flock Surveillance — App Store

## Tip identity (this checkout)

Flock Surveillance is the tip product again. Stephen paused the Mapped Camera Pins rename.

| Field | Value |
|---|---|
| Display name | Flock Surveillance |
| Bundle ID | `com.flocksurveillance.app` |
| Tests | `com.flocksurveillance.app.tests` |
| Widget | `com.flocksurveillance.app.widget` |
| App Group | `group.com.flocksurveillance.shared` |
| URL scheme | `flocksurveillance` |
| Tip IAPs | `com.flocksurveillance.app.tip.{small,medium,large}` |
| Version | 1.9.3 (build 19) — next Flock archive. 1.9.2 (build 18) was already submitted on the live listing. |

**Parked / unused:** Mapped Camera Pins identity and ASC listing `6810965608`. Leave that listing **draft**. Do not delete it from this slice. Do not archive, TestFlight, or submit from this PR.

Support / privacy URLs stay on **live GitHub Pages** (`AppLinks.supportURL` / `AppLinks.privacyPolicyURL`). Settings exposes both links. Do not invent flocksurveillance.com in-app. Follow-on (out of this PR): rebrand Pages titles from “Mapped Camera Pins” → “Flock Surveillance” so Settings links match the store name.

- Support: https://scubasteve1999.github.io/mapped-camera-pins-site/
- Privacy: https://scubasteve1999.github.io/mapped-camera-pins-site/privacy.html
- App Store: https://apps.apple.com/us/app/flock-surveillance-alpr-map/id6789356933

Overpass User-Agent is `FlockSurveillance/<version> (civic transparency)` with no fake contact URL.

This slice does not archive, submit, or delete the parked MCP listing.

---

**Shipped.** v1.9.1 (build 17) is live. v1.9.0 (build 16) shipped 2026-08-19.

- Listing: [Flock Surveillance: ALPR Map](https://apps.apple.com/us/app/flock-surveillance-alpr-map/id6789356933)
- Apple ID: `6789356933`
- Copy / ASO pack: [ASO.md](ASO.md) · paste pack: [aso-captures/ASC_PASTE.txt](aso-captures/ASC_PASTE.txt)

**Positioning:** Drive Mode / Live Activity / route exposure first. Map + Sharing Network are
infrastructure.

---

## 1.8.0 submission (done)

1. Screenshots — seven 6.9" PNGs from `docs/aso-captures/raw/`
2. Text metadata — name, subtitle, keywords, promo, description, what's new from `ASC_PASTE.txt`
3. App Review notes — OSM civic data, not a vendor feed, not a radar detector
4. Privacy nutrition label — Data Not Collected, plus optional WisDOT stills disclosure
5. Build 11 attached to 1.8.0
6. Submitted and approved 2026-08-13

## Screenshots (1.8.1)

Last capture set — not asserted as current store art. Apple requires at least one 6.9"
screenshot and allows up to ten. Seven frames in `docs/aso-captures/raw/`. Marketing
frames with headline text are a convention, not a requirement.

| # | Stem | Status |
|---|------|--------|
| 1 | `01-drive-mode` | Shipped |
| 2 | `02-safest-drive` | Shipped |
| 3 | `03-radar-hud` | Shipped |
| 4 | `04-place-score` | Shipped |
| 5 | `05-share-card` | Shipped — `ShareCardRenderer` output at 1170×1560, not a device capture |
| 6 | `06-map-fov` | Shipped — no FOV cones; Memphis OSM pins carry no `direction` tag |
| 7 | `07-ar-camera` | **Missing.** Needs a real device outdoors in daylight near a mapped pin. Do not fake it. Add in 1.8.1. |

Superseded captures from an older numbering scheme are in `raw/_legacy-scheme/`. If marketing
frames are ever wanted, they belong in `figma-export/`; source of truth is the
[Figma file](https://www.figma.com/design/rJp6KGfLHbxRHWyHvSExrC). Ignore the Python-framed
`framed/` directory.

## Still out of scope

- Expanding Sensor Atlas beyond the Madison/Milwaukee WisDOT snapshot
- FOIA Radar, Stop Card, Ordinance Watch (parked)
- Requesting the CarPlay entitlement or adding the scene manifest to `Info.plist`
- Live ALPR / vendor feeds or plate-hit notifications — not a scope call, not possible

## 1.8.1 (build 12)

Audit hardenings on `main`: Drive Mode Live Activity generation guard, honest Place Score
headlines, Overpass empty-consensus, Home/viewport alert candidates, Sensor Atlas manual-off.

## 1.8.2 (build 14)

Sharing Network geocodes FOIA names to Census county/place and drills nation → state →
county → agency. Pins are inferred from the name, not a FOIA address. 250-marker cap held.
Build 14 dismisses the stuck keyboard on search and address fields.
What's New: [ASO.md](ASO.md) · paste pack: [aso-captures/ASC_PASTE.txt](aso-captures/ASC_PASTE.txt).

## 1.9.0 (build 16)

Shipped 2026-08-19. Tip jar, Sharing Network by county, keyboard dismiss.

## 1.9.1 (build 17)

Shipped / live. Honesty copy pass — pin-zone / HOW MAPPED / Fewest Pins Drive / no pins ahead.

## 1.9.2 (build 18)

Store screenshot slot-1 honesty ("How mapped is this road?") + Shelby portal-shares
honesty card. Submitted on the Flock Surveillance listing.

## 1.9.3 (build 19)

Next Flock archive. Tip identity restored to Flock Surveillance after the Mapped Camera
Pins rename was parked (unused ASC `6810965608` stays draft). Includes Thin+ Sharing
Network retention-delta samples already on tip. Stephen archives on his Mac after merge.

## 1.8.2 backlog

- AR screenshot (`07-ar-camera`)
- `MapRadarView` split
- Remaining pluralization in `CityRankingsStrip` and `SharingNetworkView`

If a later review flags overclaiming, tighten copy. Do not add fake scan features.
Copy stays "civic transparency" / "near mapped pins," never radar-detector language.

## Reach — paste tonight

Store URL: https://apps.apple.com/us/app/flock-surveillance-alpr-map/id6789356933

### X post (attach Live Activity Lock Screen shot)

```
How mapped is this road while you drive?

Flock Surveillance: Drive Mode + Lock Screen Live Activity near mapped ALPR pins from OpenStreetMap.

Mapped pins, not plate reads. No Flock vendor APIs. Not affiliated with Flock Safety.

https://apps.apple.com/us/app/flock-surveillance-alpr-map/id6789356933
```

First reply if useful:

```
Mapped OSM pins only. The app cannot see plate reads. Civic transparency — not a radar detector.
```

### flocksurveillance.com Store button

Paste into the site builder (site is not in this repo):

```html
<a href="https://apps.apple.com/us/app/flock-surveillance-alpr-map/id6789356933"
   style="display:inline-block;padding:14px 22px;border-radius:12px;background:#F26B47;color:#fff;font:700 16px/1.2 system-ui,sans-serif;text-decoration:none">
  Get on the App Store
</a>
```
