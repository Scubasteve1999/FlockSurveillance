import CoreLocation
import XCTest
@testable import FlockSurveillance

final class SensorAtlasAutoPolicyTests: XCTestCase {
    private let madison = CLLocationCoordinate2D(latitude: 43.07, longitude: -89.40)
    private let milwaukee = CLLocationCoordinate2D(latitude: 43.04, longitude: -87.91)
    private let atlanta = CLLocationCoordinate2D(latitude: 33.749, longitude: -84.388)

    func testAutoEnableInUnsuppressedMetro() {
        let metro = SensorAtlasAutoPolicy.shouldAutoEnable(
            layerAlreadyOn: false,
            suppressedMetroNames: [],
            coordinate: madison
        )
        XCTAssertEqual(metro?.name, "Madison")
    }

    func testNoAutoEnableWhenLayerOn() {
        let metro = SensorAtlasAutoPolicy.shouldAutoEnable(
            layerAlreadyOn: true,
            suppressedMetroNames: [],
            coordinate: madison
        )
        XCTAssertNil(metro)
    }

    func testNoAutoEnableOutsideCoverage() {
        let metro = SensorAtlasAutoPolicy.shouldAutoEnable(
            layerAlreadyOn: false,
            suppressedMetroNames: [],
            coordinate: atlanta
        )
        XCTAssertNil(metro)
    }

    func testSuppressOnlyCurrentMetro() {
        let afterMadisonOff = SensorAtlasAutoPolicy.suppressedAfterManualOff(
            current: [],
            coordinate: madison
        )
        XCTAssertEqual(afterMadisonOff, ["Madison"])

        // Milwaukee can still auto-on.
        let milwaukeeMetro = SensorAtlasAutoPolicy.shouldAutoEnable(
            layerAlreadyOn: false,
            suppressedMetroNames: afterMadisonOff,
            coordinate: milwaukee
        )
        XCTAssertEqual(milwaukeeMetro?.name, "Milwaukee")

        // Madison stays suppressed.
        XCTAssertNil(
            SensorAtlasAutoPolicy.shouldAutoEnable(
                layerAlreadyOn: false,
                suppressedMetroNames: afterMadisonOff,
                coordinate: madison
            )
        )
    }

    func testManualOnClearsAllSuppressions() {
        let cleared = SensorAtlasAutoPolicy.suppressedAfterManualOn(
            current: ["Madison", "Milwaukee"]
        )
        XCTAssertTrue(cleared.isEmpty)
    }

    func testLocationKeyChangesWithLongitude() {
        let a = CLLocationCoordinate2D(latitude: 43.07, longitude: -89.40)
        let b = CLLocationCoordinate2D(latitude: 43.07, longitude: -89.30)
        XCTAssertNotEqual(
            SensorAtlasAutoPolicy.locationKey(a),
            SensorAtlasAutoPolicy.locationKey(b)
        )
    }
}
