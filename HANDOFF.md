# Claude Code Handoff — Product direction thinking

**Date:** 2026-07-15  
**Repo:** https://github.com/Scubasteve1999/FlockSurveillance (public)  
**Branch context:** `main` has recent feature PRs merged (#1–#5). Open docs PR: [#6](https://github.com/Scubasteve1999/FlockSurveillance/pull/6) (ASO paste pack + draft sim captures) — merge or ignore; not blocking product thinking.  
**Mode for this handoff:** **Think first. Do not implement code unless the human explicitly asks after the thinking pass.**

---

## Why this handoff exists

The product owner wants a **thinking pass** on whether this app is still the right thing to build.

In the latest Cursor session they asked for:

1. **Live camera feeds** from ALPR / Flock cameras  
2. **Notifications when “the camera pings them”** (real plate-read events)

Cursor correctly refused both as product/legal boundaries:

- Live Flock/ALPR vendor video and plate-hit streams are **private vendor / agency systems**. No public API. Unauthorized access is off-limits.  
- The app **cannot** observe when a camera reads a plate. It can only know **phone GPS near a mapped OSM pin**.  
- “Bending the rules” / scraping / reverse-engineering vendor systems was declined and should stay declined.

Owner reaction (paraphrased): *“damn then this isn’t what I want.”*

**Your job:** Help them think through options — double down on civic transparency mapping, pivot the product thesis, kill/park the project, or split into a different app idea that is still legal and shippable. Produce a clear recommendation with tradeoffs. **Do not** propose illegal or deceptive “we know when they scanned you” features.

---

## What this app actually is today

**Flock Surveillance** — civic transparency iOS app (SwiftUI, iOS 17+, Xcode 16+).

Answers: **how watched is your life right now?**

| Does | Does not |
|------|----------|
| Map community-documented ALPR locations from OpenStreetMap / Overpass | Use Flock Safety (or any vendor) private APIs |
| Bundled FOIA Sharing Network (DeFlock Dane hub↔partner graph) | Show which cameras feed which agency |
| Place Score, AR overlay of *mapped pins* on the phone camera, routes, Drive Mode + Live Activity | Live video from ALPR cameras |
| Geofenced **proximity** alerts near mapped pins | Notify on real plate reads |
| On-device location; “Data Not Collected” positioning | Transmit location to developer servers |

Brand: flocksurveillance.com · Not affiliated with Flock Safety · Positioned as civic transparency, **not** a radar detector (App Review sensitivity).

### Hard product constraints (do not regress if you later code)

- **Drive Mode:** Dismissing HUD must not end session; only End Drive stops Live Activity.  
- **Coverage soft-clear:** Empty tiles soft-clear only if sparse (1–3 pins) + ≥2 Overpass mirrors empty; protect batch `seen` IDs.  
- **Sharing Network:** Cap rendered Markers/arcs at 250; search list may be uncapped.  
- **CarPlay:** Code exists; **do not** add scene manifest / entitlement to Info.plist until Apple grants `com.apple.developer.carplay-driving-task`.

Skill with more detail: [`.cursor/skills/flocksurveillance-ios/SKILL.md`](.cursor/skills/flocksurveillance-ios/SKILL.md)

---

## What’s already shipped (recent)

| PR | What |
|----|------|
| #1 | Export compliance `ITSAppUsesNonExemptEncryption: false` + arc-cap scale test |
| #2 | Drive Mode / Live Activity survival (HUD dismiss ≠ end drive) |
| #3 | Coverage empty-tile soft-clear + Bugbot hardenings |
| #4 / #5 | Sharing Network partner search + clear focus pin on other Marker select |
| #6 (open) | ASO paste pack + draft sim captures under `docs/aso-captures/` |

CI: public repo, `macos-15` Actions green on `main` when last checked.

---

## Honest capability map (for the thinking pass)

| User wish | Feasible? | Notes |
|-----------|-----------|--------|
| Live ALPR / Flock camera video | **No** | Private systems; out of scope forever for this product line |
| Notify when plate is read | **No** | No public hit stream |
| Notify when *phone* near mapped camera | **Yes** | Already exists (`AlertsEngine` geofences); can polish |
| Phone camera + AR pins on street | **Yes** | Already exists; not vendor feed |
| Public *municipal traffic* cams near ALPRs | **Maybe** | Different data source, city-by-city, not ALPR video; legal only where openly published |
| Stronger “how watched” / FOIA / sharing graph | **Yes** | Fits current thesis |
| CarPlay Drive HUD | **Blocked** | Waiting on Apple entitlement |

---

## Questions to answer in the thinking pass

Work through these and write findings back (Notion, this file’s “Findings” section, or chat — ask the human where they want it).

1. **Thesis fit**  
   Is “map where cameras are from public data” still valuable to *this* owner if they personally want plate-hit / live-feed magic? Or is that a fatal product–desire mismatch?

2. **Audience**  
   Who is the real user: privacy-curious drivers, journalists/activists, local organizers, general App Store browsers? Does the current feature set serve them?

3. **Pivot options (legal only)**  
   Rank and critique, e.g.:
   - Double down: denser OSM coverage, better alerts, share cards, city rankings, FOIA tooling  
   - Adjacent: public traffic-cam layer (explicitly not ALPR feeds)  
   - Education: stronger Learn / EFF / “what ALPRs can and can’t do”  
   - New product: something else entirely (not this repo’s constraints)  
   - Park / archive the app and stop investing  

4. **Positioning risk**  
   If marketing ever overclaims (“know when you’re scanned”), App Review + trust + legal risk. How should store copy and in-app language stay honest?

5. **Next 2-week bet**  
   If they continue: one concrete, shippable bet that is *not* live feeds or plate pings. If they don’t: a clean wind-down checklist.

6. **What not to explore**  
   Vendor API reverse engineering, fake “scan detected” heuristics sold as real hits, anything that requires unauthorized access to LE/vendor systems.

---

## Suggested Claude Code workflow

1. Read this handoff + `README.md` + `docs/ASO.md` (marketing promises) + Learn copy in `LearnView.swift`.  
2. Skim feature surface from README “Features (v1.8)” — don’t deep-dive every service unless needed for a pivot idea.  
3. Produce a short **decision memo** (not a giant essay):
   - Verdict: continue / pivot / park  
   - Top 3 reasons  
   - If continue: next feature bet + why  
   - If pivot: new thesis in one paragraph + what to keep/kill from the codebase  
   - Explicit “won’t build” list  
4. Stop for human reaction before writing code or opening PRs.

---

## Key paths (if you need them later)

| Area | Path |
|------|------|
| App entry | `FlockSurveillance/App/FlockSurveillanceApp.swift` |
| Map / radar | `FlockSurveillance/Features/Map/` |
| Alerts (proximity) | `FlockSurveillance/Services/AlertsEngine.swift` |
| Drive / Live Activity | `FlockSurveillance/Services/DriveSession.swift`, `DriveLiveActivityController.swift` |
| Sharing Network | `FlockSurveillance/Services/SharingNetworkStore.swift` |
| Learn / positioning copy | `FlockSurveillance/Features/Learn/LearnView.swift` |
| ASO | `docs/ASO.md` |
| FOIA bundle refresh | `Scripts/build_sharing_network_bundle.py` |

---

## Findings

_(Claude Code: append your decision memo below after the thinking pass.)_
