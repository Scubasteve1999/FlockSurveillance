import CoreLocation
import SwiftUI

/// Telemetry pin count for the mono HUD strings — keeps "1 PIN" from reading "1 PINS".
fileprivate func pinCountLabel(_ count: Int) -> String {
    count == 1 ? "1 PIN" : "\(count) PINS"
}

// MARK: - Page header

/// Shared ops-console header for Route / Learn / Settings.
struct OverwatchPageHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(AppTheme.primary)
            Text(title)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(AppTheme.foreground)
            Text(subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
        }
    }
}

// MARK: - Boot banner

/// Slides in once when Overwatch map comes online, then dismisses.
struct OverwatchBootBanner: View {
    let visibleCount: Int
    let level: SurveillanceLevel
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: BootPhase = .hidden
    @State private var glow = false

    private enum BootPhase {
        case hidden, shown, leaving
    }

    var body: some View {
        Group {
            if phase != .hidden {
                HStack(spacing: 10) {
                    Circle()
                        .fill(level.color)
                        .frame(width: 8, height: 8)
                        .opacity(glow ? 0.3 : 1)
                        .shadow(color: level.color.opacity(0.9), radius: glow ? 8 : 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("OVERWATCH ONLINE")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(AppTheme.foreground)
                        Text("\(pinCountLabel(visibleCount)) IN VIEW · \(level.chip)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(level.color)
                    }
                    Spacer(minLength: 0)
                    Text("OSM")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(AppTheme.mutedForeground)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)
                        .fill(AppTheme.card.opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)
                                .stroke(level.color.opacity(0.55), lineWidth: 1)
                        )
                        .shadow(color: level.color.opacity(0.25), radius: 14, y: 0)
                }
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear { runSequence() }
    }

    private func runSequence() {
        OverwatchAudio.bootPing()
        if reduceMotion {
            phase = .shown
            glow = false
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                phase = .shown
            }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            if reduceMotion {
                phase = .hidden
            } else {
                withAnimation(.easeIn(duration: 0.35)) {
                    phase = .leaving
                }
                try? await Task.sleep(nanoseconds: 380_000_000)
                phase = .hidden
            }
            onFinished()
        }
    }
}

// MARK: - HOT scanlines

/// Subtle CRT scanlines when you're in a watched / HOT corridor.
struct OverwatchScanlines: View {
    var intensity: Double = 0.12
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            EmptyView()
        } else {
            Canvas { context, size in
                let step: CGFloat = 3
                var path = Path()
                for y in stride(from: 0, through: size.height, by: step) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(
                    path,
                    with: .color(Color.white.opacity(intensity * 0.35)),
                    lineWidth: 0.5
                )
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
            .blendMode(.overlay)
            .opacity(0.9)
        }
    }
}

// MARK: - Threat ticker

/// Compact monospaced status line for density / nearest pin.
struct OverwatchThreatTicker: View {
    let visibleCount: Int
    let nearestMeters: CLLocationDistance?
    let level: SurveillanceLevel
    let inWatchedZone: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(inWatchedZone ? "// GRID" : "// MAP")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(level.color)
            Text("·")
                .foregroundStyle(AppTheme.mutedForeground)
            Text(pinCountLabel(visibleCount))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.foreground)
            if let nearestMeters {
                Text("·")
                    .foregroundStyle(AppTheme.mutedForeground)
                Text("LOCK \(ProximityRadar.formatDistance(nearestMeters).uppercased())")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.accent)
            }
            Spacer(minLength: 0)
            Text(level.chip)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(level.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(AppTheme.card.opacity(0.88))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(level.color.opacity(inWatchedZone ? 0.55 : 0.2), lineWidth: 1))
        .padding(.horizontal, 16)
    }
}
