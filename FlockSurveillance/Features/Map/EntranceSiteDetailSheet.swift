import SwiftUI

/// Honest readout of a reconstructed city-limit crossing — never a confirmed Utility site.
struct EntranceSiteDetailSheet: View {
    let site: OliveBranchUniqueSite
    let nearestPin: OliveBranchEntrancePin?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
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
                    }

                    if !site.notes.isEmpty {
                        Text(site.notes)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    flags
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
            if let meters = site.distanceMeters {
                Text("\(Int(meters.rounded())) m from this crossing (published table).")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.foreground)
            } else {
                Text("No pin within 250 m — not proof the city skipped this road.")
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
        }
    }

    private var flags: some View {
        Text("Reconstruction, not official sites. Pin ≠ 2022 Utility camera. Utility ≠ Flock. Does not watch plates or feed alerts.")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppTheme.mutedForeground)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }
}
