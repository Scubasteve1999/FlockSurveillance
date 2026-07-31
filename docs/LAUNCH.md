# Flock Surveillance — App Store submission

**Goal: submit.** Everything is done except the six steps below. Copy lives in [ASO.md](ASO.md);
the paste-ready version is [aso-captures/ASC_PASTE.txt](aso-captures/ASC_PASTE.txt).

**Positioning:** Drive Mode / Live Activity / route exposure first. Map + Sharing Network are
infrastructure.

---

## Six steps

1. **Screenshots** — drag the seven PNGs from `docs/aso-captures/raw/` into the **6.9"** iPhone
   slot. They are already 1320×2868 with a clean 9:41 status bar. Upload as-is.
2. **Text metadata** — paste name, subtitle, keywords, promo text, description, and what's new
   from `ASC_PASTE.txt`.
3. **App Review notes** — paste from the same file. This one matters: it tells the reviewer this is
   OSM civic data, not a vendor feed and not a radar detector.
4. **Privacy nutrition label** — Data Not Collected, plus the optional WisDOT stills disclosure.
5. **Build** — Xcode → Archive → upload → attach build 11 to the version.
6. **Submit.**

## Screenshots — no Figma required

Apple requires at least one 6.9" screenshot and allows up to ten. **Seven is a complete
submission.** Marketing frames with headline text are a convention, not a requirement — plain
screenshots are accepted. Skip the Figma composition step for this release.

| # | Stem | Status |
|---|------|--------|
| 1 | `01-drive-mode` | Ready |
| 2 | `02-safest-drive` | Ready |
| 3 | `03-radar-hud` | Ready |
| 4 | `04-place-score` | Ready |
| 5 | `05-share-card` | Ready — `ShareCardRenderer` output at 1170×1560, not a device capture |
| 6 | `06-map-fov` | Ready — no FOV cones; Memphis OSM pins carry no `direction` tag |
| 7 | `07-ar-camera` | **Missing — ship without it.** Needs a real device outdoors in daylight near a mapped pin. Do not fake it. Add in 1.8.1. |

Superseded captures from an older numbering scheme are in `raw/_legacy-scheme/`. If marketing
frames are ever wanted, they belong in `figma-export/`; source of truth is the
[Figma file](https://www.figma.com/design/rJp6KGfLHbxRHWyHvSExrC). Ignore the Python-framed
`framed/` directory.

## Do not do before submitting

- Any new feature, refactor, or copy polish
- Expanding Sensor Atlas beyond the Madison/Milwaukee WisDOT snapshot
- FOIA Radar, Stop Card, Ordinance Watch (parked)
- Requesting the CarPlay entitlement or adding the scene manifest to `Info.plist`
- Live ALPR / vendor feeds or plate-hit notifications — not a scope call, not possible

## After submit

- Watch review for positioning language: "civic transparency," not radar detector.
- If rejected for overclaiming, tighten copy. Do not add fake scan features.
- Backlog: AR screenshot; Overpass/OSM User-Agent still says `1.5`; `MapRadarView` split;
  SwiftData `fatalError` harden; remaining pluralization in `CityRankingsStrip` and
  `SharingNetworkView`.
