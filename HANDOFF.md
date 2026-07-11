# Session Handoff — Sharing Network / Map fixes

**Date:** 2026-07-11
**Branch:** main (uncommitted working tree changes — nothing committed this session)
**Status:** All fixes verified in simulator; build clean; all 66 tests pass. Not yet committed.

## What this session was

A review of the Sharing Network map surface (`SharingNetworkView`) and the shared `MapRadarView`
turned up 5 issues, all fixed and manually re-verified in the simulator. Summary below, full diff
at the bottom.

## Fixes

1. **Named the render cap instead of a bare literal.**
   `SharingNetworkStore.maxRenderedPartners = 250` replaces the bare `250` that was duplicated
   between the store's default parameter and the view's call site. The doc comment on the
   constant explains it's now an **accessibility ceiling**, not just a polyline-perf knob — see
   point 3 below for why that matters if anyone considers raising it.
   Files: [SharingNetworkStore.swift](FlockSurveillance/Services/SharingNetworkStore.swift),
   [SharingNetworkView.swift](FlockSurveillance/Features/Network/SharingNetworkView.swift)

2. **`isLoading` could get stuck `true`.**
   `SharingNetworkStore.reload()` now resets `isLoading` via `defer`, so any future early-return
   added to that method can't leave the loading state stuck on.
   File: [SharingNetworkStore.swift](FlockSurveillance/Services/SharingNetworkStore.swift)

3. **Uncapped `reachPoints` was rendering 1,000+ Markers and hanging the UI.**
   This was the main bug. `SharingNetworkView` had a `reachPoints` computed property that
   fetched *every* partner (uncapped) just to drive the `ForEach` of Markers and the status-line
   count — while a separate `arcs` property (capped at 250) drew the polylines. A hub with
   1,000+ partners meant 1,000+ Markers, which overwhelmed the accessibility tree and made the
   sheet's own controls (close button, hub chips) unreachable to VoiceOver/UI automation — this
   is what caused the close-button hang.
   Fix: both Markers and polylines now render from the same capped `arcs` list. The status line
   still reports the true total via a new lightweight `totalPartnerCount` (a plain `.count`,
   no array materialization).
   File: [SharingNetworkView.swift](FlockSurveillance/Features/Network/SharingNetworkView.swift)

4. **`arcs` was recomputed from scratch on every body evaluation.**
   It was a computed property that called `store.arcs(...)` (a full rescan + stride-sample of
   the partner list) — up to 4x per render pass. It's now `@State`, refreshed once via
   `refreshArcs()` only when the hub or visible region actually changes (hub switch, map camera
   settle, initial fit).
   File: [SharingNetworkView.swift](FlockSurveillance/Features/Network/SharingNetworkView.swift)

5. **Duplicated MapKit zero-size gate.**
   Both `MapRadarView` and `SharingNetworkView` had their own copy of the "don't insert MapKit
   at zero size, it hangs (CAMetalLayer width=0)" gate. Extracted to a shared
   `MapKitSizeGate` view in AppTheme.swift, used by both.
   Files: [AppTheme.swift](FlockSurveillance/Theme/AppTheme.swift),
   [MapRadarView.swift](FlockSurveillance/Features/Map/MapRadarView.swift),
   [SharingNetworkView.swift](FlockSurveillance/Features/Network/SharingNetworkView.swift)

## Verification performed

- Full build succeeds.
- All 66 existing tests pass.
- Manual simulator pass: close button on the Sharing Network sheet now resolves instantly
  (previously hung); switching hubs works correctly (e.g. Grand Chute shows "223 partners" with
  no redundant arc count shown, since 223 < the 250 cap so all partners are rendered as arcs).

## Not done / open items

- Nothing was deferred from the review — all 5 findings were fixed.
- Changes are **uncommitted**. `git status` also shows an untracked `.xcodebuildmcp/` directory
  (unrelated — MCP tooling config, not part of this change).
- No new tests were added specifically for these fixes (existing suite was the regression net).
  If picking this up in Cursor, consider whether the accessibility-tree/Marker-count issue in
  fix 3 warrants a dedicated UI test — the existing 66 didn't catch it because it's a scale
  issue (real partner counts hit 1,000+, test fixtures likely don't).

## Full diff

```diff
diff --git a/FlockSurveillance/Features/Map/MapRadarView.swift b/FlockSurveillance/Features/Map/MapRadarView.swift
index e68d886..9a281f7 100644
--- a/FlockSurveillance/Features/Map/MapRadarView.swift
+++ b/FlockSurveillance/Features/Map/MapRadarView.swift
@@ -85,15 +85,7 @@ struct MapRadarView: View {
             ZStack(alignment: .top) {
                 AppTheme.background.ignoresSafeArea()
 
-                // MapKit hangs if inserted at zero size (CAMetalLayer width=0),
-                // so gate on live geometry until the container has a real frame.
-                if geo.size.width > 1, geo.size.height > 1 {
-                    mapContent
-                } else {
-                    ProgressView()
-                        .tint(AppTheme.accent)
-                        .frame(maxWidth: .infinity, maxHeight: .infinity)
-                }
+                MapKitSizeGate(size: geo.size) { mapContent }
 
                 if isPlacingReport {
                     Image(systemName: "plus.viewfinder")
diff --git a/FlockSurveillance/Features/Network/SharingNetworkView.swift b/FlockSurveillance/Features/Network/SharingNetworkView.swift
index 73a4bd0..2f1f473 100644
--- a/FlockSurveillance/Features/Network/SharingNetworkView.swift
+++ b/FlockSurveillance/Features/Network/SharingNetworkView.swift
@@ -15,21 +15,22 @@ struct SharingNetworkView: View {
     )
     @State private var visibleRegion: MKCoordinateRegion?
 
+    /// Rendered pins and polylines both stay capped — an uncapped Marker count (up to
+    /// 1,000+) overwhelms the accessibility tree and makes the sheet's own controls
+    /// (close button, hub chips) unreachable to VoiceOver/UI automation. Kept in sync by
+    /// `refreshArcs()` whenever the hub or visible region changes, rather than recomputed
+    /// on every body evaluation — `store.arcs` rescans and stride-samples the full partner list.
+    @State private var arcs: [SharingArc] = []
+
     private var selectedHub: SharingHub? {
         guard let selectedHubID else { return store.hubs.first }
         return store.hubs.first { $0.id == selectedHubID } ?? store.hubs.first
     }
 
-    /// Every partner pin (uncapped) — matches the source "reach point" footprint.
-    private var reachPoints: [SharingArc] {
-        guard let hub = selectedHub else { return [] }
-        return store.reachPoints(for: hub.id)
-    }
-
-    /// Polylines stay capped for map performance.
-    private var arcs: [SharingArc] {
-        guard let hub = selectedHub else { return [] }
-        return store.arcs(for: hub.id, limit: 250, preferring: visibleRegion)
+    /// Total partner count for the hub, for the status line only — not the rendered list.
+    private var totalPartnerCount: Int {
+        guard let hub = selectedHub else { return 0 }
+        return store.partners(for: hub.id).count
     }
 
     var body: some View {
@@ -37,15 +38,7 @@ struct SharingNetworkView: View {
             ZStack(alignment: .top) {
                 AppTheme.background.ignoresSafeArea()
 
-                // MapKit misbehaves when created at a degenerate size, so gate
-                // on live geometry until the container has a real frame.
-                if geo.size.width > 1, geo.size.height > 1 {
-                    mapContent
-                } else {
-                    ProgressView()
-                        .tint(AppTheme.accent)
-                        .frame(maxWidth: .infinity, maxHeight: .infinity)
-                }
+                MapKitSizeGate(size: geo.size) { mapContent }
 
                 // Top chrome only — no full-height Spacer, so map gestures and
                 // hub chips aren't fighting a pass-through overlay.
@@ -65,7 +58,7 @@ struct SharingNetworkView: View {
         }
         .onChange(of: selectedPartnerID) { _, partnerID in
             guard let partnerID else { return }
-            selectedPartner = reachPoints.first { $0.partner.id == partnerID }?.partner
+            selectedPartner = arcs.first { $0.partner.id == partnerID }?.partner
         }
         .onChange(of: store.isLoaded) { _, loaded in
             guard loaded, selectedHubID == nil else { return }
@@ -106,7 +99,7 @@ struct SharingNetworkView: View {
                         .stroke(arcColor(arc.direction), lineWidth: 1.15)
                 }
 
-                ForEach(reachPoints) { point in
+                ForEach(arcs) { point in
                     Marker(point.partner.name, coordinate: point.partner.coordinate)
                         .tint(markerTint(point.direction))
                         .tag(point.partner.id)
@@ -117,6 +110,7 @@ struct SharingNetworkView: View {
         .ignoresSafeArea()
         .onMapCameraChange(frequency: .onEnd) { context in
             visibleRegion = context.region
+            refreshArcs()
         }
     }
 
@@ -218,7 +212,7 @@ struct SharingNetworkView: View {
         guard let hub = selectedHub else {
             return store.loadError == nil ? "Loading…" : "Unavailable"
         }
-        let points = reachPoints.count
+        let points = totalPartnerCount
         let shownArcs = arcs.count
         if points > shownArcs {
             return "\(hub.shortName) · \(points) partners · \(shownArcs) arcs"
@@ -242,6 +236,7 @@ struct SharingNetworkView: View {
             partners: store.partners(for: hub.id)
         )
         visibleRegion = fitted
+        refreshArcs()
         if animated {
             withAnimation(.easeInOut(duration: 0.35)) {
                 position = .region(fitted)
@@ -251,6 +246,18 @@ struct SharingNetworkView: View {
         }
     }
 
+    private func refreshArcs() {
+        guard let hub = selectedHub else {
+            arcs = []
+            return
+        }
+        arcs = store.arcs(
+            for: hub.id,
+            limit: SharingNetworkStore.maxRenderedPartners,
+            preferring: visibleRegion
+        )
+    }
+
     private func arcColor(_ direction: SharingDirection) -> Color {
         switch direction {
         case .hubOut: return AppTheme.primary.opacity(0.75)
diff --git a/FlockSurveillance/Services/SharingNetworkStore.swift b/FlockSurveillance/Services/SharingNetworkStore.swift
index af0c4b2..7d8cde8 100644
--- a/FlockSurveillance/Services/SharingNetworkStore.swift
+++ b/FlockSurveillance/Services/SharingNetworkStore.swift
@@ -22,6 +22,7 @@ final class SharingNetworkStore {
     ) async {
         guard !isLoading else { return }
         isLoading = true
+        defer { isLoading = false }
         do {
             let name = resourceName
             let loaded = try await Task.detached(priority: .userInitiated) {
@@ -35,7 +36,6 @@ final class SharingNetworkStore {
             isLoaded = false
             loadError = error.localizedDescription
         }
-        isLoading = false
     }
 
     /// Test / preview helper.
@@ -63,10 +63,19 @@ final class SharingNetworkStore {
         }
     }
 
+    /// Upper bound for partners rendered as map annotations (Markers + polylines) per hub.
+    ///
+    /// This isn't just a polyline-draw-performance knob: SharingNetworkView renders one
+    /// Marker per arc from this same capped list, and an uncapped Marker count (a hub can
+    /// have 1,000+ partners) overwhelms the accessibility tree, making the sheet's own
+    /// controls (close button, hub chips) unreachable to VoiceOver/UI automation. Raising
+    /// this risks silently reintroducing that bug — re-verify accessibility before raising it.
+    static let maxRenderedPartners = 250
+
     /// Prefer partners inside `preferring` when capping arcs, then stride-sample the rest.
     func arcs(
         for hubId: String,
-        limit: Int = 250,
+        limit: Int = maxRenderedPartners,
         preferring region: MKCoordinateRegion? = nil
     ) -> [SharingArc] {
         let all = reachPoints(for: hubId)
diff --git a/FlockSurveillance/Theme/AppTheme.swift b/FlockSurveillance/Theme/AppTheme.swift
index 4a59949..d7c5891 100644
--- a/FlockSurveillance/Theme/AppTheme.swift
+++ b/FlockSurveillance/Theme/AppTheme.swift
@@ -78,6 +78,26 @@ struct StatusBadge: View {
     }
 }
 
+/// Gates MapKit-backed content on a live, non-degenerate size.
+///
+/// MapKit hangs if inserted at zero size (CAMetalLayer width=0), so wrap map content in
+/// this inside a `GeometryReader` and pass `geo.size` — it shows a spinner until the
+/// container has a real frame, which `GeometryReader` guarantees to re-report reactively.
+struct MapKitSizeGate<Content: View>: View {
+    let size: CGSize
+    @ViewBuilder var content: () -> Content
+
+    var body: some View {
+        if size.width > 1, size.height > 1 {
+            content()
+        } else {
+            ProgressView()
+                .tint(AppTheme.accent)
+                .frame(maxWidth: .infinity, maxHeight: .infinity)
+        }
+    }
+}
+
 struct DataSourcePill: View {
     var body: some View {
         HStack(spacing: 6) {
```
