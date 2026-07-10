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

    func testBearingBetweenCoordinates() {
        let origin = CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39)
        let north = CLLocationCoordinate2D(latitude: 34.75, longitude: -84.39)
        let east = CLLocationCoordinate2D(latitude: 33.75, longitude: -83.39)

        XCTAssertEqual(GeoHelpers.bearing(from: origin, to: north), 0, accuracy: 0.5)
        XCTAssertEqual(GeoHelpers.bearing(from: origin, to: east), 90, accuracy: 1.5)
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

    func testLongRouteRegionDoesNotCollapseWhenDisabled() {
        let longDrive = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 34.0, longitude: -118.5),
            span: MKCoordinateSpan(latitudeDelta: 3.5, longitudeDelta: 3.5)
        )
        let collapsed = GeoHelpers.queryTiles(for: longDrive, collapseContinental: true)
        let expanded = GeoHelpers.queryTiles(for: longDrive, collapseContinental: false, maxTiles: 24)
        XCTAssertEqual(collapsed.count, 1)
        XCTAssertGreaterThan(expanded.count, 1)
        XCTAssertLessThanOrEqual(expanded.count, 24)
    }

    func testDirectionDegreesParsesCardinalsAndNumbers() {
        XCTAssertEqual(GeoHelpers.directionDegrees(from: "90"), 90)
        XCTAssertEqual(GeoHelpers.directionDegrees(from: "NE"), 45)
        XCTAssertEqual(GeoHelpers.directionDegrees(from: "s"), 180)
        XCTAssertNil(GeoHelpers.directionDegrees(from: nil))
        XCTAssertNil(GeoHelpers.directionDegrees(from: "unknown"))
    }

    func testFOVPolygonStartsAndEndsAtCamera() {
        let center = CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39)
        let polygon = GeoHelpers.fovPolygon(center: center, bearingDegrees: 90)
        XCTAssertGreaterThan(polygon.count, 3)
        XCTAssertEqual(polygon.first?.latitude ?? 0, center.latitude, accuracy: 0.00001)
        XCTAssertEqual(polygon.last?.latitude ?? 0, center.latitude, accuracy: 0.00001)
    }

    func testPlaceScoreGradesDensity() {
        let origin = CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39)
        let cameras = (0..<8).map { index in
            ALPRCamera(
                id: "c\(index)",
                latitude: 33.75 + Double(index) * 0.001,
                longitude: -84.39,
                manufacturer: index.isMultiple(of: 2) ? "Flock Safety" : "Other"
            )
        }
        let score = GeoHelpers.placeScore(cameras: cameras, near: origin, radiusMeters: 1609.34)
        XCTAssertEqual(score.grade, "Watched")
        XCTAssertEqual(score.cameraCount, 8)
        XCTAssertEqual(score.flockPercent, 50)
        XCTAssertTrue(score.headline.lowercased().contains("watched"))
        XCTAssertTrue(score.shareText.contains("cameras"))
    }

    func testCityRankingsSortsByCount() {
        let atlanta = CLLocationCoordinate2D(latitude: 33.7490, longitude: -84.3880)
        let miami = CLLocationCoordinate2D(latitude: 25.7617, longitude: -80.1918)
        var cameras: [ALPRCamera] = (0..<5).map { index in
            ALPRCamera(
                id: "atl\(index)",
                latitude: atlanta.latitude + Double(index) * 0.01,
                longitude: atlanta.longitude,
                manufacturer: "Flock Safety"
            )
        }
        cameras.append(
            ALPRCamera(
                id: "mia0",
                latitude: miami.latitude,
                longitude: miami.longitude,
                manufacturer: "Other"
            )
        )
        let rankings = GeoHelpers.cityRankings(from: cameras, limit: 5)
        XCTAssertGreaterThanOrEqual(rankings.count, 2)
        XCTAssertEqual(rankings.first?.name, "Atlanta")
        XCTAssertGreaterThan(rankings.first?.cameraCount ?? 0, rankings[1].cameraCount)
    }

    func testRegionContainsCoordinate() {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
        XCTAssertTrue(GeoHelpers.region(region, contains: CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39)))
        XCTAssertFalse(GeoHelpers.region(region, contains: CLLocationCoordinate2D(latitude: 40.7, longitude: -74.0)))
    }
}
