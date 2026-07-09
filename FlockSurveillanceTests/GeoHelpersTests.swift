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

    func testContinentalRegionIsTooLargeForFullFetch() {
        let america = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 30, longitude: -95),
            span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 60)
        )
        XCTAssertTrue(GeoHelpers.isRegionTooLargeForFullFetch(america))
        let tiles = GeoHelpers.queryTiles(for: america)
        XCTAssertEqual(tiles.count, 1)
        XCTAssertLessThanOrEqual(tiles[0].span.latitudeDelta, GeoHelpers.maxQuerySpanDegrees + 0.001)
    }

    func testMetroRegionUsesSingleTile() {
        let la = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 34.05, longitude: -118.25),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
        XCTAssertFalse(GeoHelpers.isRegionTooLargeForFullFetch(la))
        XCTAssertEqual(GeoHelpers.queryTiles(for: la).count, 1)
    }

    func testWideRegionSplitsIntoMultipleTiles() {
        let bay = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.5, longitude: -122.0),
            span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
        )
        let tiles = GeoHelpers.queryTiles(for: bay)
        XCTAssertGreaterThan(tiles.count, 1)
        XCTAssertLessThanOrEqual(tiles.count, GeoHelpers.maxTilesPerFetch)
    }
}
