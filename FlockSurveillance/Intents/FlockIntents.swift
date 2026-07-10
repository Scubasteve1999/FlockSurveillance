import AppIntents
import CoreLocation
import Foundation

extension Notification.Name {
    /// Posted by CheckPlaceScoreIntent so the map computes a Place Score on arrival.
    static let flockPlaceScore = Notification.Name("flockPlaceScore")
}

struct NearbyCamerasIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Nearby ALPRs"
    static let description = IntentDescription("Counts community-mapped ALPR cameras within a mile of Home.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let snapshot = WidgetBridge.readSnapshot()
        guard WidgetBridge.homeCoordinate() != nil else {
            return .result(dialog: "Set a Home location in Flock Surveillance settings first.")
        }
        var dialog = snapshot.count == 1
            ? "There is 1 ALPR camera within a mile of Home."
            : "There are \(snapshot.count) ALPR cameras within a mile of Home."
        if let nearest = snapshot.nearestMeters {
            dialog += " The nearest is \(ProximityRadar.formatDistance(nearest)) away."
        }
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

struct CheckPlaceScoreIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Place Score"
    static let description = IntentDescription("Opens the map and grades surveillance exposure where you are.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if let url = URL(string: "flocksurveillance://map") {
            NotificationCenter.default.post(name: .flockDeepLink, object: nil, userInfo: ["url": url])
        }
        // Let the map tab mount before asking it to score.
        try? await Task.sleep(nanoseconds: 350_000_000)
        NotificationCenter.default.post(name: .flockPlaceScore, object: nil)
        return .result()
    }
}

struct StartDriveModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Drive Mode"
    static let description = IntentDescription("Opens route analysis so you can start a low-exposure drive.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if let url = URL(string: "flocksurveillance://route") {
            NotificationCenter.default.post(name: .flockDeepLink, object: nil, userInfo: ["url": url])
        }
        return .result()
    }
}

struct FlockShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NearbyCamerasIntent(),
            phrases: [
                "How many cameras are near me in \(.applicationName)",
                "Check nearby ALPRs in \(.applicationName)",
                "Nearby cameras in \(.applicationName)"
            ],
            shortTitle: "Nearby ALPRs",
            systemImageName: "camera.metering.spot"
        )
        AppShortcut(
            intent: CheckPlaceScoreIntent(),
            phrases: [
                "Check my place score in \(.applicationName)",
                "How watched am I in \(.applicationName)"
            ],
            shortTitle: "Place Score",
            systemImageName: "gauge.with.dots.needle.67percent"
        )
        AppShortcut(
            intent: StartDriveModeIntent(),
            phrases: [
                "Start drive mode in \(.applicationName)",
                "Plan a low exposure drive in \(.applicationName)"
            ],
            shortTitle: "Drive Mode",
            systemImageName: "car.fill"
        )
    }
}
