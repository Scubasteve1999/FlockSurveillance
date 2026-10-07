import SwiftUI

/// The one pin-density scale. Map, Place Score, Route, Drive, onboarding, widget and
/// share cards all show these five words and colors — never a second ladder.
///
/// Density is a count of mapped OSM pins, nothing more. Being inside a pin's alert
/// radius ("PIN ZONE") is proximity, not density, and is never one of these levels.
enum PinDensity: Int, CaseIterable, Comparable, Sendable {
    case clear = 0
    case light = 1
    case moderate = 2
    case heavy = 3
    case saturated = 4

    /// Minimum pin count for each level above Clear. Contexts that measure different
    /// things (pins in view, near a point, along a route) pass their own thresholds,
    /// but always land on the same labels and colors.
    struct Scale: Equatable, Sendable {
        let light: Int
        let moderate: Int
        let heavy: Int
        let saturated: Int

        /// Pins inside the visible map region.
        static let inView = Scale(light: 1, moderate: 5, heavy: 15, saturated: 30)
        /// Pins within a radius of one point — Place Score, Home widget, AR.
        static let nearPlace = Scale(light: 1, moderate: 5, heavy: 15, saturated: 30)
        /// Pins along a driving route corridor.
        static let route = Scale(light: 1, moderate: 4, heavy: 10, saturated: 20)
    }

    struct RGB: Equatable, Sendable {
        let red: Double
        let green: Double
        let blue: Double
    }

    init(count: Int, scale: Scale) {
        switch count {
        case scale.saturated...: self = .saturated
        case scale.heavy...: self = .heavy
        case scale.moderate...: self = .moderate
        case scale.light...: self = .light
        default: self = .clear
        }
    }

    static func < (lhs: PinDensity, rhs: PinDensity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Calm, factual density word.
    var label: String {
        switch self {
        case .clear: return "Clear"
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .heavy: return "Heavy"
        case .saturated: return "Saturated"
        }
    }

    /// One color per level. Cool (green, cyan) only for Clear and Light; warmer as it climbs.
    var rgb: RGB {
        switch self {
        case .clear: return RGB(red: 0.22, green: 0.92, blue: 0.55)
        case .light: return RGB(red: 0.18, green: 0.92, blue: 0.88)
        case .moderate: return RGB(red: 1.0, green: 0.72, blue: 0.18)
        case .heavy: return RGB(red: 1.0, green: 0.32, blue: 0.22)
        case .saturated: return RGB(red: 1.0, green: 0.12, blue: 0.28)
        }
    }

    var color: Color {
        Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    /// 0…1 fill for dials and meters.
    var fill: CGFloat {
        switch self {
        case .clear: return 0.12
        case .light: return 0.32
        case .moderate: return 0.55
        case .heavy: return 0.78
        case .saturated: return 1.0
        }
    }
}
