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

        // Tighter rings + harder hits as you close the pin.
        let thresholds: [CLLocationDistance] = [500, 300, 150, 75, 40]
        for threshold in thresholds {
            if nearestMeters <= threshold, lastPulseDistance > threshold {
                let intensity: CGFloat
                switch threshold {
                case ...40: intensity = 1.0
                case ...75: intensity = 0.95
                case ...150: intensity = 0.8
                default: intensity = 0.55
                }
                if threshold <= 75 {
                    heavyGenerator.prepare()
                    heavyGenerator.impactOccurred(intensity: intensity)
                } else {
                    generator.prepare()
                    generator.impactOccurred(intensity: intensity)
                }
                break
            }
        }
        lastPulseDistance = nearestMeters
    }

    private func updateWatchCadence(nearestMeters: CLLocationDistance) {
        let interval: TimeInterval
        switch nearestMeters {
        case ..<40: interval = 0.7
        case ..<75: interval = 1.1
        case ..<150: interval = 1.8
        case ..<300: interval = 2.8
        case ..<500: interval = 4.0
        default: return
        }

        let now = Date()
        guard now.timeIntervalSince(lastWatchPulseAt) >= interval else { return }
        lastWatchPulseAt = now
        heavyGenerator.prepare()
        heavyGenerator.impactOccurred(intensity: nearestMeters < 75 ? 1.0 : 0.7)
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
