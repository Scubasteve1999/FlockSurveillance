import CoreLocation
import SwiftUI

struct PlaceScoreCard: View {
    let score: PlaceScore
    var selectedRadiusMeters: CLLocationDistance = 1609.34
    var onSelectRadius: ((CLLocationDistance) -> Void)?
    let onShare: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("HOW WATCHED?")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.mutedForeground)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.mutedForeground)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.card)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Text(score.headline)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.foreground)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline) {
                Text(score.grade)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.primary)
                Spacer()
                StatusBadge(
                    text: score.cameraCountLabel,
                    color: AppTheme.densityColor(count: score.cameraCount)
                )
            }

            if let onSelectRadius {
                HStack(spacing: 8) {
                    radiusChip("1 mi", meters: 1609.34, selected: selectedRadiusMeters < 3000, onSelect: onSelectRadius)
                    radiusChip("5 mi", meters: 8046.72, selected: selectedRadiusMeters >= 3000, onSelect: onSelectRadius)
                }
            }

            Text("Within \(score.radiusMilesLabel) of this spot")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)

            HStack(spacing: 16) {
                metric("Flock", "\(score.flockPercent)%")
                metric("Density", String(format: "%.1f/mi²", score.densityPerSquareMile))
                metric("Flock #", "\(score.flockCount)")
            }

            Button(action: onShare) {
                Label("Share how watched you are", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(AppTheme.foreground)
                    .background(AppTheme.cardTop)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(AppTheme.mutedForeground)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.foreground)
        }
    }

    private func radiusChip(
        _ title: String,
        meters: CLLocationDistance,
        selected: Bool,
        onSelect: @escaping (CLLocationDistance) -> Void
    ) -> some View {
        Button {
            onSelect(meters)
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? AppTheme.background : AppTheme.foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? AppTheme.accent : AppTheme.card)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.border, lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }
}
