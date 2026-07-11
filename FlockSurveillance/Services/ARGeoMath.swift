import CoreLocation
import Foundation
import simd

/// Pure geo helpers for placing OSM cameras in a local AR frame.
enum ARGeoMath {
    static let maxRangeMeters: CLLocationDistance = 400
    static let maxAnnotations = 25
    static let fovRadiusMeters: CLLocationDistance = 40
    static let fovHalfAngleDegrees: Double = 35
    /// Billboard height above ground (meters).
    static let pinHeightMeters: Float = 1.6

    struct LocalOffset: Equatable {
        /// Meters east of origin.
        let east: Double
        /// Meters north of origin.
        let north: Double
        /// Horizontal distance in meters.
        var distance: Double {
            sqrt(east * east + north * north)
        }
    }

    /// East/north offset of `target` relative to `origin` (WGS84 approximation).
    static func enuOffset(
        from origin: CLLocationCoordinate2D,
        to target: CLLocationCoordinate2D
    ) -> LocalOffset {
        let originLoc = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let targetLoc = CLLocation(latitude: target.latitude, longitude: target.longitude)
        let distance = originLoc.distance(from: targetLoc)
        let bearing = GeoHelpers.bearing(from: origin, to: target) * .pi / 180
        let east = distance * sin(bearing)
        let north = distance * cos(bearing)
        return LocalOffset(east: east, north: north)
    }

    /// RealityKit / ARKit Y-up: x = east, y = up, z = **-north** (camera looks -Z).
    static func arPosition(east: Double, north: Double, up: Float = pinHeightMeters) -> SIMD3<Float> {
        SIMD3(Float(east), up, Float(-north))
    }

    static func arPosition(for offset: LocalOffset, up: Float = pinHeightMeters) -> SIMD3<Float> {
        arPosition(east: offset.east, north: offset.north, up: up)
    }

    /// Yaw (radians) so +Z faces the FOV bearing in the ENU/AR frame.
    /// Bearing 0 = north, 90 = east. AR -Z is north, so yaw = bearing.
    static func fovYawRadians(bearingDegrees: Double) -> Float {
        Float(bearingDegrees * .pi / 180)
    }

    /// Nearest cameras within range, sorted by distance, capped.
    /// Uses a cheap lat/lon bbox prefilter before ENU math.
    static func nearbyCameras(
        from cameras: [ALPRCamera],
        user: CLLocationCoordinate2D,
        maxRange: CLLocationDistance = maxRangeMeters,
        limit: Int = maxAnnotations
    ) -> [(camera: ALPRCamera, offset: LocalOffset)] {
        // ~111_320 m per degree latitude; pad longitude for mid-latitudes.
        let latPad = maxRange / 111_320 + 0.0005
        let lonPad = maxRange / (111_320 * max(cos(user.latitude * .pi / 180), 0.2)) + 0.0005
        let latMin = user.latitude - latPad
        let latMax = user.latitude + latPad
        let lonMin = user.longitude - lonPad
        let lonMax = user.longitude + lonPad

        return cameras
            .lazy
            .filter {
                $0.latitude >= latMin && $0.latitude <= latMax &&
                $0.longitude >= lonMin && $0.longitude <= lonMax
            }
            .map { camera -> (ALPRCamera, LocalOffset) in
                (camera, enuOffset(from: user, to: camera.coordinate))
            }
            .filter { $0.1.distance <= maxRange }
            .sorted { $0.1.distance < $1.1.distance }
            .prefix(limit)
            .map { (camera: $0.0, offset: $0.1) }
    }
}