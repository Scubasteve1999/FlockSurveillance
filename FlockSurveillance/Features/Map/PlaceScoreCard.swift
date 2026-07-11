import CoreLocation
import SwiftUI

/// Shared radial bloom used by Place Score in-app and share PNG.
struct WatchednessDial: View {
    let grade: String
    let cameraCount: Int
    var size: CGFloat = 148
    var animate: Bool = true

    @State private var bloom: CGFloat = 0

    private var densityColor: Color {
        AppTheme.densityColor(count: cameraCount)
    }

    private var targetBloom: CGFloat {
        switch cameraCount {
        case 0: return 0.12
        case 1...4: return 0.35
        case 5...14: return 0.65
        default: return 0.95
        }
    }

    /// Share / ImageRenderer paths skip animation and must not depend on `onAppear`.
    private var displayedBloom: CGFloat {
        animate ? bloom : targetBloom
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            densityColor.opacity(0.35),
                            densityColor.opacity(0.08),
                            .clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: size * 0.55
                    )
                )
                .frame(width: size * 1.15, height: size * 1.15)
                .scaleEffect(0.85 + 0.15 * displayedBloom)

            Circle()
                .stroke(AppTheme.border, lineWidth: 10)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: displayedBloom)
                .stroke(
                    densityColor,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text(grade.uppercased())
                    .font(.system(size: size * 0.18, weight: .black))
                    .foregroundStyle(AppTheme.primary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(cameraCount == 1 ? "1 CAM" : "\(cameraCount) CAMS")
                    .font(.system(size: size * 0.08, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.mutedForeground)
            }
        }
        .onAppear {
            guard animate else { return }
            withAnimation(.easeOut(duration: 0.75)) {
                bloom = targetBloom
            }
        }
        .onChange(of: cameraCount) { _, _ in
            guard animate else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                bloom = targetBloom
            }
        }
        .onChange(of: grade) { _, _ in
            guard animate else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                bloom = targetBloom
            }
        }
    }
}

struct PlaceScoreCard: View {
    let score: PlaceScore
    var selectedRadiusMeters: CLLocationDistance = 1609.34
    var onSelectRadius: ((CLLocationDistance) -> Void)?
    let onShare: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            HStack(alignment: .center, spacing: 16) {
                WatchednessDial(grade: score.grade, cameraCount: score.cameraCount, size: 120)

                VStack(alignment: .leading, spacing: 8) {
                    Text(score.headline)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.foreground)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Within \(score.radiusMilesLabel)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.mutedForeground)

                    HStack(spacing: 12) {
                        metric("Flock", "\(score.flockPercent)%")
                        metric("Density", String(format: "%.1f/mi²", score.densityPerSquareMile))
                    }
                }
            }

            if let onSelectRadius {
                HStack(spacing: 8) {
                    radiusChip("1 mi", meters: 1609.34, selected: selectedRadiusMeters < 3000, onSelect: onSelectRadius)
                    radiusChip("5 mi", meters: 8046.72, selected: selectedRadiusMeters >= 3000, onSelect: onSelectRadius)
                }
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
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(AppTheme.mutedForeground)
            Text(value)
                .font(.system(size: 14, weight: .bold))
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
