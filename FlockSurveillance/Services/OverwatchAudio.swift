import AudioToolbox
import Foundation
import UIKit

/// Short system stings for Overwatch state changes.
/// No custom asset pipeline — AudioServices + haptic only.
@MainActor
enum OverwatchAudio {
    private static var lastCriticalStingAt: Date = .distantPast
    private static var lastZoneEnterAt: Date = .distantPast
    private static var lastZoneExitAt: Date = .distantPast
    private static let criticalCooldown: TimeInterval = 12
    private static let zoneCooldown: TimeInterval = 4

    /// Fire when surveillance level crosses into `.critical`.
    static func stingIfEnteringCritical(
        previous: SurveillanceLevel?,
        current: SurveillanceLevel
    ) {
        guard current == .critical else { return }
        guard previous != .critical else { return }

        let now = Date()
        guard now.timeIntervalSince(lastCriticalStingAt) >= criticalCooldown else { return }
        lastCriticalStingAt = now

        // 1057 ≈ lock / tink; 1521 ≈ modern alert.
        AudioServicesPlaySystemSound(1057)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            AudioServicesPlaySystemSound(1521)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Entering a mapped ALPR corridor (geofence / proximity).
    static func zoneEnter() {
        let now = Date()
        guard now.timeIntervalSince(lastZoneEnterAt) >= zoneCooldown else { return }
        lastZoneEnterAt = now

        AudioServicesPlaySystemSound(1005) // new mail-ish alert
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
    }

    /// Leaving a mapped corridor after linger.
    static func zoneExit() {
        let now = Date()
        guard now.timeIntervalSince(lastZoneExitAt) >= zoneCooldown else { return }
        lastZoneExitAt = now

        AudioServicesPlaySystemSound(1114) // end-record soft
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Soft arm/disarm click for Overwatch toggle.
    static func armClick() {
        AudioServicesPlaySystemSound(1104) // keyboard tap
    }

    /// App / map session online.
    static func bootPing() {
        AudioServicesPlaySystemSound(1103)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
    }
}
