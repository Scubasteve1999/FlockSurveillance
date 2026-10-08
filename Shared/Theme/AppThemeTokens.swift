import SwiftUI

/// Every color and layout metric. Shared so the app, widget and Live Activity use the same
/// values; no hand-copied RGB in views. Density colors live on `PinDensity`.
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

    /// Density palette lives on `PinDensity` (Shared, so the widget uses the same colors).
    static let densityLow = PinDensity.clear.color
    static let densityMedium = PinDensity.moderate.color
    static let densityHigh = PinDensity.heavy.color
    /// Saturated density.
    static let critical = PinDensity.saturated.color
    /// Inside a mapped pin's alert radius — proximity, never a density level.
    static let zoneTint = primary

    static let flockMarker = Color(red: 1.0, green: 0.32, blue: 0.22)
    static let otherMarker = Color(red: 0.18, green: 0.92, blue: 0.88)
    /// Municipal traffic CCTV (Sensor Atlas) — distinct from ALPR markers.
    static let trafficSensorMarker = Color(red: 1.0, green: 0.82, blue: 0.22)
    /// Sharing Network bidirectional links (hub ↔ partner).
    static let sharingBidirectional = Color(red: 0.95, green: 0.72, blue: 0.28)
    static let entranceMatch = densityLow
    static let entranceNearMiss = densityMedium
    static let entranceGap = mutedForeground
    static let entranceLayerMarker = densityMedium

    static let cornerRadius: CGFloat = 16
    /// Primary / secondary CTA corners (Drive, Route, etc.).
    static let buttonCornerRadius: CGFloat = 12
    static let cardPadding: CGFloat = 16
}
