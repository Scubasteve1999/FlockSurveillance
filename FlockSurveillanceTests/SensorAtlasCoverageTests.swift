import CoreLocation
import XCTest
@testable import FlockSurveillance

final class SensorAtlasCoverageTests: XCTestCase {
    func testMadisonAndMilwaukeeContained() {
        let madison = CLLocationCoordinate2D(latitude: 43.07, longitude: -89.40)
        let milwaukee = CLLocationCoordinate2D(latitude: 43.04, longitude: -87.91)
        XCTAssertEqual(SensorAtlasCoverage.metro(containing: madison)?.name, "Madison")
        XCTAssertEqual(SensorAtlasCoverage.metro(containing: milwaukee)?.name, "Milwaukee")
        XCTAssertTrue(SensorAtlasCoverage.contains(madison))
    }

    func testOutsideCoverage() {
        let atlanta = CLLocationCoordinate2D(latitude: 33.749, longitude: -84.388)
        XCTAssertNil(SensorAtlasCoverage.metro(containing: atlanta))
        XCTAssertFalse(SensorAtlasCoverage.contains(atlanta))
    }
}
