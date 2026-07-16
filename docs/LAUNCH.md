# Flock Surveillance — App Store launch checklist

**Ship this app independently.** Sensor Atlas polish and city expansions must not block screenshots, App Store Connect paste, or review submission.

Source of truth for copy and capture order: [ASO.md](ASO.md).

---

## Pre-submit checklist

- [ ] Confirm `main` CI green  
- [ ] Archive / TestFlight build from current `MARKETING_VERSION`  
- [ ] Privacy nutrition label: **Data Not Collected** (see ASO.md)  
- [ ] Paste App Store Connect pack from ASO.md (name, subtitle, keywords, promo, description, what’s new)  
- [ ] Paste App Review notes from ASO.md  

## Screenshots (6.7")

Capture per [ASO.md § Screenshot capture checklist](ASO.md). Prefer iPhone 16 Pro Max / shipping 6.7" device, dark appearance, dense metro location.

| # | Needs physical device? |
|---|------------------------|
| 1 Sharing Network | No (bundled FOIA) |
| 2 Radar HUD | No |
| 3 Place Score dial | No |
| 4 Place Score share PNG | No (`ShareCardRenderer`) |
| 5 AR Camera Sight | **Yes** |
| 6 Map + FOV | No |
| 7 Safest Drive commute | No (sim OK with Home/Work) |
| 8 Drive Mode / Dynamic Island | **Yes** for Island; HUD on sim |

Optional extra: Sensor Atlas traffic-cam layer on (Madison or Milwaukee) with amber pins — not required for the core 8-frame storyboard.

Draft sim JPEGs in `docs/aso-captures/` are layout reference only — not upload assets.

## Explicit non-blockers

- Expanding Sensor Atlas beyond Madison/Milwaukee WisDOT snapshot  
- FOIA Radar, Stop Card, Ordinance Watch (parked)  
- CarPlay entitlement (defer; do not add scene manifest early)  
- Live ALPR / Flock vendor feeds or plate-hit notifications (won’t build)

## After submit

- Watch App Review for positioning language (“civic transparency,” not radar detector)  
- If rejected for overclaiming, tighten copy — do not add fake scan features  
