import CoreLocation
import XCTest
@testable import FlockSurveillance

final class SurveillanceLevelTests: XCTestCase {
    func testClearWhenEmptyAndFar() {
        let level = SurveillanceLevel.compute(
            visibleCount: 0,
            nearestMeters: 2000,
            inWatchedZone: false
        )
        XCTAssertEqual(level, .clear)
    }

    func testDensityElevatesWithoutProximity() {
        XCTAssertEqual(
            SurveillanceLevel.compute(visibleCount: 3, nearestMeters: nil, inWatchedZone: false),
            .low
        )
        XCTAssertEqual(
            SurveillanceLevel.compute(visibleCount: 10, nearestMeters: nil, inWatchedZone: false),
            .elevated
        )
        XCTAssertEqual(
            SurveillanceLevel.compute(visibleCount: 20, nearestMeters: nil, inWatchedZone: false),
            .high
        )
        XCTAssertEqual(
            SurveillanceLevel.compute(visibleCount: 40, nearestMeters: nil, inWatchedZone: false),
            .critical
        )
    }

    func testClosePinForcesCritical() {
        let level = SurveillanceLevel.compute(
            visibleCount: 1,
            nearestMeters: 40,
            inWatchedZone: false
        )
        XCTAssertEqual(level, .critical)
    }

    func testWatchedZoneNeverCalm() {
        let level = SurveillanceLevel.compute(
            visibleCount: 0,
            nearestMeters: 500,
            inWatchedZone: true
        )
        XCTAssertGreaterThanOrEqual(level, .high)
    }

    func testWatchedZonePlusCloseIsHot() {
        let level = SurveillanceLevel.compute(
            visibleCount: 5,
            nearestMeters: 60,
            inWatchedZone: true
        )
        XCTAssertEqual(level, .critical)
    }

    func testDialFillMonotonic() {
        let fills = SurveillanceLevel.allCases.map(\.dialFill)
        for i in 1..<fills.count {
            XCTAssertGreaterThan(fills[i], fills[i - 1])
        }
    }
}
