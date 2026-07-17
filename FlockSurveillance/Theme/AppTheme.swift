import SwiftUI

enum AppTheme {
    /// Near-black ops console.
    static let background = Color(red: 0.03, green: 0.035, blue: 0.05)
    static let foreground = Color(red: 0.96, green: 0.97, blue: 0.99)
    /// Hot coral — primary alert / Flock pin energy.
    static let primary = Color(red: 1.0, green: 0.32, blue: 0.22)
    /// Cold cyan HUD instrument.
    static let accent = Color(red: 0.18, green: 0.92, blue: 0.88)
    static let mutedForeground = Color(red: 0.55, green: 0.60, blue: 0.68)
    static let border = Color.white.opacity(0.14)
    static let card = Color(red: 0.07, green: 0.09, blue: 0.12)
    static let cardTop = Color(red: 0.10, green: 0.12, blue: 0.16)
    static let cardBottom = Color(red: 0.05, green: 0.06, blue: 0.09)

    static let densityLow = Color(red: 0.22, green: 0.92, blue: 0.55)
    static let densityMedium = Color(red: 1.0, green: 0.72, blue: 0.18)
    static let densityHigh = Color(red: 1.0, green: 0.32, blue: 0.22)
    /// Beyond dense — hot zone pulse.
    static let critical = Color(red: 1.0, green: 0.12, blue: 0.28)

    static let flockMarker = Color(red: 1.0, green: 0.32, blue: 0.22)
    static let otherMarker = Color(red: 0.18, green: 0.92, blue: 0.88)
    /// Municipal traffic CCTV (Sensor Atlas) — distinct from ALPR markers.
    static let trafficSensorMarker = Color(red: 1.0, green: 0.82, blue: 0.22)

    static let cornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 16

    static func densityColor(count: Int) -> Color {
        switch count {
        case 0...4: return densityLow
        case 5...14: return densityMedium
        case 15...29: return densityHigh
        default: return critical
        }
    }

    static func densityLabel(count: Int) -> String {
        switch count {
        case 0: return "Clear"
        case 1...4: return "Low"
        case 5...14: return "Moderate"
        case 15...29: return "Dense"
        default: return "Saturated"
        }
    }
}

struct SectionCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(AppTheme.cardPadding)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [AppTheme.cardTop, AppTheme.cardBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .overlay(
                Capsule().stroke(color.opacity(0.35), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

/// Gates MapKit-backed content on a live, non-degenerate size.
///
/// MapKit hangs if inserted at zero size (CAMetalLayer width=0), so wrap map content in
/// this inside a `GeometryReader` and pass `geo.size` — it shows a spinner until the
/// container has a real frame, which `GeometryReader` guarantees to re-report reactively.
struct MapKitSizeGate<Content: View>: View {
    let size: CGSize
    @ViewBuilder var content: () -> Content

    var body: some View {
        if size.width > 1, size.height > 1 {
            content()
        } else {
            ProgressView()
                .tint(AppTheme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct DataSourcePill: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "map.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("OSM · DeFlock community")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(AppTheme.mutedForeground)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.card.opacity(0.9))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
    }
}
