import CoreLocation
import Foundation

@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var location: CLLocation?
    /// Compass heading in degrees (0 = north), nil until the first heading fix.
    private(set) var headingDegrees: Double?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 8
    }

    func requestPermissionIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func start() {
        requestPermissionIfNeeded()
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        }
    }

    /// Continuous GPS (with the blue background indicator) only while Drive Mode
    /// is active so Live Activity can refresh with the app backgrounded. AlertsEngine
    /// uses a separate manager and keeps `allowsBackgroundLocationUpdates` off.
    func setDriveTrackingEnabled(_ enabled: Bool) {
        guard manager.authorizationStatus == .authorizedWhenInUse
            || manager.authorizationStatus == .authorizedAlways
        else {
            manager.allowsBackgroundLocationUpdates = false
            manager.showsBackgroundLocationIndicator = false
            return
        }
        manager.allowsBackgroundLocationUpdates = enabled
        manager.showsBackgroundLocationIndicator = enabled
        manager.pausesLocationUpdatesAutomatically = !enabled
        if enabled {
            manager.startUpdatingLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Capture Sendable values only; hop to MainActor and use self.manager there.
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.startUpdatingLocation()
                if CLLocationManager.headingAvailable() {
                    self.manager.startUpdatingHeading()
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.location = latest
            // Home is set explicitly in Settings — don't silently bind commute/widget
            // to the first GPS fix (often work or travel).
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Prefer true north; fall back to magnetic when declination is unknown.
        let degrees = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        guard degrees >= 0 else { return }
        Task { @MainActor in
            self.headingDegrees = degrees
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep last known location; UI surfaces permission/empty states.
    }
}
