import SwiftUI

/// Honest readout of a reconstructed city-limit crossing — never a confirmed Utility site.
struct EntranceSiteDetailSheet: View {
    let site: OliveBranchUniqueSite
    let nearestPin: OliveBranchEntrancePin?
    var attribution: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(site.displayRoad)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.foreground)

                    Text(site.edge)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.mutedForeground)

                    HStack(spacing: 8) {
                        StatusBadge(text: site.quality.label, color: qualityColor)
                        StatusBadge(text: site.quality.windowLabel, color: qualityColor)
                        if site.isCoincident {
                            StatusBadge(text: "One site", color: AppTheme.accent)
                        }
                    }

                    qualityLine

                    if let nearestPin {
                        pinBlock(nearestPin)
                    } else {
                        Text("No mapped OSM pin within 250 m of this crossing.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground)
                    }

                    if !site.notes.isEmpty {
                        Text(site.notes)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    flags

                    if let attribution, !attribution.isEmpty {
                        Text(attribution)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground.opacity(0.85))
                            .padding(.top, 4)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ENTRANCEWAY")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.entranceLayerMarker)
                }
            }
        }
    }

    private var qualityColor: Color {
        switch site.quality {
        case .match: return AppTheme.entranceMatch
        case .nearMiss: return AppTheme.entranceNearMiss
        case .noPin: return AppTheme.entranceGap
        }
    }

    private var qualityLine: some View {
        Group {
            if let meters = site.distanceMeters, let node = site.nearestOsmNode {
                Text("Nearest mapped pin \(node) is \(Int(meters.rounded())) m from this crossing — published table, not a live vendor match.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Gap: nothing mapped within 250 m. That is not evidence the city skipped this entrance.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func pinBlock(_ pin: OliveBranchEntrancePin) -> some View {
        let pinIsThisCrossing = site.isBestEntrance(for: pin)
        return VStack(alignment: .leading, spacing: 8) {
            Text(pinIsThisCrossing ? "Nearest mapped pin" : "Nearest pin (other crossing)")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(AppTheme.mutedForeground)
            HStack(spacing: 8) {
                StatusBadge(text: pin.vendor.rawValue, color: AppTheme.accent)
                if pinIsThisCrossing {
                    StatusBadge(text: pin.locationClass.label, color: AppTheme.entranceLayerMarker)
                } else {
                    StatusBadge(text: "Not this entrance", color: AppTheme.mutedForeground)
                }
            }
            if let road = pin.displayRoad {
                Text(road)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
            }
            if let url = pin.osmURL {
                Link(destination: url) {
                    Text("OSM node \(pin.id)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
            Text("A mapped pin here is not a confirmed 2022 Utility / Coreforce camera.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
        }
    }

    private var flags: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reconstruction — not an official site list. The city never published the 24 intersections.")
            Text("Utility (2022) ≠ Flock (2024 SaaS). OSM tags here are almost all Flock Safety.")
            Text("City limit from OSM relation 1832800 (TIGER 2008). Annexation can shift this line.")
            Text("This overlay does not watch plates and does not feed proximity alerts.")
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(AppTheme.mutedForeground)
        .fixedSize(horizontal: false, vertical: true)
    }
}
