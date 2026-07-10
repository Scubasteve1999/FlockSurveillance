import CoreLocation
import XCTest
@testable import FlockSurveillance

final class PendingIntentActionsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearPending()
    }

    override func tearDown() {
        clearPending()
        super.tearDown()
    }

    func testPlaceScoreRequestedRoundTrip() {
        XCTAssertFalse(PendingIntentActions.placeScoreRequested)
        PendingIntentActions.placeScoreRequested = true
        XCTAssertTrue(PendingIntentActions.placeScoreRequested)
        PendingIntentActions.placeScoreRequested = false
        XCTAssertFalse(PendingIntentActions.placeScoreRequested)
    }

    func testMapFocusCoordinateRoundTripAndClear() {
        XCTAssertNil(PendingIntentActions.mapFocusCoordinate)
        let coordinate = CLLocationCoordinate2D(latitude: 33.749, longitude: -84.388)
        PendingIntentActions.mapFocusCoordinate = coordinate
        let stored = PendingIntentActions.mapFocusCoordinate
        XCTAssertNotNil(stored)
        XCTAssertEqual(stored!.latitude, coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(stored!.longitude, coordinate.longitude, accuracy: 0.0001)

        PendingIntentActions.mapFocusCoordinate = nil
        XCTAssertNil(PendingIntentActions.mapFocusCoordinate)
    }

    func testCommuteToHomeTrueMeansWorkToHome() {
        XCTAssertNil(PendingIntentActions.commuteToHome)
        PendingIntentActions.commuteToHome = true
        XCTAssertEqual(PendingIntentActions.commuteToHome, true)
        PendingIntentActions.commuteToHome = nil
        XCTAssertNil(PendingIntentActions.commuteToHome)
    }

    func testCommuteToHomeFalseMeansHomeToWork() {
        PendingIntentActions.commuteToHome = false
        XCTAssertEqual(PendingIntentActions.commuteToHome, false)
        PendingIntentActions.commuteToHome = nil
        XCTAssertNil(PendingIntentActions.commuteToHome)
    }

    func testPlaceScoreDeepLinkUsesCoarsePrecision() throws {
        let score = PlaceScore(
            coordinate: CLLocationCoordinate2D(latitude: 33.74912, longitude: -84.38845),
            radiusMeters: 1609.34,
            cameraCount: 4,
            flockCount: 2,
            flockPercent: 50,
            densityPerSquareMile: 1.3,
            grade: "Light"
        )
        let link = try XCTUnwrap(score.mapDeepLink)
        XCTAssertEqual(link.scheme, "flocksurveillance")
        XCTAssertEqual(link.host, "map")
        let items = URLComponents(url: link, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first(where: { $0.name == "lat" })?.value, "33.749")
        XCTAssertEqual(items.first(where: { $0.name == "lon" })?.value, "-84.388")
    }

    private func clearPending() {
        PendingIntentActions.placeScoreRequested = false
        PendingIntentActions.mapFocusCoordinate = nil
        PendingIntentActions.commuteToHome = nil
    }
}
