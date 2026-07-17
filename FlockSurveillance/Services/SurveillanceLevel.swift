import CoreLocation
import Foundation
import SwiftUI

/// How hard the mapped ALPR grid is pressing on you right now.
/// Pure density + proximity math — never plate-read claims.
enum SurveillanceLevel: Int, CaseIterable, Comparable, Sendable {
    case clear = 0
    case low = 1
    case elevated = 2
    case high = 3
    case critical = 4

    static func < (lhs: SurveillanceLevel, rhs: SurveillanceLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Short HUD chip: CLEAR / LOW / ELEV / HIGH / HOT
    var chip: String {
        switch self {
        case .clear: return "CLEAR"
        case .low: return "LOW"
        case .elevated: return "ELEV"
        case .high: return "HIGH"
        case .critical: return "HOT"
        }
    }

    /// Full instrument title under the dial.
    var title: String {
        switch self {
        case .clear: return "CLEAR SKY"
        case .low: return "SPARSE GRID"
        case .elevated: return "HEAVY COVERAGE"
        case .high: return "DENSE GRID"
        case .critical: return "HOT ZONE"
        }
    }

    var color: Color {
        switch self {
        case .clear: return AppTheme.densityLow
        case .low: return AppTheme.accent
        case .elevated: return AppTheme.densityMedium
        case .high: return AppTheme.primary
        case .critical: return AppTheme.critical
        }
    }

    /// 0…1 fill for the outer threat arc.
    var dialFill: CGFloat {
        switch self {
        case .clear: return 0.12
        case .low: return 0.32
        case .elevated: return 0.55
        case .high: return 0.78
        case .critical: return 1.0
        }
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
        var level: SurveillanceLevel

        switch visibleCount {
        case 0: level = .clear
        case 1...4: level = .low
        case 5...14: level = .elevated
        case 15...29: level = .high
        default: level = .critical
        }

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
