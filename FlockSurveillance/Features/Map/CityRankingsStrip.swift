import MapKit
import SwiftUI

/// Horizontal strip of most-mapped metros — war-board ranking, not a census.
struct CityRankingsStrip: View {
    let rankings: [CityRanking]
    let onSelect: (CityRanking) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("THREAT BOARD")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.primary)
                Spacer()
                Text("CACHED · NOT NATIONAL")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.mutedForeground)
            }

            Text("Most-mapped metros on this device — denser cache, not complete coverage.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(rankings.enumerated()), id: \.element.id) { index, city in
                        let level = SurveillanceLevel.compute(
                            visibleCount: city.cameraCount,
                            nearestMeters: nil,
                            inWatchedZone: false
                        )
                        Button {
                            onSelect(city)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 6) {
                                    Text("#\(index + 1)")
                                        .font(.system(size: 11, weight: .black, design: .monospaced))
                                        .foregroundStyle(level.color)
                                    Text(city.name.uppercased())
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(AppTheme.foreground)
                                        .lineLimit(1)
                                }
                                Text("\(city.cameraCount) PINS")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AppTheme.accent)
                                StatusBadge(text: level.chip, color: level.color)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(AppTheme.card.opacity(0.94))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(level.color.opacity(0.35), lineWidth: 1)
                            )
                            .shadow(color: level.color.opacity(0.12), radius: 8, y: 0)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(AppTheme.card.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.primary.opacity(0.25), lineWidth: 1)
        )
    }
}
