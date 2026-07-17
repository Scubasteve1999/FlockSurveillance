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
                .fill(color.opacity(0.28))
                .frame(width: count > 1 ? 48 : 38, height: count > 1 ? 48 : 38)
                .blur(radius: 0.5)
            Circle()
                .fill(color)
                .frame(width: count > 1 ? 28 : 18, height: count > 1 ? 28 : 18)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                )
            if count > 1 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white)
            }
        }
        .shadow(color: color.opacity(0.7), radius: 10, y: 0)
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
    @State private var sweepAngle: Double = 0

    private var level: SurveillanceLevel {
        SurveillanceLevel.compute(
            visibleCount: visibleCount,
            nearestMeters: nearestMeters,
            inWatchedZone: inWatchedZone
        )
    }

    private var levelColor: Color { level.color }

    private var targetRing: CGFloat { level.dialFill }

    private var modeLabel: String {
        if inWatchedZone { return WatchedZoneCopy.hudActiveLabel }
        if watchModeEnabled { return "OVERWATCH LIVE" }
        return "OVERWATCH"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                tacticalDial
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        inWatchedZone
                            ? "Watched zone. \(visibleCount) cameras in view, \(level.title). Phone near mapped ALPR pins, not a plate-read alert."
                            : "\(visibleCount) cameras in view, \(level.title)"
                    )

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        if inWatchedZone || watchModeEnabled {
                            Circle()
                                .fill(levelColor)
                                .frame(width: 7, height: 7)
                                .opacity(zonePulse ? 0.2 : 1)
                                .shadow(color: levelColor.opacity(0.9), radius: zonePulse ? 6 : 2)
                        }
                        Text(modeLabel)
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.1)
                            .foregroundStyle(inWatchedZone || watchModeEnabled ? levelColor : AppTheme.mutedForeground)
                    }

                    HStack(spacing: 6) {
                        StatusBadge(text: level.chip, color: levelColor)
                        StatusBadge(text: densityLabel, color: AppTheme.densityColor(count: visibleCount))
                    }

                    Text(level.title)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.foreground)
                        .contentTransition(.opacity)

                    if inWatchedZone {
                        Text(WatchedZoneCopy.hudActiveSubtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let nearestMeters {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("LOCK")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.mutedForeground)
                            Text(ProximityRadar.formatDistance(nearestMeters))
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(AppTheme.accent)
                                .contentTransition(.numericText())
                        }
                        if let nearestLabel {
                            Text(nearestLabel)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.mutedForeground)
                                .lineLimit(1)
                        }
                    } else {
                        Text("NO LOCK")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.mutedForeground)
                    }
                }

                Spacer(minLength: 0)

                Button(action: onToggleWatch) {
                    VStack(spacing: 3) {
                        Image(systemName: watchModeEnabled ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right")
                            .font(.system(size: 14, weight: .bold))
                        Text(watchModeEnabled ? "LIVE" : "ARM")
                            .font(.system(size: 10, weight: .black))
                            .tracking(0.6)
                    }
                    .foregroundStyle(watchModeEnabled ? AppTheme.background : AppTheme.foreground)
                    .frame(width: 56, height: 56)
                    .background(
                        watchModeEnabled
                            ? AnyShapeStyle(LinearGradient(
                                colors: [AppTheme.primary, AppTheme.critical],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            : AnyShapeStyle(AppTheme.card)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                watchModeEnabled ? AppTheme.primary.opacity(0.0) : AppTheme.border,
                                lineWidth: 1
                            )
                    )
                    .shadow(color: watchModeEnabled ? AppTheme.primary.opacity(0.55) : .clear, radius: 10, y: 0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(watchModeEnabled ? "Disable overwatch mode" : "Arm overwatch mode")
            }

            // Threat meter bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.border.opacity(0.5))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.densityLow,
                                    AppTheme.densityMedium,
                                    AppTheme.primary,
                                    AppTheme.critical
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * targetRing))
                        .shadow(color: levelColor.opacity(0.6), radius: 6, y: 0)
                }
            }
            .frame(height: 5)
            .clipShape(Capsule())

            Text(confidence.instrumentLine)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.mutedForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

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
                Text("ROUTE · lower-cam drives")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.mutedForeground)
            }
        }
        .padding(14)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                levelColor.opacity(inWatchedZone ? 0.18 : 0.06),
                                AppTheme.card.opacity(0.85),
                                AppTheme.cardBottom.opacity(0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(
                    inWatchedZone
                        ? levelColor.opacity(zonePulse ? 0.35 : 0.95)
                        : AppTheme.border,
                    lineWidth: inWatchedZone ? 1.5 : 1
                )
        )
        .shadow(color: inWatchedZone ? levelColor.opacity(0.35) : .black.opacity(0.4), radius: inWatchedZone ? 16 : 8, y: 4)
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                ringProgress = targetRing
            }
            startSweep()
            if inWatchedZone || watchModeEnabled {
                updateZonePulse(true)
            }
        }
        .onChange(of: visibleCount) { _, _ in
            withAnimation(.easeInOut(duration: 0.45)) {
                ringProgress = targetRing
            }
        }
        .onChange(of: nearestMeters) { _, _ in
            withAnimation(.easeInOut(duration: 0.35)) {
                ringProgress = targetRing
            }
        }
        .onChange(of: inWatchedZone) { _, inside in
            withAnimation(.easeInOut(duration: 0.35)) {
                ringProgress = targetRing
            }
            if inside {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
            }
            updateZonePulse(inside || watchModeEnabled)
        }
        .onChange(of: watchModeEnabled) { _, enabled in
            if enabled {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                OverwatchAudio.armClick()
            }
            updateZonePulse(enabled || inWatchedZone)
        }
        .onChange(of: level) { previous, current in
            OverwatchAudio.stingIfEnteringCritical(previous: previous, current: current)
        }
    }

    private var tacticalDial: some View {
        ZStack {
            // Outer glow when hot
            if level >= .high {
                Circle()
                    .fill(levelColor.opacity(zonePulse ? 0.22 : 0.08))
                    .frame(width: 118, height: 118)
                    .blur(radius: 8)
            }

            // Track
            Circle()
                .stroke(AppTheme.border.opacity(0.7), lineWidth: 9)
                .frame(width: 92, height: 92)

            // Threat arc
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    AngularGradient(
                        colors: [
                            AppTheme.densityLow,
                            AppTheme.densityMedium,
                            AppTheme.primary,
                            AppTheme.critical
                        ],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .frame(width: 92, height: 92)
                .rotationEffect(.degrees(-90))
                .shadow(color: levelColor.opacity(0.55), radius: 6, y: 0)

            // Radar sweep (overwatch / zone)
            if watchModeEnabled || inWatchedZone {
                Circle()
                    .trim(from: 0, to: 0.18)
                    .stroke(
                        levelColor.opacity(0.85),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: 108, height: 108)
                    .rotationEffect(.degrees(sweepAngle))
                    .opacity(0.9)
            }

            if inWatchedZone {
                Circle()
                    .stroke(levelColor.opacity(zonePulse ? 0.15 : 0.9), lineWidth: 2)
                    .frame(width: 108, height: 108)
                    .scaleEffect(zonePulse ? 1.1 : 1.0)
            }

            VStack(spacing: 1) {
                Text("\(visibleCount)")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.foreground)
                    .contentTransition(.numericText())
                Text(inWatchedZone ? "HOT" : (watchModeEnabled ? "LIVE" : "VIEW"))
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(inWatchedZone || watchModeEnabled ? levelColor : AppTheme.mutedForeground)
            }
        }
        .frame(width: 118, height: 118)
    }

    private func startSweep() {
        withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
            sweepAngle = 360
        }
    }

    private func updateZonePulse(_ active: Bool) {
        if active {
            zonePulse = false
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                zonePulse = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.25)) {
                zonePulse = false
            }
        }
    }
}

/// Full-bleed edge vignette when you're inside a watched corridor.
struct WatchedZoneEdgeAlert: View {
    let level: SurveillanceLevel
    @State private var pulse = false

    var body: some View {
        let c = level.color
        RoundedRectangle(cornerRadius: 0)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        c.opacity(pulse ? 0.85 : 0.35),
                        c.opacity(0.05),
                        c.opacity(pulse ? 0.75 : 0.25)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 4
            )
            .shadow(color: c.opacity(pulse ? 0.55 : 0.2), radius: 18, y: 0)
            .allowsHitTesting(false)
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    pulse = true
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
