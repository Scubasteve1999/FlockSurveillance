import XCTest
@testable import FlockSurveillance

final class TipJarStoreTests: XCTestCase {
    func testProductIDsAreTheThreeConsumablesInOrder() {
        XCTAssertEqual(
            TipProductID.allCases.map(\.rawValue),
            [
                "com.flocksurveillance.app.tip.small",
                "com.flocksurveillance.app.tip.medium",
                "com.flocksurveillance.app.tip.large"
            ]
        )
    }

    func testFallbackNamesAreStable() {
        XCTAssertEqual(TipProductID.small.fallbackName, "Small tip")
        XCTAssertEqual(TipProductID.medium.fallbackName, "Medium tip")
        XCTAssertEqual(TipProductID.large.fallbackName, "Large tip")
    }

    func testCopySaysTipsUnlockNothingAndNeverClaimsAPaidTier() {
        let joined = TipJarCopy.userFacingStrings.joined(separator: "\n").lowercased()
        XCTAssertTrue(joined.contains("unlocks nothing"))
        XCTAssertTrue(joined.contains("stays free"))
        XCTAssertFalse(joined.contains("donate"))
        XCTAssertFalse(joined.contains("subscription"))
        XCTAssertFalse(joined.contains("plate was read"))
        XCTAssertFalse(joined.contains("pro tier"))
        XCTAssertFalse(joined.contains("unlocks drive"))
        XCTAssertFalse(joined.contains("unlocks map"))
    }

    func testKnownProductLookup() {
        XCTAssertEqual(TipProductID(rawValue: "com.flocksurveillance.app.tip.small"), .small)
        XCTAssertNil(TipProductID(rawValue: "com.flocksurveillance.app.tip.pro"))
    }
}
