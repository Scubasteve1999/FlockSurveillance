import CoreLocation
import MapKit
import XCTest
@testable import FlockSurveillance

/// Deterministic RNG so fixtures are reproducible across runs.
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@MainActor
final class MapSnapshotTests: XCTestCase {
    /// ~5,000 cameras across a Memphis-sized box, a mix of Flock / other and facing / unknown.
    private static func fixture(count: Int = 5_000, seed: UInt64 = 42) -> [ALPRCamera] {
        var rng = SplitMix64(state: seed)
        let directions: [String?] = [nil, nil, "N", "90", "SW", "180", "bogus"]
        return (0..<count).map { i in
            let flock = Int.random(in: 0..<3, using: &rng) != 0
            return ALPRCamera(
                id: "node/\(i)",
                latitude: Double.random(in: 34.90...35.40, using: &rng),
                longitude: Double.random(in: (-90.30)...(-89.70), using: &rng),
                manufacturer: flock ? "Flock Safety" : "Motorola",
                direction: directions[Int.random(in: 0..<directions.count, using: &rng)],
                tagsJSON: flock ? #"{"manufacturer":"Flock Safety"}"# : "{}"
            )
        }
    }

    /// The old `CameraRepository.nearest`: a `CLLocation` per row, then min.
    private static func legacyNearest(in cameras: [ALPRCamera], from origin: CLLocation) -> (id: String, meters: Double)? {
        var best: (id: String, meters: Double)?
        for camera in cameras {
            let meters = camera.location.distance(from: origin)
            if best == nil || meters < best!.meters { best = (camera.id, meters) }
        }
        return best
    }

    private static let regions: [MKCoordinateRegion] = [
        MKCoordinateRegion(center: .init(latitude: 35.15, longitude: -90.0), span: .init(latitudeDelta: 0.02, longitudeDelta: 0.02)),
        MKCoordinateRegion(center: .init(latitude: 35.10, longitude: -89.95), span: .init(latitudeDelta: 0.12, longitudeDelta: 0.12)),
        MKCoordinateRegion(center: .init(latitude: 35.20, longitude: -90.05), span: .init(latitudeDelta: 0.5, longitudeDelta: 0.4)),
        MKCoordinateRegion(center: .init(latitude: 36.0, longitude: -88.0), span: .init(latitudeDelta: 8, longitudeDelta: 8)),
        MKCoordinateRegion(center: .init(latitude: 10, longitude: 10), span: .init(latitudeDelta: 0.1, longitudeDelta: 0.1)),
    ]

    private static let users: [CLLocationCoordinate2D?] = [
        nil,
        .init(latitude: 35.1495, longitude: -90.0490),
        .init(latitude: 34.9001, longitude: -89.7001),
        .init(latitude: 35.9, longitude: -91.5), // outside the data, ~120 km from the nearest pin
    ]

    // MARK: Snapshot vs the old computed properties

    func testSnapshotMatchesLegacyComputedProperties() {
        let cameras = Self.fixture()
        let index = CameraSpatialIndex(points: cameras.map(\.point))

        for filter in CameraFilter.allCases {
            for region in Self.regions {
                for user in Self.users {
                    let snap = MapSnapshotBuilder.build(index: index, region: region, filter: filter, user: user)

                    // camerasInView
                    let legacyInView = GeoHelpers.cameras(in: region, from: cameras, filter: filter)
                    XCTAssertEqual(snap.inViewCount, legacyInView.count, "in-view count \(filter) \(region.span)")
                    XCTAssertEqual(snap.facingPercent, CoverageConfidence.facingPercent(in: legacyInView))

                    // clusters
                    let legacyClusters = GeoHelpers.clusters(for: filter, in: region, from: cameras)
                    XCTAssertEqual(snap.clusters.count, legacyClusters.count)
                    let byID = Dictionary(uniqueKeysWithValues: snap.clusters.map { ($0.id, $0) })
                    for legacy in legacyClusters {
                        guard let mine = byID[legacy.id] else { XCTFail("missing cluster \(legacy.id)"); continue }
                        XCTAssertEqual(mine.count, legacy.count)
                        XCTAssertEqual(mine.isFlockDominant, legacy.isFlockDominant)
                        XCTAssertEqual(mine.latitude, legacy.coordinate.latitude, accuracy: 1e-9)
                        XCTAssertEqual(mine.longitude, legacy.coordinate.longitude, accuracy: 1e-9)
                        XCTAssertEqual(Set(mine.cameraIDs), Set(legacy.cameras.map(\.id)))
                    }

                    // fovCameras (first 40 in view with a parseable direction)
                    let legacyFOV = legacyInView
                        .filter { GeoHelpers.directionDegrees(from: $0.direction) != nil }
                        .prefix(40).map(\.id)
                    XCTAssertEqual(snap.fovPoints.map(\.id), Array(legacyFOV))

                    // nearest
                    if let user {
                        let origin = CLLocation(latitude: user.latitude, longitude: user.longitude)
                        let base = filter == .flockOnly ? cameras.filter(\.isFlock) : cameras
                        let legacyNearest = Self.legacyNearest(in: base, from: origin)
                        let mine = snap.nearest
                        XCTAssertEqual(mine?.id, legacyNearest?.id, "nearest id \(filter) \(user)")
                        // Local-ellipsoid distance tracks CLLocation within 1 m near, ~0.1% far away.
                        let legacyMeters = legacyNearest?.meters ?? 0
                        XCTAssertEqual(mine?.meters ?? 0, legacyMeters, accuracy: max(1, legacyMeters * 0.002))
                    } else {
                        XCTAssertNil(snap.nearest)
                    }

                    // surveillanceLevel
                    var legacyMeters: Double?
                    if let user {
                        let origin = CLLocation(latitude: user.latitude, longitude: user.longitude)
                        let base = filter == .flockOnly ? cameras.filter(\.isFlock) : cameras
                        legacyMeters = Self.legacyNearest(in: base, from: origin)?.meters
                    }
                    for inZone in [false, true] {
                        XCTAssertEqual(
                            SurveillanceLevel.compute(visibleCount: snap.inViewCount, nearestMeters: snap.nearest?.meters, inWatchedZone: inZone),
                            SurveillanceLevel.compute(visibleCount: legacyInView.count, nearestMeters: legacyMeters, inWatchedZone: inZone)
                        )
                    }
                }
            }
        }
    }

    func testNilRegionYieldsEmptyViewport() {
        let index = CameraSpatialIndex(points: Self.fixture(count: 200).map(\.point))
        let snap = MapSnapshotBuilder.build(index: index, region: nil, filter: .all, user: nil)
        XCTAssertEqual(snap.inViewCount, 0)
        XCTAssertTrue(snap.clusters.isEmpty)
        XCTAssertNil(snap.nearest)
    }

    // MARK: Spatial index vs brute force

    func testIndexViewportAndNearestMatchBruteForce() {
        let points = Self.fixture(count: 3_000, seed: 7).map(\.point)
        let index = CameraSpatialIndex(points: points)
        var rng = SplitMix64(state: 99)

        for _ in 0..<150 {
            let region = MKCoordinateRegion(
                center: .init(
                    latitude: Double.random(in: 34.8...35.5, using: &rng),
                    longitude: Double.random(in: (-90.4)...(-89.6), using: &rng)
                ),
                span: .init(
                    latitudeDelta: Double.random(in: 0.001...0.6, using: &rng),
                    longitudeDelta: Double.random(in: 0.001...0.6, using: &rng)
                )
            )
            for filter in CameraFilter.allCases {
                let latMin = region.center.latitude - region.span.latitudeDelta / 2
                let latMax = region.center.latitude + region.span.latitudeDelta / 2
                let lonMin = region.center.longitude - region.span.longitudeDelta / 2
                let lonMax = region.center.longitude + region.span.longitudeDelta / 2
                var expectedIDs: [String] = []
                for point in points where filter == .all || point.isFlock {
                    let inLat = point.latitude >= latMin && point.latitude <= latMax
                    let inLon = point.longitude >= lonMin && point.longitude <= lonMax
                    if inLat && inLon { expectedIDs.append(point.id) }
                }
                let actualIDs: [String] = index.points(in: region, filter: filter).map { $0.id }
                XCTAssertEqual(actualIDs, expectedIDs)
            }

            let lat = Double.random(in: 33...37, using: &rng)
            let lon = Double.random(in: (-92)...(-88), using: &rng)
            for filter in CameraFilter.allCases {
                var bruteID: String?
                var bruteMeters = Double.infinity
                for point in points where filter == .all || point.isFlock {
                    let meters = GeoDistance.meters(
                        fromLatitude: lat, longitude: lon,
                        toLatitude: point.latitude, longitude: point.longitude
                    )
                    if meters < bruteMeters { bruteMeters = meters; bruteID = point.id }
                }
                let hit = index.nearest(toLatitude: lat, longitude: lon, filter: filter)
                XCTAssertEqual(hit?.point.id, bruteID)
                XCTAssertEqual(hit?.meters ?? 0, bruteMeters, accuracy: 1e-6)
            }
        }
    }

    func testEmptyIndexIsSafe() {
        let index = CameraSpatialIndex.empty
        XCTAssertNil(index.nearest(toLatitude: 1, longitude: 2))
        XCTAssertTrue(index.points(in: Self.regions[0]).isEmpty)
    }

    // MARK: Distance

    func testGeoDistanceMatchesCLLocationWithinOneMeter() {
        var rng = SplitMix64(state: 2024)
        for baseLat in [0.0, 35.0, 60.0, -33.9] {
            for _ in 0..<100 {
                let lat1 = baseLat + Double.random(in: -0.5...0.5, using: &rng)
                let lon1 = Double.random(in: (-120)...(-60), using: &rng)
                let lat2 = lat1 + Double.random(in: -0.04...0.04, using: &rng)
                let lon2 = lon1 + Double.random(in: -0.04...0.04, using: &rng)
                let expected = CLLocation(latitude: lat1, longitude: lon1)
                    .distance(from: CLLocation(latitude: lat2, longitude: lon2))
                let mine = GeoDistance.meters(fromLatitude: lat1, longitude: lon1, toLatitude: lat2, longitude: lon2)
                XCTAssertEqual(mine, expected, accuracy: 1.0, "(\(lat1),\(lon1)) -> (\(lat2),\(lon2))")
            }
        }
    }

    func testGeoDistanceStaysCloseOverLongerPairs() {
        // Memphis -> Little Rock-ish (~200 km): well inside 0.5%.
        let mine = GeoDistance.meters(fromLatitude: 35.1495, longitude: -90.0490, toLatitude: 34.7465, longitude: -92.2896)
        let expected = CLLocation(latitude: 35.1495, longitude: -90.0490)
            .distance(from: CLLocation(latitude: 34.7465, longitude: -92.2896))
        XCTAssertEqual(mine, expected, accuracy: expected * 0.005)
    }

    func testGeoDistanceIsSymmetricAndZeroForSamePoint() {
        XCTAssertEqual(GeoDistance.meters(fromLatitude: 35, longitude: -90, toLatitude: 35, longitude: -90), 0, accuracy: 1e-9)
        let a = GeoDistance.meters(fromLatitude: 35, longitude: -90, toLatitude: 35.01, longitude: -90.02)
        let b = GeoDistance.meters(fromLatitude: 35.01, longitude: -90.02, toLatitude: 35, longitude: -90)
        XCTAssertEqual(a, b, accuracy: 0.01)
    }
}
