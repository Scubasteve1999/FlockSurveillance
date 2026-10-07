import AudioToolbox
import Foundation
import UIKit

/// Shows the Map boot banner (and its ping) at most once per app launch.
/// App-scoped on purpose: view `@State` resets whenever the Map view is rebuilt.
@MainActor
enum BootBannerGate {
    private(set) static var hasShown = false

    /// Returns true exactly once per launch.
    static func claim() -> Bool {
        guard !hasShown else { return false }
        hasShown = true
        return true
    }

    static func resetForTesting() { hasShown = false }
}

/// Short system stings for Overwatch state changes.
/// No custom asset pipeline — AudioServices + haptic only.
/// Every sound goes through `play(_:)`, the single gate for the Sounds setting.
/// Haptics are deliberately outside that gate.
@MainActor
enum OverwatchAudio {
    private static var lastCriticalStingAt: Date = .distantPast
    private static var lastZoneEnterAt: Date = .distantPast
    private static var lastZoneExitAt: Date = .distantPast
    private static let criticalCooldown: TimeInterval = 12
    private static let zoneCooldown: TimeInterval = 4

    /// Where sounds are actually played. Tests swap this to observe the gate.
    static var soundSink: (SystemSoundID) -> Void = { AudioServicesPlaySystemSound($0) }

    /// Central gate: all app sounds funnel through here.
    static func play(_ id: SystemSoundID) {
        guard AppPreferences.soundsEnabled else { return }
        soundSink(id)
    }

    static func resetCooldownsForTesting() {
        lastCriticalStingAt = .distantPast
        lastZoneEnterAt = .distantPast
        lastZoneExitAt = .distantPast
    }

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
        play(1057)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            play(1521)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Entering a mapped ALPR corridor (geofence / proximity).
    static func zoneEnter() {
        let now = Date()
        guard now.timeIntervalSince(lastZoneEnterAt) >= zoneCooldown else { return }
        lastZoneEnterAt = now

        play(1005) // new mail-ish alert
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
    }

    /// Leaving a mapped corridor after linger.
    static func zoneExit() {
        let now = Date()
        guard now.timeIntervalSince(lastZoneExitAt) >= zoneCooldown else { return }
        lastZoneExitAt = now

        play(1114) // end-record soft
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Soft arm/disarm click for Overwatch toggle.
    static func armClick() {
        play(1104) // keyboard tap
    }

    /// App / map session online.
    static func bootPing() {
        play(1103)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
    }
}
