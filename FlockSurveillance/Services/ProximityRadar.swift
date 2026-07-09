import CoreLocation
import Foundation
import UIKit

@MainActor
@Observable
final class ProximityRadar {
    var hapticsEnabled: Bool {
        didSet { AppPreferences.hapticsEnabled = hapticsEnabled }
    }

    var watchModeEnabled = false

    private var lastPulseDistance: CLLocationDistance = .greatestFiniteMagnitude
    private var lastWatchPulseAt: Date = .distantPast
    private let generator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)

    init() {
        hapticsEnabled = AppPreferences.hapticsEnabled
    }

    func update(userLocation: CLLocation?, nearestMeters: CLLocationDistance?) {
        guard hapticsEnabled, let nearestMeters else { return }

        if watchModeEnabled {
            updateWatchCadence(nearestMeters: nearestMeters)
        }

        let thresholds: [CLLocationDistance] = [400, 200, 100, 50]
        for threshold in thresholds {
            if nearestMeters <= threshold, lastPulseDistance > threshold {
                generator.prepare()
                generator.impactOccurred(intensity: threshold <= 100 ? 1.0 : 0.7)
                break
            }
        }
        lastPulseDistance = nearestMeters
    }

    private func updateWatchCadence(nearestMeters: CLLocationDistance) {
        let interval: TimeInterval
        switch nearestMeters {
        case ..<50: interval = 1.2
        case ..<100: interval = 2.0
        case ..<200: interval = 3.5
        case ..<400: interval = 5.0
        default: return
        }

        let now = Date()
        guard now.timeIntervalSince(lastWatchPulseAt) >= interval else { return }
        lastWatchPulseAt = now
        heavyGenerator.prepare()
        heavyGenerator.impactOccurred(intensity: nearestMeters < 100 ? 1.0 : 0.65)
    }

    static func formatDistance(_ meters: CLLocationDistance) -> String {
        let miles = meters / 1609.34
        if miles >= 0.1 {
            return String(format: "%.1f mi", miles)
        }
        let feet = meters * 3.28084
        return String(format: "%.0f ft", feet)
    }
}
