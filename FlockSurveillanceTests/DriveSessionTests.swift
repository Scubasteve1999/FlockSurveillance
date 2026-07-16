import CoreLocation
import XCTest
@testable import FlockSurveillance

@MainActor
final class DriveSessionTests: XCTestCase {
    func testStartActivatesSessionAndSuppressesAlerts() {
        let session = DriveSession()
        defer { session.stop() }

        let hits = [
            makeHit(id: "a", lat: 43.1, lon: -89.4, metersFromStart: 100),
            makeHit(id: "b", lat: 43.2, lon: -89.4, metersFromStart: 500)
        ]
        session.start(hits: hits, exposureLabel: "Light")

        XCTAssertTrue(session.isActive)
        XCTAssertEqual(session.hits.map(\.id), ["a", "b"])
        XCTAssertEqual(session.exposureLabel, "Light")
        XCTAssertEqual(session.camerasRemaining, 2)
        XCTAssertEqual(session.nextHit?.id, "a")
        XCTAssertTrue(AlertsEngine.shared.isSuppressed)
    }

    func testStopClearsStateAndUnsuppressesAlerts() {
        let session = DriveSession()
        session.start(
            hits: [makeHit(id: "a", lat: 43.1, lon: -89.4, metersFromStart: 100)],
            exposureLabel: "Clear"
        )
        session.stop()

        XCTAssertFalse(session.isActive)
        XCTAssertTrue(session.hits.isEmpty)
        XCTAssertNil(session.nextHit)
        XCTAssertNil(session.metersToNext)
        XCTAssertEqual(session.camerasRemaining, 0)
        XCTAssertFalse(AlertsEngine.shared.isSuppressed)
    }

    func testUpdateMarksNearbyHitPassedAndAdvancesNext() {
        let session = DriveSession()
        defer { session.stop() }

        let near = makeHit(id: "near", lat: 43.1000, lon: -89.4000, metersFromStart: 50)
        let far = makeHit(id: "far", lat: 43.1100, lon: -89.4000, metersFromStart: 1_200)
        session.start(hits: [near, far], exposureLabel: "Light")

        // Within the 35 m pass threshold of "near".
        let atNear = CLLocation(latitude: 43.10005, longitude: -89.4000)
        session.update(userLocation: atNear, hapticsEnabled: false)

        XCTAssertTrue(session.passedIDs.contains("near"))
        XCTAssertEqual(session.nextHit?.id, "far")
        XCTAssertEqual(session.camerasRemaining, 1)
        XCTAssertNotNil(session.metersToNext)
        XCTAssertGreaterThan(session.metersToNext ?? 0, 100)
    }

    func testUpdateWithoutLocationKeepsFirstRemainingHit() {
        let session = DriveSession()
        defer { session.stop() }

        session.start(
            hits: [
                makeHit(id: "a", lat: 43.1, lon: -89.4, metersFromStart: 100),
                makeHit(id: "b", lat: 43.2, lon: -89.4, metersFromStart: 500)
            ],
            exposureLabel: "Elevated"
        )
        session.update(userLocation: nil, hapticsEnabled: false)

        XCTAssertEqual(session.nextHit?.id, "a")
        XCTAssertNil(session.metersToNext)
        XCTAssertEqual(session.camerasRemaining, 2)
    }

    private func makeHit(
        id: String,
        lat: Double,
        lon: Double,
        metersFromStart: CLLocationDistance
    ) -> DriveHit {
        DriveHit(
            id: id,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            title: "Camera \(id)",
            manufacturer: "Test",
            isFlock: false,
            metersFromStart: metersFromStart
        )
    }
}
