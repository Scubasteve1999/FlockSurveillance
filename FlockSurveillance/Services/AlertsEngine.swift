import CoreLocation
import Foundation
import UIKit
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

    static func clear() {
        write([])
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
    nonisolated static let regionRadius: CLLocationDistance = 150
    static let cooldown: TimeInterval = 30 * 60
    /// Core Location region identifiers are short; keep titles bounded.
    nonisolated static let maxTitleLength = 40
    private static let lastAlertKey = "alerts.lastAlertAt"
    private nonisolated static let regionPrefix = "alpr."
    private static let zoneExitNotificationID = "alpr-zone-exit"

    @ObservationIgnored private let manager = CLLocationManager()
    private(set) var authorizationStatus: CLAuthorizationStatus

    /// Set while Drive Mode is active — the HUD already covers approach warnings.
    var isSuppressed = false

    /// Corridor state for the "watched zone" experience: which alert geofences
    /// the user is currently inside, persisted across background relaunches.
    private(set) var watchedZone = WatchedZoneStore.read()

    var isInsideWatchedZone: Bool { watchedZone.isInside }

    /// True after an explicit user action asked for Always; cleared once Always
    /// is granted or the user lands on denied/restricted. Prevents re-prompting
    /// from every authorization callback (which races LocationManager and hangs
    /// the iPad permission sheet).
    @ObservationIgnored private var pendingAlwaysUpgrade = false

    /// Monotonic generation so overlapping detached reseeds don't apply stale sets.
    @ObservationIgnored private var reseedGeneration = 0

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
        authorizationStatus = manager.authorizationStatus
        guard AppPreferences.alertsEnabled else { return }
        startBackgroundMonitoringIfAuthorized()
        if hasAlwaysAuthorization, let location = manager.location {
            reseed(around: location.coordinate)
        }
    }

    func setEnabled(_ enabled: Bool) async {
        AppPreferences.alertsEnabled = enabled
        guard enabled else {
            pendingAlwaysUpgrade = false
            stopAll()
            return
        }

        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])

        // Apple requires When-In-Use before Always. Only request Always from this
        // explicit user action (or requestAlwaysAccess) — never from every auth callback.
        switch manager.authorizationStatus {
        case .notDetermined:
            pendingAlwaysUpgrade = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            pendingAlwaysUpgrade = true
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            pendingAlwaysUpgrade = false
            startBackgroundMonitoringIfAuthorized()
            if let location = manager.location {
                reseed(around: location.coordinate)
            } else {
                manager.requestLocation()
            }
        default:
            pendingAlwaysUpgrade = false
            break
        }
    }

    /// Explicit Always upgrade from Settings when the user already has When-In-Use.
    func requestAlwaysAccess() {
        guard AppPreferences.alertsEnabled else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse:
            pendingAlwaysUpgrade = true
            manager.requestAlwaysAuthorization()
        case .notDetermined:
            pendingAlwaysUpgrade = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways:
            startBackgroundMonitoringIfAuthorized()
            reseedFromLastKnownLocation()
        default:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }

    private func startBackgroundMonitoringIfAuthorized() {
        guard manager.authorizationStatus == .authorizedAlways else { return }
        manager.startMonitoringSignificantLocationChanges()
    }

    /// Whether alerts can actually fire in the background.
    var hasAlwaysAuthorization: Bool {
        authorizationStatus == .authorizedAlways
    }

    /// Opted in but missing Always — foreground-only / no reliable wake-ups.
    var needsAlwaysAuthorization: Bool {
        AppPreferences.alertsEnabled && !hasAlwaysAuthorization
    }

    /// Drop monitored regions after the camera cache is cleared so stale
    /// notifications cannot fire for deleted cameras.
    func clearGeofences() {
        clearMonitoredRegions()
        resetWatchedZone()
    }

    private func stopAll() {
        manager.stopMonitoringSignificantLocationChanges()
        clearMonitoredRegions()
        resetWatchedZone()
    }

    private func resetWatchedZone() {
        watchedZone.reset()
        WatchedZoneStore.write(watchedZone)
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.zoneExitNotificationID])
    }

    private func clearMonitoredRegions() {
        for region in manager.monitoredRegions where region.identifier.hasPrefix(Self.regionPrefix) {
            manager.stopMonitoring(for: region)
        }
    }

    // MARK: - Region seeding

    /// Reseeds using the engine's own last fix, or requests one if none exists —
    /// so preference changes (e.g. Flock-only) apply even before the UI's
    /// location manager has a fix.
    func reseedFromLastKnownLocation() {
        guard hasAlwaysAuthorization else {
            clearMonitoredRegions()
            return
        }
        if let location = manager.location {
            reseed(around: location.coordinate)
        } else if manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func reseed(around coordinate: CLLocationCoordinate2D) {
        guard AppPreferences.alertsEnabled else { return }
        // Background delivery requires Always. Registering regions on When-In-Use
        // makes alerts look "on" while wake-ups silently fail.
        guard hasAlwaysAuthorization else {
            clearMonitoredRegions()
            return
        }

        let flockOnly = AppPreferences.alertsFlockOnly
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        let maxRegions = Self.maxRegions
        reseedGeneration += 1
        let generation = reseedGeneration

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
                guard generation == self.reseedGeneration else { return }
                self.applyMonitoredRegions(nearest)
            }
        }
    }

    private func applyMonitoredRegions(_ candidates: [AlertCandidate]) {
        guard hasAlwaysAuthorization else {
            clearMonitoredRegions()
            return
        }

        clearMonitoredRegions()

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
            region.notifyOnExit = true
            manager.startMonitoring(for: region)
        }

        // Dropped regions never deliver their exit callback once monitoring
        // stops, so prune corridor state against the freshly seeded set.
        let event = watchedZone.reconcile(monitoredIDs: Set(candidates.map(\.id)))
        WatchedZoneStore.write(watchedZone)
        if case .exitPending(let passedCount) = event {
            scheduleZoneExitSummary(passedCount: passedCount)
        }
    }

    // MARK: - Region identifier encoding

    nonisolated static func regionIdentifier(cameraID: String, isFlock: Bool, title: String) -> String {
        let trimmed = String(title.prefix(maxTitleLength))
        return regionPrefix + cameraID + "|" + (isFlock ? "1" : "0") + "|" + trimmed
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

    /// Region radius in feet, rounded to a friendly 50 ft step for copy.
    nonisolated static var approxRadiusFeet: Int {
        Int((regionRadius * 3.28084 / 50).rounded() * 50)
    }

    private func handleRegionEnter(identifier: String) {
        let parsed = Self.parseRegionIdentifier(identifier)
        let event = watchedZone.enter(cameraID: parsed.cameraID)
        WatchedZoneStore.write(watchedZone)
        guard let event else { return }

        // Back inside before the linger window elapsed — same corridor, so the
        // pending "left the zone" summary must not fire.
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.zoneExitNotificationID])

        guard AppPreferences.alertsEnabled, !isSuppressed, !isQuietHours() else { return }
        guard !isInCooldown(cameraID: parsed.cameraID) else { return }

        let title = parsed.title ?? (parsed.isFlock ? "Flock ALPR" : "ALPR camera")
        let content = UNMutableNotificationContent()
        switch event {
        case .enteredZone:
            content.title = WatchedZoneCopy.enteringTitle
            content.body = WatchedZoneCopy.enteringBody(
                cameraTitle: title,
                radiusFeet: Self.approxRadiusFeet
            )
        case .anotherCamera(let passedCount):
            content.title = WatchedZoneCopy.stillInsideTitle
            content.body = WatchedZoneCopy.anotherCameraBody(
                cameraTitle: title,
                passedCount: passedCount
            )
        case .resumedZone, .exitPending:
            return
        }
        recordAlert(cameraID: parsed.cameraID)
        content.sound = .default
        content.userInfo = ["deepLink": "flocksurveillance://map"]

        let request = UNNotificationRequest(
            identifier: "alpr-alert-\(parsed.cameraID)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func handleRegionExit(identifier: String) {
        let parsed = Self.parseRegionIdentifier(identifier)
        let event = watchedZone.exit(cameraID: parsed.cameraID)
        WatchedZoneStore.write(watchedZone)
        guard case .exitPending(let passedCount) = event else { return }
        scheduleZoneExitSummary(passedCount: passedCount)
    }

    /// Schedules the corridor summary after the linger window; a re-entry
    /// within the window cancels it, merging brief gaps into one corridor.
    private func scheduleZoneExitSummary(passedCount: Int) {
        guard AppPreferences.alertsEnabled, !isSuppressed, !isQuietHours(), passedCount > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = WatchedZoneCopy.leftTitle
        content.body = WatchedZoneCopy.leftBody(passedCount: passedCount)
        content.sound = .default
        content.userInfo = ["deepLink": "flocksurveillance://map"]

        let request = UNNotificationRequest(
            identifier: Self.zoneExitNotificationID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: WatchedZoneTracker.lingerInterval,
                repeats: false
            )
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
            guard AppPreferences.alertsEnabled else { return }

            switch status {
            case .authorizedWhenInUse:
                // Only continue the Always upgrade if the user just opted in —
                // never re-prompt on every callback after they declined Always.
                if self.pendingAlwaysUpgrade {
                    self.pendingAlwaysUpgrade = false
                    self.manager.requestAlwaysAuthorization()
                }
            case .authorizedAlways:
                self.pendingAlwaysUpgrade = false
                self.startBackgroundMonitoringIfAuthorized()
                if let location = self.manager.location {
                    self.reseed(around: location.coordinate)
                } else {
                    self.manager.requestLocation()
                }
            case .denied, .restricted:
                self.pendingAlwaysUpgrade = false
                self.clearMonitoredRegions()
            default:
                break
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
            self.handleRegionEnter(identifier: identifier)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        let identifier = region.identifier
        guard identifier.hasPrefix(Self.regionPrefix) else { return }
        Task { @MainActor in
            self.handleRegionExit(identifier: identifier)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Region monitoring soft-fails; the next significant change retries.
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        // Individual regions can fail (e.g. over quota); remaining regions still fire.
    }
}
