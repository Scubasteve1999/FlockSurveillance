import CoreLocation
import MapKit
import XCTest
@testable import FlockSurveillance

final class GeoHelpersTests: XCTestCase {
    func testClustersOnlyIncludeCamerasInViewport() {
        let inView = ALPRCamera(id: "a", latitude: 33.75, longitude: -84.39, manufacturer: "Flock Safety")
        let outside = ALPRCamera(id: "b", latitude: 40.71, longitude: -74.00, manufacturer: "Flock Safety")
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )

        let clusters = GeoHelpers.clusters(for: .all, in: region, from: [inView, outside])
        let ids = Set(clusters.flatMap { $0.cameras.map(\.id) })

        XCTAssertTrue(ids.contains("a"))
        XCTAssertFalse(ids.contains("b"))
        XCTAssertEqual(GeoHelpers.cameras(in: region, from: [inView, outside]).count, 1)
    }

    func testFlockOnlyFilter() {
        let flock = ALPRCamera(id: "f", latitude: 33.75, longitude: -84.39, manufacturer: "Flock Safety")
        let other = ALPRCamera(id: "o", latitude: 33.751, longitude: -84.391, manufacturer: "Motorola")
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )

        let flockOnly = GeoHelpers.cameras(in: region, from: [flock, other], filter: .flockOnly)
        XCTAssertEqual(flockOnly.map(\.id), ["f"])
    }

    func testRelativeFreshness() {
        let now = Date()
        XCTAssertEqual(GeoHelpers.relativeFreshness(from: now.addingTimeInterval(-30), now: now), "Updated just now")
        XCTAssertEqual(GeoHelpers.relativeFreshness(from: now.addingTimeInterval(-120), now: now), "Updated 2m ago")
        XCTAssertNil(GeoHelpers.relativeFreshness(from: nil, now: now))
    }
}
