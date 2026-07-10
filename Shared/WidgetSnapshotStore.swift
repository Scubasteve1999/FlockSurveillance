import CoreLocation
import Foundation
import WidgetKit

/// App Group helpers shared by the app and the widget extension so the
/// interactive refresh control can recompute nearby counts without opening
/// the main process.
enum WidgetSnapshotStore {
    static let appGroupID = "group.com.flocksurveillance.shared"
    static let nearbyCountKey = "nearbyCount"
    static let nearestMetersKey = "nearestMeters"
    static let homeLatKey = "homeLatitude"
    static let homeLonKey = "homeLongitude"
    static let updatedAtKey = "updatedAt"
    static let cameraPointsKey = "widgetCameraPoints"
    static let radiusMeters: CLLocationDistance = 1609.34

    struct CameraPoint: Codable, Sendable {
        let latitude: Double
        let longitude: Double
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
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

    /// Persist a compact set of points near Home so the widget can refresh offline.
    static func writeCameraPoints(_ points: [CameraPoint]) {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(points) {
            defaults.set(data, forKey: cameraPointsKey)
        }
    }

    static func clearCameraPoints() {
        defaults?.removeObject(forKey: cameraPointsKey)
    }

    static func writeNearbySnapshot(count: Int, nearestMeters: Double?) {
        guard let defaults else { return }
        defaults.set(count, forKey: nearbyCountKey)
        defaults.set(nearestMeters ?? -1, forKey: nearestMetersKey)
        defaults.set(Date().timeIntervalSince1970, forKey: updatedAtKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func clearNearbySnapshot() {
        guard let defaults else { return }
        defaults.set(0, forKey: nearbyCountKey)
        defaults.set(-1, forKey: nearestMetersKey)
        defaults.set(Date().timeIntervalSince1970, forKey: updatedAtKey)
        clearCameraPoints()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Recompute 1 mi nearby count from the last App Group camera points + Home.
    @discardableResult
    static func recomputeNearbyFromHome() -> (count: Int, nearestMeters: Double?) {
        guard let defaults, let home = homeCoordinate() else {
            return (0, nil)
        }
        let points: [CameraPoint]
        if let data = defaults.data(forKey: cameraPointsKey),
           let decoded = try? JSONDecoder().decode([CameraPoint].self, from: data)
        {
            points = decoded
        } else {
            points = []
        }

        let origin = CLLocation(latitude: home.latitude, longitude: home.longitude)
        let nearby = points
            .map { point -> CLLocationDistance in
                CLLocation(latitude: point.latitude, longitude: point.longitude)
                    .distance(from: origin)
            }
            .filter { $0 <= radiusMeters }
            .sorted()

        let nearest = nearby.first
        writeNearbySnapshot(count: nearby.count, nearestMeters: nearest)
        return (nearby.count, nearest)
    }
}
