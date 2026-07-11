import CoreLocation
import XCTest
@testable import FlockSurveillance

final class ARGeoMathTests: XCTestCase {
    func testEnuOffsetNorthIsPositiveNorth() {
        let origin = CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39)
        let north = CLLocationCoordinate2D(latitude: 33.751, longitude: -84.39)
        let offset = ARGeoMath.enuOffset(from: origin, to: north)
        XCTAssertGreaterThan(offset.north, 50)
        XCTAssertEqual(offset.east, 0, accuracy: 5)
        XCTAssertEqual(offset.distance, offset.north, accuracy: 1)
    }

    func testEnuOffsetEastIsPositiveEast() {
        let origin = CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39)
        let east = CLLocationCoordinate2D(latitude: 33.75, longitude: -84.389)
        let offset = ARGeoMath.enuOffset(from: origin, to: east)
        XCTAssertGreaterThan(offset.east, 50)
        XCTAssertEqual(offset.north, 0, accuracy: 8)
    }

    func testARPositionMapsNorthToNegativeZ() {
        let position = ARGeoMath.arPosition(east: 10, north: 20, up: 1.5)
        XCTAssertEqual(position.x, 10, accuracy: 0.01)
        XCTAssertEqual(position.y, 1.5, accuracy: 0.01)
        XCTAssertEqual(position.z, -20, accuracy: 0.01)
    }

    func testNearbyCamerasFiltersAndCaps() {
        let user = CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39)
        var cameras: [ALPRCamera] = (0..<30).map { index in
            ALPRCamera(
                id: "c\(index)",
                latitude: 33.75 + Double(index) * 0.0002,
                longitude: -84.39,
                manufacturer: "Flock Safety"
            )
        }
        cameras.append(
            ALPRCamera(id: "far", latitude: 34.0, longitude: -84.39, manufacturer: "Other")
        )
        let nearby = ARGeoMath.nearbyCameras(from: cameras, user: user, maxRange: 400, limit: 25)
        XCTAssertLessThanOrEqual(nearby.count, 25)
        XCTAssertFalse(nearby.contains(where: { $0.camera.id == "far" }))
        XCTAssertEqual(nearby.first?.camera.id, "c0")
    }
}
