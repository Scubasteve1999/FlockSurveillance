import CoreLocation
import SwiftUI

struct CameraAnnotationView: View {
    let count: Int
    let isFlock: Bool

    private var color: Color {
        isFlock ? AppTheme.flockMarker : AppTheme.otherMarker
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.22))
                .frame(width: count > 1 ? 44 : 34, height: count > 1 ? 44 : 34)
            Circle()
                .fill(color)
                .frame(width: count > 1 ? 28 : 18, height: count > 1 ? 28 : 18)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                )
            if count > 1 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .shadow(color: color.opacity(0.45), radius: 6, y: 2)
        .accessibilityLabel(count > 1 ? "\(count) ALPR cameras" : "ALPR camera")
    }
}

struct RadarHUD: View {
    let visibleCount: Int
    let nearestMeters: CLLocationDistance?
    let nearestLabel: String?
    let densityLabel: String
    let isLoading: Bool
    let errorMessage: String?
    let coverageHint: String?
    let freshnessLabel: String?
    let watchModeEnabled: Bool
    let onToggleWatch: () -> Void
    var onOpenDeFlockMaps: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(watchModeEnabled ? "LIVE WATCH" : "PROXIMITY RADAR")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(watchModeEnabled ? AppTheme.primary : AppTheme.mutedForeground)
                    Text("\(visibleCount)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.foreground)
                        .contentTransition(.numericText())
                    Text("cameras in view")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.mutedForeground)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    StatusBadge(text: densityLabel, color: AppTheme.densityColor(count: visibleCount))
                    if let nearestMeters {
                        Text("Nearest \(ProximityRadar.formatDistance(nearestMeters))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    } else {
                        Text("No nearby hit")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground)
                    }
                    if let nearestLabel {
                        Text(nearestLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground)
                            .lineLimit(1)
                    }
                }
            }

            if watchModeEnabled, let nearestMeters {
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppTheme.primary)
                        .frame(width: 8, height: 8)
                        .opacity(0.9)
                    Text("Watching · \(ProximityRadar.formatDistance(nearestMeters)) to nearest ALPR")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.foreground)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if let coverageHint {
                Text(coverageHint)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                DataSourcePill()
                Spacer()
                Button(action: onToggleWatch) {
                    Text(watchModeEnabled ? "Watching" : "Watch")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(watchModeEnabled ? AppTheme.background : AppTheme.foreground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(watchModeEnabled ? AppTheme.primary : AppTheme.card)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.border, lineWidth: watchModeEnabled ? 0 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(watchModeEnabled ? "Disable watch mode" : "Enable watch mode")

                if isLoading {
                    ProgressView()
                        .tint(AppTheme.accent)
                        .scaleEffect(0.8)
                }
            }

            if let onOpenDeFlockMaps {
                Button(action: onOpenDeFlockMaps) {
                    HStack(spacing: 6) {
                        Image(systemName: "safari")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Open DeFlock Maps")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(AppTheme.card.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open DeFlock Maps")
            }

            if let freshnessLabel {
                Text(freshnessLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

struct LocationDeniedBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.slash.fill")
                .foregroundStyle(AppTheme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Location off")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.foreground)
                Text("Enable location to power radar and route exposure.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
            }
            Spacer()
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(AppTheme.accent)
        }
        .padding(12)
        .background(AppTheme.card.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}
