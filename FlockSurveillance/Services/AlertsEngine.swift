import CoreLocation
import Foundation
import UserNotifications

extension Notification.Name {
    /// Posted with a "url" userInfo entry when a notification tap or App Intent
    /// wants the app to navigate somewhere.
    static let flockDeepLink = Notification.Name("flockDeepLink")
}

/// Routes notification taps into the app's deep-link handling.
@MainActor
final class NotificationTapHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationTapHandler()

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let raw = response.notification.request.content.userInfo["deepLink"] as? String,
              let url = URL(string: raw)
        else { return }
        await MainActor.run {
            NotificationCenter.default.post(name: .flockDeepLink, object: nil, userInfo: ["url": url])
        }
    }
}

/// Lightweight camera point persisted to disk so the alerts engine can reseed
/// geofences on background wake-ups without touching SwiftData.
struct AlertCandidate: Codable, Sendable {
    let id: String
    let latitude: Double
    let longitude: Double
    let isFlock: Bool
    let title: String
}

enum AlertCandidateStore {
    /// Serial queue keeps writes ordered (rapid loadCached calls must not let an
    /// older snapshot win) and reads consistent with in-flight writes.
    private static let queue = DispatchQueue(label: "com.flocksurveillance.alertCandidates", qos: .utility)

    private static var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("AlertCandidates.json")
    }

    static func write(_ candidates: [AlertCandidate]) {
        queue.async {
            guard let data = try? JSONEncoder().encode(candidates) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    static func read() -> [AlertCandidate] {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL) else { return [] }
            return (try? JSONDecoder().decode([AlertCandidate].self, from: data)) ?? []
        }
    }
}

/// Background ALPR proximity alerts: monitors geofences around the nearest cameras
/// and reseeds them on significant location changes, so users get notified even
/// with the app closed.
@MainActor
@Observable
final class AlertsEngine: NSObject, CLLocationManagerDelegate {
    static let shared = AlertsEngine()

    /// iOS hard-caps region monitoring at 20 regions per app.
    static let maxRegions = 20
    static let regionRadius: CLLocationDistance = 150
    static let cooldown: TimeInterval = 30 * 60
    private static let lastAlertKey = "alerts.lastAlertAt"
    private nonisolated static let regionPrefix = "alpr."

    @ObservationIgnored private let manager = CLLocationManager()
    private(set) var authorizationStatus: CLAuthorizationStatus

    /// Set while Drive Mode is active — the HUD already covers approach warnings.
    var isSuppressed = false

    private override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
    }

    /// Call once at launch. Re-attaches the delegate so region callbacks work after
    /// the system relaunches the app in the background.
    func activateIfEnabled() {
        guard AppPreferences.alertsEnabled else { return }
        startBackgroundMonitoringIfAuthorized()
        if let location = manager.location {
            reseed(around: location.coordinate)
        }
    }

    func setEnabled(_ enabled: Bool) async {
        AppPreferences.alertsEnabled = enabled
        guard enabled else {
            stopAll()
            return
        }

        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])

        // Apple requires When-In-Use before Always. Jumping straight to Always
        // from .notDetermined can hang the permission sheet on iPad.
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            startBackgroundMonitoringIfAuthorized()
        default:
            break
        }

        if let location = manager.location {
            reseed(around: location.coordinate)
        } else if manager.authorizationStatus == .authorizedWhenInUse
            || manager.authorizationStatus == .authorizedAlways
        {
            manager.requestLocation()
        }
    }

    private func startBackgroundMonitoringIfAuthorized() {
        guard manager.authorizationStatus == .authorizedAlways else { return }
        manager.startMonitoringSignificantLocationChanges()
    }

    /// Whether alerts can actually fire (permission-wise). Used by Settings to
    /// surface a "grant Always access" hint.
    var hasAlwaysAuthorization: Bool {
        authorizationStatus == .authorizedAlways
    }

    private func stopAll() {
        manager.stopMonitoringSignificantLocationChanges()
        for region in manager.monitoredRegions where region.identifier.hasPrefix(Self.regionPrefix) {
            manager.stopMonitoring(for: region)
        }
    }

    // MARK: - Region seeding

    /// Reseeds using the engine's own last fix, or requests one if none exists —
    /// so preference changes (e.g. Flock-only) apply even before the UI's
    /// location manager has a fix.
    func reseedFromLastKnownLocation() {
        if let location = manager.location {
            reseed(around: location.coordinate)
        } else {
            manager.requestLocation()
        }
    }

    func reseed(around coordinate: CLLocationCoordinate2D) {
        guard AppPreferences.alertsEnabled else { return }
        let flockOnly = AppPreferences.alertsFlockOnly
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        let maxRegions = Self.maxRegions

        // Distance-sort thousands of candidates off the main thread — doing this
        // synchronously on MainActor freezes the UI (especially on iPad).
        Task.detached(priority: .utility) {
            let origin = CLLocation(latitude: lat, longitude: lon)
            let nearest = AlertCandidateStore.read()
                .filter { flockOnly ? $0.isFlock : true }
                .map { candidate -> (AlertCandidate, CLLocationDistance) in
                    let location = CLLocation(latitude: candidate.latitude, longitude: candidate.longitude)
                    return (candidate, location.distance(from: origin))
                }
                .sorted { $0.1 < $1.1 }
                .prefix(maxRegions)
                .map(\.0)

            await MainActor.run {
                self.applyMonitoredRegions(nearest)
            }
        }
    }

    private func applyMonitoredRegions(_ candidates: [AlertCandidate]) {
        for region in manager.monitoredRegions where region.identifier.hasPrefix(Self.regionPrefix) {
            manager.stopMonitoring(for: region)
        }

        for candidate in candidates {
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: candidate.latitude, longitude: candidate.longitude),
                radius: Self.regionRadius,
                identifier: Self.regionIdentifier(
                    cameraID: candidate.id,
                    isFlock: candidate.isFlock,
                    title: candidate.title
                )
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
        }
    }

    // MARK: - Region identifier encoding

    nonisolated static func regionIdentifier(cameraID: String, isFlock: Bool, title: String) -> String {
        regionPrefix + cameraID + "|" + (isFlock ? "1" : "0") + "|" + title
    }

    nonisolated static func parseRegionIdentifier(
        _ identifier: String
    ) -> (cameraID: String, isFlock: Bool, title: String?) {
        let raw = String(identifier.dropFirst(regionPrefix.count))
        let parts = raw.split(separator: "|", maxSplits: 2).map(String.init)
        let cameraID = parts.first ?? raw
        let isFlock = parts.count > 1 && parts[1] == "1"
        let title = parts.count > 2 && !parts[2].isEmpty ? parts[2] : nil
        return (cameraID, isFlock, title)
    }

    // MARK: - Notification delivery

    private func fireAlert(regionIdentifier: String) {
        guard AppPreferences.alertsEnabled, !isSuppressed, !isQuietHours() else { return }

        let parsed = Self.parseRegionIdentifier(regionIdentifier)
        let cameraID = parsed.cameraID
        let isFlock = parsed.isFlock
        let title = parsed.title ?? (isFlock ? "Flock ALPR" : "ALPR camera")

        guard !isInCooldown(cameraID: cameraID) else { return }
        recordAlert(cameraID: cameraID)

        let content = UNMutableNotificationContent()
        content.title = isFlock ? "Flock ALPR ahead" : "ALPR camera ahead"
        content.body = "\(title) within \(Int(Self.regionRadius)) m of you."
        content.sound = .default
        content.userInfo = ["deepLink": "flocksurveillance://map"]

        let request = UNNotificationRequest(
            identifier: "alpr-alert-\(cameraID)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func isQuietHours(now: Date = .now) -> Bool {
        guard AppPreferences.quietHoursEnabled else { return false }
        let hour = Calendar.current.component(.hour, from: now)
        return Self.quietWindowContains(
            hour: hour,
            start: AppPreferences.quietStartHour,
            end: AppPreferences.quietEndHour
        )
    }

    /// Whether `hour` falls in the [start, end) window; the window may wrap
    /// midnight (e.g. 22 -> 7). Equal start/end means no window.
    nonisolated static func quietWindowContains(hour: Int, start: Int, end: Int) -> Bool {
        if start == end { return false }
        if start < end {
            return hour >= start && hour < end
        }
        return hour >= start || hour < end
    }

    private func isInCooldown(cameraID: String, now: Date = .now) -> Bool {
        let history = UserDefaults.standard.dictionary(forKey: Self.lastAlertKey) as? [String: TimeInterval] ?? [:]
        guard let last = history[cameraID] else { return false }
        return now.timeIntervalSince1970 - last < Self.cooldown
    }

    private func recordAlert(cameraID: String, now: Date = .now) {
        var history = UserDefaults.standard.dictionary(forKey: Self.lastAlertKey) as? [String: TimeInterval] ?? [:]
        history[cameraID] = now.timeIntervalSince1970
        // Prune stale entries so the dictionary doesn't grow unbounded.
        let cutoff = now.timeIntervalSince1970 - Self.cooldown * 4
        history = history.filter { $0.value >= cutoff }
        UserDefaults.standard.set(history, forKey: Self.lastAlertKey)
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if AppPreferences.alertsEnabled {
                if status == .authorizedWhenInUse {
                    // Upgrade path: Always prompt only after When-In-Use is granted.
                    self.manager.requestAlwaysAuthorization()
                }
                if status == .authorizedAlways {
                    self.startBackgroundMonitoringIfAuthorized()
                }
                if status == .authorizedAlways || status == .authorizedWhenInUse,
                   let location = self.manager.location
                {
                    self.reseed(around: location.coordinate)
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        let coordinate = latest.coordinate
        Task { @MainActor in
            self.reseed(around: coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let identifier = region.identifier
        guard identifier.hasPrefix(Self.regionPrefix) else { return }
        Task { @MainActor in
            self.fireAlert(regionIdentifier: identifier)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Region monitoring soft-fails; the next significant change retries.
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        // Individual regions can fail (e.g. over quota); remaining regions still fire.
    }
}
