import CoreLocation
import SwiftUI
import UIKit

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
    /// Nearest mapped camera is within alert-geofence range — "watched right now".
    let inWatchedZone: Bool
    let densityLabel: String
    let confidence: CoverageConfidence
    let coverageHint: String?
    let errorMessage: String?
    let watchModeEnabled: Bool
    let onToggleWatch: () -> Void

    @State private var ringProgress: CGFloat = 0
    @State private var zonePulse = false

    private var densityColor: Color {
        AppTheme.densityColor(count: visibleCount)
    }

    private var targetRing: CGFloat {
        switch visibleCount {
        case 0: return 0.08
        case 1...4: return 0.32
        case 5...14: return 0.62
        default: return 0.92
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(AppTheme.border, lineWidth: 8)
                        .frame(width: 88, height: 88)

                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(
                            densityColor,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 88, height: 88)
                        .rotationEffect(.degrees(-90))

                    if inWatchedZone {
                        Circle()
                            .stroke(AppTheme.primary.opacity(zonePulse ? 0.2 : 0.8), lineWidth: 2)
                            .frame(width: 102, height: 102)
                            .scaleEffect(zonePulse ? 1.08 : 1.0)
                    } else if watchModeEnabled {
                        Circle()
                            .stroke(AppTheme.primary.opacity(0.55), lineWidth: 2)
                            .frame(width: 102, height: 102)
                            .opacity(0.9)
                    }

                    VStack(spacing: 0) {
                        Text("\(visibleCount)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.foreground)
                            .contentTransition(.numericText())
                        Text(inWatchedZone ? "ZONE" : (watchModeEnabled ? "LIVE" : "VIEW"))
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(inWatchedZone || watchModeEnabled ? AppTheme.primary : AppTheme.mutedForeground)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    inWatchedZone
                        ? "In a watched zone. \(visibleCount) cameras in view, \(densityLabel) density"
                        : "\(visibleCount) cameras in view, \(densityLabel) density"
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        if inWatchedZone {
                            Circle()
                                .fill(AppTheme.primary)
                                .frame(width: 6, height: 6)
                                .opacity(zonePulse ? 0.25 : 1)
                        }
                        Text(inWatchedZone ? "IN A WATCHED ZONE" : (watchModeEnabled ? "LIVE WATCH" : "PROXIMITY RADAR"))
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(inWatchedZone || watchModeEnabled ? AppTheme.primary : AppTheme.mutedForeground)
                    }

                    StatusBadge(text: densityLabel, color: densityColor)

                    if let nearestMeters {
                        Text("Lock \(ProximityRadar.formatDistance(nearestMeters))")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                        if let nearestLabel {
                            Text(nearestLabel)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.mutedForeground)
                                .lineLimit(1)
                        }
                    } else {
                        Text("No nearby lock")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedForeground)
                    }
                }

                Spacer(minLength: 0)

                Button(action: onToggleWatch) {
                    Text(watchModeEnabled ? "Watching" : "Watch")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(watchModeEnabled ? AppTheme.background : AppTheme.foreground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(watchModeEnabled ? AppTheme.primary : AppTheme.card)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.border, lineWidth: watchModeEnabled ? 0 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(watchModeEnabled ? "Disable watch mode" : "Enable watch mode")
            }

            Text(confidence.instrumentLine)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.mutedForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let coverageHint {
                Text(coverageHint)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                DataSourcePill()
                Spacer()
                Text("Lower-camera drives on Route")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                ringProgress = targetRing
            }
            if inWatchedZone {
                updateZonePulse(true)
            }
        }
        .onChange(of: visibleCount) { _, _ in
            withAnimation(.easeInOut(duration: 0.45)) {
                ringProgress = targetRing
            }
        }
        .onChange(of: watchModeEnabled) { _, enabled in
            if enabled {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
        .onChange(of: inWatchedZone) { _, inside in
            if inside {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
            updateZonePulse(inside)
        }
    }

    private func updateZonePulse(_ active: Bool) {
        if active {
            zonePulse = false
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                zonePulse = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.3)) {
                zonePulse = false
            }
        }
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
