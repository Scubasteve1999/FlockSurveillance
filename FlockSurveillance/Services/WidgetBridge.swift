import CoreLocation
import Foundation
import WidgetKit

enum WidgetBridge {
    static let appGroupID = "group.com.flocksurveillance.shared"
    static let nearbyCountKey = "nearbyCount"
    static let nearestMetersKey = "nearestMeters"
    static let homeLatKey = "homeLatitude"
    static let homeLonKey = "homeLongitude"
    static let workLatKey = "workLatitude"
    static let workLonKey = "workLongitude"
    static let updatedAtKey = "updatedAt"
    static let radiusMeters: CLLocationDistance = 1609.34

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func writeHomeCoordinateIfNeeded(_ coordinate: CLLocationCoordinate2D) {
        guard let defaults else { return }
        if defaults.object(forKey: homeLatKey) == nil {
            defaults.set(coordinate.latitude, forKey: homeLatKey)
            defaults.set(coordinate.longitude, forKey: homeLonKey)
        }
    }

    static func setHomeCoordinate(_ coordinate: CLLocationCoordinate2D) {
        guard let defaults else { return }
        defaults.set(coordinate.latitude, forKey: homeLatKey)
        defaults.set(coordinate.longitude, forKey: homeLonKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func homeCoordinate() -> CLLocationCoordinate2D? {
        guard let defaults,
              defaults.object(forKey: homeLatKey) != nil,
              defaults.object(forKey: homeLonKey) != nil
        else { return nil }
        return CLLocationCoordinate2D(
            latitude: defaults.double(forKey: homeLatKey),
            longitude: defaults.double(forKey: homeLonKey)
        )
    }

    static func setWorkCoordinate(_ coordinate: CLLocationCoordinate2D) {
        guard let defaults else { return }
        defaults.set(coordinate.latitude, forKey: workLatKey)
        defaults.set(coordinate.longitude, forKey: workLonKey)
    }

    static func workCoordinate() -> CLLocationCoordinate2D? {
        guard let defaults,
              defaults.object(forKey: workLatKey) != nil,
              defaults.object(forKey: workLonKey) != nil
        else { return nil }
        return CLLocationCoordinate2D(
            latitude: defaults.double(forKey: workLatKey),
            longitude: defaults.double(forKey: workLonKey)
        )
    }

    static func writeNearbySnapshot(from cameras: [ALPRCamera]) {
        guard let defaults, let home = homeCoordinate() else { return }
        let origin = CLLocation(latitude: home.latitude, longitude: home.longitude)
        let nearby = cameras
            .map { ($0, $0.location.distance(from: origin)) }
            .filter { $0.1 <= radiusMeters }
            .sorted { $0.1 < $1.1 }

        defaults.set(nearby.count, forKey: nearbyCountKey)
        defaults.set(nearby.first?.1 ?? -1, forKey: nearestMetersKey)
        defaults.set(Date().timeIntervalSince1970, forKey: updatedAtKey)

        // Keep App Group points in sync so the widget refresh intent can recompute.
        let points = cameras
            .map { ($0, $0.location.distance(from: origin)) }
            .filter { $0.1 <= 5 * 1609.34 }
            .sorted { $0.1 < $1.1 }
            .prefix(1_000)
            .map { WidgetSnapshotStore.CameraPoint(latitude: $0.0.latitude, longitude: $0.0.longitude) }
        WidgetSnapshotStore.writeCameraPoints(Array(points))

        WidgetCenter.shared.reloadAllTimelines()
    }

    static func readSnapshot() -> (count: Int, nearestMeters: Double?, updatedAt: Date?) {
        guard let defaults else { return (0, nil, nil) }
        let count = defaults.integer(forKey: nearbyCountKey)
        let nearest = defaults.double(forKey: nearestMetersKey)
        let updated = defaults.object(forKey: updatedAtKey) as? TimeInterval
        return (
            count,
            nearest >= 0 ? nearest : nil,
            updated.map { Date(timeIntervalSince1970: $0) }
        )
    }
}
