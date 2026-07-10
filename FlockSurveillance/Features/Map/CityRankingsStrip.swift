import MapKit
import SwiftUI

/// Horizontal strip of most-mapped metros for social proof on an empty / zoomed-out map.
struct CityRankingsStrip: View {
    let rankings: [CityRanking]
    let onSelect: (CityRanking) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MOST MAPPED METROS")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.accent)

            Text("From cameras on this device — not a national census.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(rankings.enumerated()), id: \.element.id) { index, city in
                        Button {
                            onSelect(city)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("#\(index + 1) \(city.name)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(AppTheme.foreground)
                                Text(city.subtitle)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppTheme.mutedForeground)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(AppTheme.card.opacity(0.92))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(AppTheme.card.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}
