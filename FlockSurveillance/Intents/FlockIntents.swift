import AppIntents
import CoreLocation
import Foundation

extension Notification.Name {
    /// Posted by CheckPlaceScoreIntent so the map computes a Place Score on arrival.
    static let flockPlaceScore = Notification.Name("flockPlaceScore")
    /// Posted when a deep link asks the map to center on lat/lon.
    static let flockMapFocus = Notification.Name("flockMapFocus")
    /// Posted by SafestDriveHomeIntent / deep link to run Home↔Work commute.
    static let flockSafestCommute = Notification.Name("flockSafestCommute")
}

/// Cross-launch handoff for intents: the flag survives until the map view is
/// actually mounted, so cold starts don't drop the request.
enum PendingIntentActions {
    private static let placeScoreKey = "pending.placeScore"
    private static let mapLatKey = "pending.mapLat"
    private static let mapLonKey = "pending.mapLon"
    private static let commuteKey = "pending.commuteToHome"
    private static let commutePendingKey = "pending.commuteRequested"

    static var placeScoreRequested: Bool {
        get { UserDefaults.standard.bool(forKey: placeScoreKey) }
        set { UserDefaults.standard.set(newValue, forKey: placeScoreKey) }
    }

    static var mapFocusCoordinate: CLLocationCoordinate2D? {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: mapLatKey) != nil,
                  defaults.object(forKey: mapLonKey) != nil
            else { return nil }
            return CLLocationCoordinate2D(
                latitude: defaults.double(forKey: mapLatKey),
                longitude: defaults.double(forKey: mapLonKey)
            )
        }
        set {
            let defaults = UserDefaults.standard
            if let newValue {
                defaults.set(newValue.latitude, forKey: mapLatKey)
                defaults.set(newValue.longitude, forKey: mapLonKey)
            } else {
                defaults.removeObject(forKey: mapLatKey)
                defaults.removeObject(forKey: mapLonKey)
            }
        }
    }

    /// `true` = Work → Home, `false` = Home → Work. Nil when nothing pending.
    static var commuteToHome: Bool? {
        get {
            guard UserDefaults.standard.bool(forKey: commutePendingKey) else { return nil }
            return UserDefaults.standard.bool(forKey: commuteKey)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(true, forKey: commutePendingKey)
                UserDefaults.standard.set(newValue, forKey: commuteKey)
            } else {
                UserDefaults.standard.set(false, forKey: commutePendingKey)
                UserDefaults.standard.removeObject(forKey: commuteKey)
            }
        }
    }
}

struct NearbyCamerasIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Nearby Cameras"
    static let description = IntentDescription("Counts community-mapped cameras within a mile of Home.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let snapshot = WidgetBridge.readSnapshot()
        guard WidgetBridge.homeCoordinate() != nil else {
            return .result(dialog: "Set a Home location in Flock Surveillance settings first.")
        }
        guard snapshot.updatedAt != nil else {
            return .result(dialog: "Open Flock Surveillance once so it can load cameras near Home.")
        }
        var dialog = snapshot.count == 1
            ? "There is 1 camera within a mile of Home."
            : "There are \(snapshot.count) cameras within a mile of Home."
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
        // Belt and braces: the notification reaches an already-mounted map; the
        // flag survives until the map appears on a cold start.
        PendingIntentActions.placeScoreRequested = true
        NotificationCenter.default.post(name: .flockPlaceScore, object: nil)
        return .result()
    }
}

struct StartDriveModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Drive Mode"
    static let description = IntentDescription("Opens route analysis so you can start a lower-camera drive.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if let url = URL(string: "flocksurveillance://route") {
            NotificationCenter.default.post(name: .flockDeepLink, object: nil, userInfo: ["url": url])
        }
        return .result()
    }
}

struct SafestDriveHomeIntent: AppIntent {
    static let title: LocalizedStringResource = "Safest Drive Home"
    static let description = IntentDescription("Opens the Route tab and scores the lowest-camera drive from Work to Home.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard WidgetBridge.homeCoordinate() != nil else {
            return .result(dialog: "Set Home in Flock Surveillance Settings first.")
        }
        guard WidgetBridge.workCoordinate() != nil else {
            return .result(dialog: "Set Work in Flock Surveillance Settings first.")
        }
        PendingIntentActions.commuteToHome = true
        if let url = URL(string: "flocksurveillance://route?commute=home") {
            NotificationCenter.default.post(name: .flockDeepLink, object: nil, userInfo: ["url": url])
        }
        NotificationCenter.default.post(name: .flockSafestCommute, object: nil)
        return .result(dialog: "Scoring the safest drive home…")
    }
}

struct FlockShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NearbyCamerasIntent(),
            phrases: [
                "How many cameras are near me in \(.applicationName)",
                "Check nearby cameras in \(.applicationName)",
                "Nearby cameras in \(.applicationName)"
            ],
            shortTitle: "Nearby cameras",
            systemImageName: "camera.metering.spot"
        )
        AppShortcut(
            intent: CheckPlaceScoreIntent(),
            phrases: [
                "Check my place score in \(.applicationName)",
                "How watched am I in \(.applicationName)"
            ],
            shortTitle: "How watched?",
            systemImageName: "gauge.with.dots.needle.67percent"
        )
        AppShortcut(
            intent: StartDriveModeIntent(),
            phrases: [
                "Start drive mode in \(.applicationName)",
                "Plan a low camera drive in \(.applicationName)"
            ],
            shortTitle: "Drive Mode",
            systemImageName: "car.fill"
        )
        AppShortcut(
            intent: SafestDriveHomeIntent(),
            phrases: [
                "Safest drive home in \(.applicationName)",
                "Drive home with fewer cameras in \(.applicationName)"
            ],
            shortTitle: "Safest drive home",
            systemImageName: "house.fill"
        )
    }
}
