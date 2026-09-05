import XCTest

/// Locks Mid-South honesty-layer copy to verified sources. Reads the three product surfaces.
final class MidSouthHonestyCopyTests: XCTestCase {
    func testPinSheetCannotBeReadAsAScan() throws {
        let source = try readProductSource("FlockSurveillance/Features/Map/CameraDetailSheet.swift")
        XCTAssertTrue(source.contains("Volunteer-mapped OpenStreetMap pin"))
        XCTAssertTrue(source.contains("A pin is a claim, not a guarantee"))
        XCTAssertTrue(source.contains("does not mean this camera scanned your plate"))
        XCTAssertTrue(source.contains("Not affiliated with Flock Safety"))
        XCTAssertTrue(source.contains("Not legal advice"))
        XCTAssertTrue(source.contains("Private and HOA Flocks"))
        XCTAssertTrue(source.contains("camera.fetchedAt"))
        XCTAssertTrue(source.contains("Open in OpenStreetMap"))
        XCTAssertTrue(source.contains("Report wrong info or removal"))
        XCTAssertFalse(source.contains("Crowdsourced OpenStreetMap data. Locations may be incomplete or outdated."))
        XCTAssertFalse(source.contains("detected your plate"))
        XCTAssertFalse(source.contains("this camera just read"))
        XCTAssertFalse(source.contains("surveyed"))
    }

    func testLearnRetentionAndMemphisUseVerifiedFactsOnly() throws {
        let source = try readProductSource("FlockSurveillance/Features/Learn/LearnView.swift")
        XCTAssertTrue(source.contains("Tennessee Code Annotated § 55-10-302"))
        XCTAssertTrue(source.contains("90 days"))
        XCTAssertTrue(source.contains("2014"))
        XCTAssertTrue(source.contains("not private owners"))
        XCTAssertTrue(source.contains("Shelby County Sheriff"))
        XCTAssertTrue(source.contains("30 days"))
        XCTAssertTrue(source.contains("does not store plate reads"))

        XCTAssertTrue(source.contains("id: \"memphis-shelby\""))
        XCTAssertTrue(source.contains("June 24, 2025"))
        XCTAssertTrue(source.contains("state highway rights-of-way"))
        XCTAssertTrue(source.contains("name no dollar amount, camera count, or vendor"))
        XCTAssertTrue(source.contains("$318,000"))
        XCTAssertTrue(source.contains("FLOCK-FALCON INFRASTRUCTURE-FREE"))
        XCTAssertTrue(source.contains("June 9, 2025"))
        XCTAssertTrue(source.contains("June 8, 2026"))
        XCTAssertFalse(source.contains("153,750"))
        XCTAssertFalse(source.contains("153750"))
        XCTAssertFalse(source.contains("Hoodline"))
        XCTAssertFalse(source.contains("Time is a policy choice"))
    }

    func testLearnOliveBranchTimelineFollowsMinutes() throws {
        let source = try readProductSource("FlockSurveillance/Features/Learn/LearnView.swift")
        XCTAssertTrue(source.contains("id: \"olive-branch-gates\""))
        XCTAssertTrue(source.contains("August 2022"))
        XCTAssertTrue(source.contains("May 7, 2024"))
        XCTAssertTrue(source.contains("December 17, 2024"))
        XCTAssertTrue(source.contains("Flock Group SaaS"))
        XCTAssertTrue(source.contains("24-camera perimeter in 2026"))
        XCTAssertTrue(source.contains("Coreforce / Utility 2022"))
        XCTAssertTrue(source.contains("that row is stale"))
        XCTAssertTrue(source.contains("not a confirmed 2022 Utility camera"))
        XCTAssertTrue(source.contains("Horn Lake has had Flock since at least 2020"))
        XCTAssertFalse(source.contains("ten Flock"))
        XCTAssertFalse(source.contains("~10"))
    }

    func testSettingsAboutNamesThreeLayersAndNoPlateStorage() throws {
        let source = try readProductSource("FlockSurveillance/Features/Settings/SettingsView.swift")
        XCTAssertTrue(source.contains("three layers"))
        XCTAssertTrue(source.contains("Community poles"))
        XCTAssertTrue(source.contains("Agency records"))
        XCTAssertTrue(source.contains("Unknown private"))
        XCTAssertTrue(source.contains("does not store plate reads"))
        XCTAssertTrue(source.contains("does not invent a scan score"))
        XCTAssertTrue(source.contains("Dodging a mapped pin does not mean you are off the network"))
        XCTAssertTrue(source.contains("Not affiliated with Flock Safety"))
        XCTAssertFalse(source.contains("Community-mapped ALPR locations from OpenStreetMap and the DeFlock mapping community. Not affiliated with Flock Safety."))
    }

    private func readProductSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
