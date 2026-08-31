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
        .accessibilityLabel(count > 1 ? "\(count) mapped ALPR cameras" : "mapped ALPR camera")
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

    /// One headline: WATCHED ZONE while inside, otherwise the surveillance title.
    /// Density (Saturated, etc.) stays a badge — not a second shout.
    private var headline: String {
        if inWatchedZone { return WatchedZoneCopy.hudActiveLabel }
        return level.title
    }

    private var visibleCountLabel: String {
        visibleCount == 1 ? "1 mapped pin" : "\(visibleCount) mapped pins"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                tacticalDial
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        inWatchedZone
                            ? "Watched zone. \(visibleCountLabel) in view, \(headline). Phone near mapped ALPR pins, not a plate-read alert."
                            : "\(visibleCountLabel) in view, \(headline)"
                    )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if inWatchedZone || watchModeEnabled {
                            Circle()
                                .fill(levelColor)
                                .frame(width: 7, height: 7)
                                .opacity(zonePulse ? 0.2 : 1)
                                .shadow(color: levelColor.opacity(0.9), radius: zonePulse ? 6 : 2)
                        }
                        Text(headline)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.foreground)
                            .fixedSize(horizontal: false, vertical: true)
                            .contentTransition(.opacity)
                    }

                    StatusBadge(text: densityLabel, color: AppTheme.densityColor(count: visibleCount))

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
                            Text(WatchedZoneCopy.mappedOperatorCaption(nearestLabel))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.mutedForeground)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text("NO LOCK")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.mutedForeground)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
                .accessibilityLabel(confidence.instrumentAccessibilityLabel)

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

            HStack(alignment: .center, spacing: 8) {
                DataSourcePill()
                Spacer(minLength: 8)
                overwatchToggle
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

    private var overwatchToggle: some View {
        Button(action: onToggleWatch) {
            HStack(spacing: 5) {
                Image(systemName: watchModeEnabled ? "eye.fill" : "eye")
                    .font(.system(size: 12, weight: .bold))
                Text(watchModeEnabled ? "ON" : "SET")
                    .font(.system(size: 11, weight: .black))
                    .tracking(0.6)
            }
            .foregroundStyle(watchModeEnabled ? AppTheme.background : AppTheme.foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                watchModeEnabled
                    ? AnyShapeStyle(LinearGradient(
                        colors: [AppTheme.primary, AppTheme.critical],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    : AnyShapeStyle(AppTheme.card)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)
                    .stroke(
                        watchModeEnabled ? AppTheme.primary.opacity(0.0) : AppTheme.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel(watchModeEnabled ? "Disable overwatch mode" : "Set overwatch mode")
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

            // Quiet Overwatch tick — short arc, not a live-detector sweep.
            if watchModeEnabled || inWatchedZone {
                Circle()
                    .trim(from: 0, to: 0.07)
                    .stroke(
                        levelColor.opacity(0.45),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 108, height: 108)
                    .rotationEffect(.degrees(sweepAngle))
                    .opacity(0.7)
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
                Text(visibleCount == 1 ? "PIN" : "PINS")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.mutedForeground)
            }
        }
        .frame(width: 118, height: 118)
    }

    private func startSweep() {
        guard !reduceMotion else {
            sweepAngle = 45
            return
        }
        withAnimation(.linear(duration: 4.2).repeatForever(autoreverses: false)) {
            sweepAngle = 360
        }
    }

    private func updateZonePulse(_ active: Bool) {
        if active {
            if reduceMotion {
                zonePulse = true
                return
            }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                if reduceMotion {
                    pulse = true
                } else {
                    withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
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
                Text("Enable location to show nearby mapped pins and route exposure.")
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
