import CoreLocation
import XCTest
@testable import FlockSurveillance

final class RouteExposureTests: XCTestCase {
    func testCameraOnPathIsDetected() {
        let points = [
            CLLocationCoordinate2D(latitude: 33.7500, longitude: -84.3900),
            CLLocationCoordinate2D(latitude: 33.7600, longitude: -84.3900)
        ]
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

    func testRankByMetricsPrefersFewerCameras() {
        let order = RouteExposureService.rankByMetrics([
            (cameraCount: 5, distance: 1_000),
            (cameraCount: 2, distance: 2_000),
            (cameraCount: 2, distance: 1_500)
        ])
        XCTAssertEqual(order, [2, 1, 0])
    }

    func testRankByMetricsUsesDistanceAsTieBreak() {
        let order = RouteExposureService.rankByMetrics([
            (cameraCount: 3, distance: 4_000),
            (cameraCount: 3, distance: 2_500),
            (cameraCount: 3, distance: 3_000)
        ])
        XCTAssertEqual(order.first, 1)
        XCTAssertEqual(order, [1, 2, 0])
    }
}
