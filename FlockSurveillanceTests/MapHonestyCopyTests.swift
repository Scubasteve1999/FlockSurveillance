import XCTest
@testable import FlockSurveillance

/// Locks MAP first-paint honesty, the non-affiliation filter label, and share provenance.
final class MapHonestyCopyTests: XCTestCase {
    func testChipLineNamesAffiliationProvenanceAndIncomplete() {
        XCTAssertEqual(
            MapHonestyCopy.chipLine,
            "Not affiliated with Flock Safety · OSM / DeFlock community · Incomplete map."
        )
        XCTAssertTrue(MapHonestyCopy.chipLine.contains(MapHonestyCopy.affiliation))
        XCTAssertTrue(MapHonestyCopy.chipLine.contains(MapHonestyCopy.provenance))
        XCTAssertTrue(MapHonestyCopy.chipLine.contains(MapHonestyCopy.incomplete))
        XCTAssertFalse(MapHonestyCopy.chipLine.contains("%"))
        XCTAssertFalse(MapHonestyCopy.chipLine.lowercased().contains("detected"))
        XCTAssertFalse(MapHonestyCopy.chipLine.lowercased().contains("plate read"))
        XCTAssertFalse(MapHonestyCopy.accessibilityLabel.contains("%"))
    }

    func testFlockFilterTitleIsNotVendorAffiliation() {
        XCTAssertEqual(CameraFilter.flockOnly.title, "Flock-branded pins")
        XCTAssertEqual(CameraFilter.all.title, "All ALPRs")
        XCTAssertNotEqual(CameraFilter.flockOnly.title, "Flock only")
        XCTAssertFalse(CameraFilter.flockOnly.title.lowercased().contains("flock only"))
        XCTAssertEqual(CameraFilter(rawValue: "Flock only"), .flockOnly)
    }

    func testMapChromeShowsHonestyChipUnconditionally() throws {
        let source = try readProductSource("FlockSurveillance/Features/Map/MapRadarView.swift")
        XCTAssertTrue(source.contains("DataSourcePill()"))
        XCTAssertTrue(source.contains("item.title"))
        XCTAssertFalse(source.contains("Text(item.rawValue)"))
        XCTAssertFalse(source.contains("\"Flock only\""))
        XCTAssertTrue(source.contains("OpenStreetMap pins tagged Flock-branded"))
    }

    func testSettingsFilterMenuUsesNonAffiliationTitle() throws {
        let source = try readProductSource("FlockSurveillance/Features/Settings/SettingsView.swift")
        XCTAssertTrue(source.contains("filter.title"))
        XCTAssertFalse(source.contains("Text(filter.rawValue)"))
        XCTAssertTrue(source.contains("Flock pins only"))
        XCTAssertTrue(source.contains("Skip other ALPR manufacturers"))
        XCTAssertTrue(source.contains("Not affiliated with Flock Safety"))
    }

    func testPinZonePillAndShareCardsCarryChipLine() throws {
        let pill = try readProductSource("FlockSurveillance/Theme/AppTheme.swift")
        XCTAssertTrue(pill.contains("MapHonestyCopy.chipLine"))
        XCTAssertTrue(pill.contains("map-honesty-chip"))
        XCTAssertFalse(pill.contains("\"OSM · DeFlock community\""))

        let hud = try readProductSource("FlockSurveillance/Features/Map/CameraAnnotationView.swift")
        XCTAssertTrue(hud.contains("DataSourcePill()"))

        let shareCards = try readProductSource("FlockSurveillance/Theme/ShareCardRenderer.swift")
        XCTAssertTrue(shareCards.contains("MapHonestyCopy.chipLine"))
        XCTAssertFalse(shareCards.contains("OSM · COMMUNITY MAPPED · NOT A VENDOR FEED"))

        let route = try readProductSource("FlockSurveillance/Features/Route/RouteExposureView.swift")
        XCTAssertTrue(route.contains("MapHonestyCopy.chipLine"))

        let geo = try readProductSource("FlockSurveillance/Services/GeoHelpers.swift")
        XCTAssertTrue(geo.contains("MapHonestyCopy.chipLine"))
    }

    func testLearnAndTrafficCamHonestyUnchanged() throws {
        let learn = try readProductSource("FlockSurveillance/Features/Learn/LearnView.swift")
        XCTAssertTrue(learn.contains("incomplete coverage is curiosity, not a blank map"))
        XCTAssertTrue(learn.contains("not ALPR"))
        XCTAssertTrue(learn.contains("not Flock Safety cameras"))
        XCTAssertTrue(learn.contains("It is not affiliated with Flock Safety"))

        let sensor = try readProductSource("FlockSurveillance/Features/Map/SensorDetailSheet.swift")
        XCTAssertTrue(sensor.contains("Not an ALPR.\\nNot Flock Safety."))
        XCTAssertTrue(sensor.contains("not an ALPR, not Flock Safety"))
    }

    private func readProductSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
