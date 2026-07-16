import CoreLocation
import MapKit
import XCTest
@testable import FlockSurveillance

final class CoverageConfidenceTests: XCTestCase {
    func testIdsToMarkAbsentOnlyInsideRegionAndMissingFromRemote() {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        let cached: [(id: String, coordinate: CLLocationCoordinate2D)] = [
            ("keep", CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39)),
            ("gone", CLLocationCoordinate2D(latitude: 33.751, longitude: -84.391)),
            ("outside", CLLocationCoordinate2D(latitude: 40.7, longitude: -74.0))
        ]
        let remote: Set<String> = ["keep"]
        let absent = CoverageConfidence.idsToMarkAbsent(cached: cached, remoteIDs: remote, region: region)
        XCTAssertEqual(absent, ["gone"])
    }

    func testIdsToMarkAbsentEmptyWhenRemoteCoversAll() {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        let cached: [(id: String, coordinate: CLLocationCoordinate2D)] = [
            ("a", CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39))
        ]
        let absent = CoverageConfidence.idsToMarkAbsent(
            cached: cached,
            remoteIDs: ["a"],
            region: region
        )
        XCTAssertTrue(absent.isEmpty)
    }

    func testIdsToMarkAbsentClearsSparseEmptyRemote() {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        let cached: [(id: String, coordinate: CLLocationCoordinate2D)] = [
            ("a", CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39)),
            ("b", CLLocationCoordinate2D(latitude: 33.751, longitude: -84.391))
        ]
        let absent = CoverageConfidence.idsToMarkAbsent(
            cached: cached,
            remoteIDs: [],
            region: region
        )
        XCTAssertEqual(absent, ["a", "b"])
        XCTAssertTrue(CoverageConfidence.shouldTrustAbsentDiff(remoteCount: 0, cachedInCoverage: 2))
        XCTAssertFalse(CoverageConfidence.shouldTrustAbsentDiff(remoteCount: 0, cachedInCoverage: 0))
    }

    func testIdsToMarkAbsentSkipsDenseEmptyRemote() {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
        let cached: [(id: String, coordinate: CLLocationCoordinate2D)] = (0..<4).map { index in
            (
                "d\(index)",
                CLLocationCoordinate2D(latitude: 33.75 + Double(index) * 0.001, longitude: -84.39)
            )
        }
        let absent = CoverageConfidence.idsToMarkAbsent(
            cached: cached,
            remoteIDs: [],
            region: region
        )
        XCTAssertTrue(absent.isEmpty)
        XCTAssertFalse(CoverageConfidence.shouldTrustAbsentDiff(remoteCount: 0, cachedInCoverage: 10))
    }

    func testIdsToMarkAbsentOnlyInsideQueriedTiles() {
        let tile = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        let cached: [(id: String, coordinate: CLLocationCoordinate2D)] = [
            ("inTileGone", CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39)),
            ("outsideTile", CLLocationCoordinate2D(latitude: 33.80, longitude: -84.39))
        ]
        let absent = CoverageConfidence.idsToMarkAbsent(
            cached: cached,
            remoteIDs: ["other"],
            regions: [tile]
        )
        XCTAssertEqual(absent, ["inTileGone"])
    }

    func testIdsToMarkAbsentSkipsTruncatedRemote() {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
        let cached: [(id: String, coordinate: CLLocationCoordinate2D)] = (0..<10).map { index in
            (
                "c\(index)",
                CLLocationCoordinate2D(latitude: 33.75 + Double(index) * 0.001, longitude: -84.39)
            )
        }
        let absent = CoverageConfidence.idsToMarkAbsent(
            cached: cached,
            remoteIDs: ["c0", "c1"],
            region: region
        )
        XCTAssertTrue(absent.isEmpty)
        XCTAssertFalse(
            CoverageConfidence.shouldTrustAbsentDiff(remoteCount: 2, cachedInCoverage: 10)
        )
    }

    func testFacingPercent() {
        let withDir = ALPRCamera(id: "1", latitude: 33.75, longitude: -84.39, direction: "N")
        let without = ALPRCamera(id: "2", latitude: 33.75, longitude: -84.39)
        XCTAssertEqual(CoverageConfidence.facingPercent(in: [withDir, without]), 50)
        XCTAssertEqual(CoverageConfidence.facingPercent(in: []), 0)
    }

    func testInstrumentLineFetched() {
        let confidence = CoverageConfidence.make(
            visibleCameras: [
                ALPRCamera(id: "1", latitude: 33.75, longitude: -84.39, direction: "90")
            ],
            isLoading: false,
            isSeeding: false,
            isServingStale: false,
            lastError: nil,
            lastSuccessfulFetchAt: Date().addingTimeInterval(-120),
            hasViewportFetch: true
        )
        XCTAssertEqual(confidence.state, .fetched)
        XCTAssertTrue(confidence.instrumentLine.contains("Fetched"))
        XCTAssertTrue(confidence.instrumentLine.contains("100% facing"))
        XCTAssertTrue(confidence.instrumentLine.contains("2m"))
    }

    func testInstrumentLineCachedWithoutViewportFetch() {
        let confidence = CoverageConfidence.make(
            visibleCameras: [
                ALPRCamera(id: "1", latitude: 33.75, longitude: -84.39)
            ],
            isLoading: false,
            isSeeding: false,
            isServingStale: false,
            lastError: nil,
            lastSuccessfulFetchAt: Date().addingTimeInterval(-3600),
            hasViewportFetch: false
        )
        XCTAssertEqual(confidence.state, .stale)
        XCTAssertTrue(confidence.instrumentLine.hasPrefix("Cached"))
    }

    func testInstrumentLineLoadingTakesPrecedence() {
        let confidence = CoverageConfidence.make(
            visibleCameras: [],
            isLoading: true,
            isSeeding: true,
            isServingStale: false,
            lastError: nil,
            lastSuccessfulFetchAt: nil,
            hasViewportFetch: false
        )
        XCTAssertEqual(confidence.state, .loading)
        XCTAssertTrue(confidence.instrumentLine.hasPrefix("Loading"))
    }
}
