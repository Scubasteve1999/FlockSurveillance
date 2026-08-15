import CoreLocation
import XCTest
@testable import FlockSurveillance

final class OliveBranchEntranceAutoPolicyTests: XCTestCase {
    private let oliveBranch = GeoHelpers.oliveBranchCoordinate
    private let madison = CLLocationCoordinate2D(latitude: 43.07, longitude: -89.40)
    private let milwaukee = CLLocationCoordinate2D(latitude: 43.04, longitude: -87.91)
    private let memphis = GeoHelpers.memphisCoordinate
    private let atlanta = CLLocationCoordinate2D(latitude: 33.749, longitude: -84.388)

    func testCoverageContainsHomeMarketNotSensorAtlasMetros() {
        XCTAssertTrue(OliveBranchEntranceCoverage.contains(oliveBranch))
        XCTAssertFalse(OliveBranchEntranceCoverage.contains(madison))
        XCTAssertFalse(OliveBranchEntranceCoverage.contains(milwaukee))
        XCTAssertFalse(OliveBranchEntranceCoverage.contains(memphis))
        XCTAssertFalse(OliveBranchEntranceCoverage.contains(atlanta))
        XCTAssertFalse(SensorAtlasCoverage.contains(oliveBranch))
    }

    func testAutoEnableNearOliveBranch() {
        XCTAssertTrue(
            OliveBranchEntranceAutoPolicy.shouldAutoEnable(
                layerAlreadyOn: false,
                suppressed: false,
                coordinate: oliveBranch
            )
        )
    }

    func testNoAutoEnableWhenLayerOnOrSuppressed() {
        XCTAssertFalse(
            OliveBranchEntranceAutoPolicy.shouldAutoEnable(
                layerAlreadyOn: true,
                suppressed: false,
                coordinate: oliveBranch
            )
        )
        XCTAssertFalse(
            OliveBranchEntranceAutoPolicy.shouldAutoEnable(
                layerAlreadyOn: false,
                suppressed: true,
                coordinate: oliveBranch
            )
        )
    }

    func testNoAutoEnableOutsideOliveBranch() {
        XCTAssertFalse(
            OliveBranchEntranceAutoPolicy.shouldAutoEnable(
                layerAlreadyOn: false,
                suppressed: false,
                coordinate: madison
            )
        )
        XCTAssertFalse(
            OliveBranchEntranceAutoPolicy.shouldAutoEnable(
                layerAlreadyOn: false,
                suppressed: false,
                coordinate: memphis
            )
        )
        XCTAssertFalse(
            OliveBranchEntranceAutoPolicy.shouldAutoEnable(
                layerAlreadyOn: false,
                suppressed: false,
                coordinate: nil
            )
        )
    }

    func testManualOffSuppressesAndManualOnClears() {
        XCTAssertTrue(OliveBranchEntranceAutoPolicy.suppressedAfterManualOff(current: false))
        XCTAssertFalse(OliveBranchEntranceAutoPolicy.suppressedAfterManualOn(current: true))
    }

    func testLocationKeyChangesWithLongitude() {
        let a = CLLocationCoordinate2D(latitude: 34.9618, longitude: -89.8295)
        let b = CLLocationCoordinate2D(latitude: 34.9618, longitude: -89.8100)
        XCTAssertNotEqual(
            OliveBranchEntranceAutoPolicy.locationKey(a),
            OliveBranchEntranceAutoPolicy.locationKey(b)
        )
    }
}
