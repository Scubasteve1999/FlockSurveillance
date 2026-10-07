import CoreLocation
import Foundation

/// Internal feedback intensity: viewport density plus GPS proximity to mapped pins.
/// Drives scanline strength and the critical audio sting only — it is never displayed.
/// The user-facing density word and color always come from `PinDensity`; being inside
/// an alert radius is shown as "PIN ZONE" (`WatchedZoneCopy`), not as a level.
enum SurveillanceLevel: Int, CaseIterable, Comparable, Sendable {
    case clear = 0
    case low = 1
    case elevated = 2
    case high = 3
    case critical = 4

    static func < (lhs: SurveillanceLevel, rhs: SurveillanceLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Compute from what the map + GPS actually know.
    ///
    /// Priority: inside a watched corridor always elevates; nearest pin distance
    /// and viewport density stack on top. Pure public-map math.
    static func compute(
        visibleCount: Int,
        nearestMeters: CLLocationDistance?,
        inWatchedZone: Bool
    ) -> SurveillanceLevel {
        // Density baseline uses the same thresholds as the map's density word.
        var level = SurveillanceLevel(
            rawValue: PinDensity(count: visibleCount, scale: .inView).rawValue
        ) ?? .clear

        if let nearestMeters {
            if nearestMeters <= 50 {
                level = max(level, .critical)
            } else if nearestMeters <= 100 {
                level = max(level, .high)
            } else if nearestMeters <= 200 {
                level = max(level, .elevated)
            } else if nearestMeters <= 400 {
                level = max(level, .low)
            }
        }

        if inWatchedZone {
            // You're inside a mapped corridor — never rate that calm.
            level = max(level, .high)
            if let nearestMeters, nearestMeters <= 80 {
                level = .critical
            } else if visibleCount >= 10 {
                level = .critical
            }
        }

        return level
    }
}
