import CoreLocation
import XCTest
@testable import FlockSurveillance

final class RouteExposureTests: XCTestCase {
    func testCameraOnPathIsDetected() {
        let points = [
            CLLocationCoordinate2D(latitude: 33.7500, longitude: -84.3900),
            CLLocationCoordinate2D(latitude: 33.7600, longitude: -84.3900)
        ]
        // Midpoint roughly on the segment
        let onPath = CLLocationCoordinate2D(latitude: 33.7550, longitude: -84.3900)
        let distance = RouteExposureService.distanceAlongPolyline(
            to: onPath,
            points: points,
            corridorMeters: 75
        )
        XCTAssertNotNil(distance)
        XCTAssertGreaterThan(distance ?? 0, 0)
    }

    func testCameraFarFromPathIsIgnored() {
        let points = [
            CLLocationCoordinate2D(latitude: 33.7500, longitude: -84.3900),
            CLLocationCoordinate2D(latitude: 33.7600, longitude: -84.3900)
        ]
        let far = CLLocationCoordinate2D(latitude: 33.7550, longitude: -84.4100)
        let distance = RouteExposureService.distanceAlongPolyline(
            to: far,
            points: points,
            corridorMeters: 75
        )
        XCTAssertNil(distance)
    }
}
