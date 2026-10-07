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

    func testOverpassBoundingBoxesSnapToCoarseGridAndAreNeverCenteredOnFix() {
        var rng = SeededGenerator(seed: 0x0F1_0C4)
        let spans: [Double] = [0.01, 0.05, 0.2, 0.45, 1.0, 3.5]
        for _ in 0..<500 {
            let fix = CLLocationCoordinate2D(
                latitude: Double.random(in: -60...70, using: &rng),
                longitude: Double.random(in: -179...179, using: &rng)
            )
            for span in spans {
                let region = MKCoordinateRegion(
                    center: fix,
                    span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
                )
                for collapse in [true, false] {
                    let tiles = GeoHelpers.queryTiles(for: region, collapseContinental: collapse, maxTiles: 24)
                    XCTAssertFalse(tiles.isEmpty)
                    for tile in tiles {
                        assertGridAligned(GeoHelpers.overpassBoundingBox(for: tile), fix: fix)
                        // Already-snapped tiles must pass through the client's guard unchanged.
                        let snapped = GeoHelpers.snappedToOverpassGrid(tile)
                        XCTAssertEqual(snapped.span.latitudeDelta, tile.span.latitudeDelta, accuracy: 1e-9)
                        XCTAssertEqual(snapped.center.longitude, tile.center.longitude, accuracy: 1e-9)
                    }
                    if tiles.count == 1, span <= GeoHelpers.maxQuerySpanDegrees {
                        let box = GeoHelpers.overpassBoundingBox(for: tiles[0])
                        XCTAssertTrue((box.south...box.north).contains(fix.latitude))
                        XCTAssertTrue((box.west...box.east).contains(fix.longitude))
                    }
                }
                // Direct client calls (probe / seed) bypass queryTiles and still snap.
                let direct = GeoHelpers.overpassBoundingBox(for: region)
                assertGridAligned(direct, fix: fix)
                XCTAssertGreaterThanOrEqual(direct.north - direct.south, GeoHelpers.overpassGridDegrees - 1e-9)
            }
        }
    }

    func testTinyRegionSnapsToExactlyOneGridCell() {
        let tiny = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.1234, longitude: -89.9876),
            span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
        )
        let tiles = GeoHelpers.queryTiles(for: tiny)
        XCTAssertEqual(tiles.count, 1)
        let box = GeoHelpers.overpassBoundingBox(for: tiles[0])
        XCTAssertEqual(box.south, 35.1, accuracy: 1e-12)
        XCTAssertEqual(box.north, 35.2, accuracy: 1e-12)
        XCTAssertEqual(box.west, -90.0, accuracy: 1e-12)
        XCTAssertEqual(box.east, -89.9, accuracy: 1e-12)
    }

    private func assertGridAligned(
        _ box: (south: Double, west: Double, north: Double, east: Double),
        fix: CLLocationCoordinate2D,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for edge in [box.south, box.west, box.north, box.east] {
            XCTAssertEqual(edge * 10, (edge * 10).rounded(), accuracy: 1e-9, "edge \(edge) off 0.1° grid", file: file, line: line)
        }
        XCTAssertGreaterThan(box.north, box.south, file: file, line: line)
        XCTAssertGreaterThan(box.east, box.west, file: file, line: line)
        let centerLat = (box.south + box.north) / 2
        let centerLon = (box.west + box.east) / 2
        XCTAssertFalse(
            abs(centerLat - fix.latitude) < 1e-6 && abs(centerLon - fix.longitude) < 1e-6,
            "bbox is centered on the fix",
            file: file,
            line: line
        )
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
        XCTAssertEqual(score.density, .moderate)
        XCTAssertEqual(score.grade, "Moderate")
        XCTAssertEqual(score.cameraCount, 8)
        XCTAssertEqual(score.flockPercent, 50)
        XCTAssertEqual(score.headline, "Your block has moderate mapped pins")
        XCTAssertFalse(score.headline.lowercased().contains("watched"))
        XCTAssertTrue(score.headline.hasPrefix("Your block"))
        let area = GeoHelpers.placeScore(
            cameras: cameras,
            near: origin,
            radiusMeters: 1609.34,
            isPersonal: false
        )
        XCTAssertTrue(area.headline.hasPrefix("This area"))
        XCTAssertEqual(area.headline, "This area has moderate mapped pins")
        XCTAssertEqual(score.cameraCountLabel, "8 mapped pins")
        XCTAssertTrue(score.cameraCountLabel.contains("mapped pin"))
        XCTAssertFalse(score.cameraCountLabel.contains("camera"))
        XCTAssertTrue(score.shareText.contains("mapped pin"))
        XCTAssertFalse(score.shareText.contains("8 cameras"))
        XCTAssertTrue(score.shareText.contains("Mapped OSM pins — not a vendor feed."))
        XCTAssertTrue(score.shareText.contains("Mapped OSM pin density near you."))
        XCTAssertTrue(score.shareText.contains(MapHonestyCopy.chipLine))
        XCTAssertFalse(score.shareText.contains("coverage %"))
        XCTAssertFalse(score.shareText.contains("How watched is your life right now?"))
        XCTAssertTrue(score.shareText.contains("FLOCK SURVEILLANCE"))
        XCTAssertTrue(score.shareText.hasPrefix(AppIdentity.chromeMono))
        XCTAssertFalse(score.shareText.contains("OVERWATCH"))
        XCTAssertFalse(score.shareText.contains("MAPPED CAMERA PINS"))
        XCTAssertFalse(score.shareText.contains("flocksurveillance.com"))
        XCTAssertTrue(score.shareText.contains("scubasteve1999.github.io/mapped-camera-pins-site"))
        XCTAssertEqual(AppLinks.appStore?.absoluteString, "https://apps.apple.com/us/app/flock-surveillance-alpr-map/id6789356933")
        XCTAssertTrue(score.shareText.contains(AppLinks.appStore!.absoluteString))
    }

    func testPlaceScoreGradeIsTheSharedDensityLadder() {
        let origin = CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39)
        for count in [0, 1, 4, 5, 9, 14, 15, 29, 30] {
            let cameras = (0..<count).map { index in
                ALPRCamera(id: "g\(index)", latitude: 33.75 + Double(index) * 0.0001, longitude: -84.39, manufacturer: "Other")
            }
            let score = GeoHelpers.placeScore(cameras: cameras, near: origin, radiusMeters: 1609.34)
            XCTAssertEqual(score.density, PinDensity(count: count, scale: .nearPlace), "count \(count)")
            XCTAssertEqual(score.grade, score.density.label)
            XCTAssertFalse(score.headline.lowercased().contains("watch"))
        }
    }

    func testPlaceScoreLightModerateHeavyHeadlinesUseMappedPins() {
        let origin = CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39)
        func cameras(_ count: Int) -> [ALPRCamera] {
            (0..<count).map { index in
                ALPRCamera(
                    id: "h\(index)",
                    latitude: 33.75 + Double(index) * 0.0003,
                    longitude: -84.39,
                    manufacturer: "Flock Safety"
                )
            }
        }

        let light = GeoHelpers.placeScore(cameras: cameras(3), near: origin, radiusMeters: 1609.34)
        XCTAssertEqual(light.grade, "Light")
        XCTAssertEqual(light.headline, "Your block has light mapped pins")
        XCTAssertFalse(light.headline.lowercased().contains("watched"))

        let moderate = GeoHelpers.placeScore(cameras: cameras(8), near: origin, radiusMeters: 1609.34)
        XCTAssertEqual(moderate.grade, "Moderate")
        XCTAssertEqual(moderate.headline, "Your block has moderate mapped pins")
        XCTAssertFalse(moderate.headline.lowercased().contains("watched"))

        let heavy = GeoHelpers.placeScore(cameras: cameras(20), near: origin, radiusMeters: 1609.34)
        XCTAssertEqual(heavy.grade, "Heavy")
        XCTAssertEqual(heavy.headline, "Your block has heavy mapped pins")
        XCTAssertFalse(heavy.headline.lowercased().contains("watched"))

        XCTAssertEqual(
            GeoHelpers.placeScore(cameras: [], near: origin, radiusMeters: 1609.34).headline,
            "Your block looks clear"
        )
    }

    func testPlaceScoreSaturatedHeadlineUsesMappedPins() {
        let origin = CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39)
        let cameras = (0..<30).map { index in
            ALPRCamera(
                id: "s\(index)",
                latitude: 33.75 + Double(index) * 0.0003,
                longitude: -84.39,
                manufacturer: "Flock Safety"
            )
        }
        let score = GeoHelpers.placeScore(cameras: cameras, near: origin, radiusMeters: 1609.34)
        XCTAssertEqual(score.grade, "Saturated")
        XCTAssertEqual(score.headline, "Your block is saturated with mapped pins")
        XCTAssertFalse(score.headline.contains("cameras"))
        let area = GeoHelpers.placeScore(
            cameras: cameras,
            near: origin,
            radiusMeters: 1609.34,
            isPersonal: false
        )
        XCTAssertEqual(area.headline, "This area is saturated with mapped pins")
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
        XCTAssertEqual(rankings.first?.subtitle, "5 mapped pins")
        XCTAssertFalse(rankings.contains { $0.subtitle.contains("camera") })
        let miamiRank = rankings.first { $0.name == "Miami" }
        XCTAssertEqual(miamiRank?.subtitle, "1 mapped pin")
        XCTAssertTrue(miamiRank?.subtitle.contains("mapped pin") == true)
    }

    func testMidSouthSeedsFirstForLocalDensity() {
        let names = GeoHelpers.seedMetros.map(\.name)
        XCTAssertEqual(names.first, "Memphis")
        XCTAssertTrue(names.contains("Olive Branch"))
        XCTAssertTrue(names.contains("Southaven"))
        XCTAssertTrue(names.contains("Germantown"))
        // Mid-South should outrank distant national metros in seed order.
        let memphisIdx = names.firstIndex(of: "Memphis")!
        let laIdx = names.firstIndex(of: "Los Angeles")!
        XCTAssertLessThan(memphisIdx, laIdx)
    }

    func testMemphisCoordinateIsMidSouth() {
        XCTAssertEqual(GeoHelpers.memphisCoordinate.latitude, 35.1495, accuracy: 0.001)
        XCTAssertEqual(GeoHelpers.oliveBranchCoordinate.latitude, 34.9618, accuracy: 0.001)
    }

    func testRegionContainsCoordinate() {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
        XCTAssertTrue(GeoHelpers.region(region, contains: CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39)))
        XCTAssertFalse(GeoHelpers.region(region, contains: CLLocationCoordinate2D(latitude: 40.7, longitude: -74.0)))
    }

    func testPlaceScoreNotSettledWhenFetchOnlyScheduled() {
        let coordinate = CLLocationCoordinate2D(latitude: 25.76, longitude: -80.19)
        // Mirrors the old bug: lastRegion set at schedule time with isLoading false.
        XCTAssertFalse(
            GeoHelpers.placeScoreIsSettled(
                coordinate: coordinate,
                isLoading: false,
                lastFetchedRegion: nil
            )
        )
        XCTAssertFalse(GeoHelpers.shouldCommitPlaceScore(cameraCount: 0, settled: false))
    }

    func testPlaceScoreSettledOnlyAfterSuccessfulCoveringFetch() {
        let coordinate = CLLocationCoordinate2D(latitude: 25.76, longitude: -80.19)
        let miami = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
        let atlanta = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39),
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )

        XCTAssertFalse(
            GeoHelpers.placeScoreIsSettled(
                coordinate: coordinate,
                isLoading: true,
                lastFetchedRegion: miami
            )
        )
        XCTAssertFalse(
            GeoHelpers.placeScoreIsSettled(
                coordinate: coordinate,
                isLoading: false,
                lastFetchedRegion: atlanta
            )
        )
        XCTAssertTrue(
            GeoHelpers.placeScoreIsSettled(
                coordinate: coordinate,
                isLoading: false,
                lastFetchedRegion: miami
            )
        )
        XCTAssertTrue(GeoHelpers.shouldCommitPlaceScore(cameraCount: 0, settled: true))
        XCTAssertTrue(GeoHelpers.shouldCommitPlaceScore(cameraCount: 3, settled: false))
    }

    func testFailedFetchMustNotCommitClear() {
        // After a failed Overpass call: not loading, no successful covering region.
        let settled = GeoHelpers.placeScoreIsSettled(
            coordinate: CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39),
            isLoading: false,
            lastFetchedRegion: nil
        )
        XCTAssertFalse(settled)
        XCTAssertFalse(GeoHelpers.shouldCommitPlaceScore(cameraCount: 0, settled: settled))
    }

    func testUnionRegionIsQueriedTilesNotScheduledViewport() throws {
        let centerTile = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.8, longitude: -98.5),
            span: MKCoordinateSpan(latitudeDelta: 0.45, longitudeDelta: 0.45)
        )
        let union = try XCTUnwrap(GeoHelpers.unionRegion(of: [centerTile]))
        XCTAssertEqual(union.center.latitude, 39.8, accuracy: 0.001)
        XCTAssertEqual(union.span.latitudeDelta, 0.45, accuracy: 0.001)
        XCTAssertFalse(
            GeoHelpers.region(
                union,
                contains: CLLocationCoordinate2D(latitude: 47.6, longitude: -122.3)
            )
        )
    }
}

/// Deterministic SplitMix64 so the random-fix property test is reproducible.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
