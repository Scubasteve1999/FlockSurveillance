# Flock Surveillance — App Store

**Shipped.** v1.9.0 (build 16) is live (2026-08-19).

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

## 1.8.2 backlog

- AR screenshot (`07-ar-camera`)
- Overpass/OSM User-Agent still says `1.5`
- `MapRadarView` split
- Remaining pluralization in `CityRankingsStrip` and `SharingNetworkView`

If a later review flags overclaiming, tighten copy. Do not add fake scan features.
Copy stays "civic transparency" / "near mapped pins," never radar-detector language.

## Reach — paste tonight

Store URL: https://apps.apple.com/us/app/flock-surveillance-alpr-map/id6789356933

### X post (attach Live Activity Lock Screen shot)

```
How watched is this road while you drive?

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
