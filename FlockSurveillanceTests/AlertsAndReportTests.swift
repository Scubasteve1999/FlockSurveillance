import CoreLocation
import XCTest
@testable import FlockSurveillance

final class AlertsAndReportTests: XCTestCase {
    // MARK: - Quiet hours

    func testQuietWindowSameDay() {
        XCTAssertTrue(AlertsEngine.quietWindowContains(hour: 10, start: 9, end: 17))
        XCTAssertFalse(AlertsEngine.quietWindowContains(hour: 8, start: 9, end: 17))
        XCTAssertFalse(AlertsEngine.quietWindowContains(hour: 17, start: 9, end: 17))
    }

    func testQuietWindowWrapsMidnight() {
        XCTAssertTrue(AlertsEngine.quietWindowContains(hour: 23, start: 22, end: 7))
        XCTAssertTrue(AlertsEngine.quietWindowContains(hour: 0, start: 22, end: 7))
        XCTAssertTrue(AlertsEngine.quietWindowContains(hour: 6, start: 22, end: 7))
        XCTAssertFalse(AlertsEngine.quietWindowContains(hour: 7, start: 22, end: 7))
        XCTAssertFalse(AlertsEngine.quietWindowContains(hour: 12, start: 22, end: 7))
    }

    func testQuietWindowDisabledWhenStartEqualsEnd() {
        XCTAssertFalse(AlertsEngine.quietWindowContains(hour: 5, start: 5, end: 5))
    }

    // MARK: - Region identifier round trip

    func testRegionIdentifierRoundTrip() {
        let identifier = AlertsEngine.regionIdentifier(cameraID: "node/123", isFlock: true, title: "Main St ALPR")
        let parsed = AlertsEngine.parseRegionIdentifier(identifier)
        XCTAssertEqual(parsed.cameraID, "node/123")
        XCTAssertTrue(parsed.isFlock)
        XCTAssertEqual(parsed.title, "Main St ALPR")
    }

    func testRegionIdentifierTitleMayContainPipes() {
        let identifier = AlertsEngine.regionIdentifier(cameraID: "way/9", isFlock: false, title: "NB | Exit 4")
        let parsed = AlertsEngine.parseRegionIdentifier(identifier)
        XCTAssertEqual(parsed.cameraID, "way/9")
        XCTAssertFalse(parsed.isFlock)
        XCTAssertEqual(parsed.title, "NB | Exit 4")
    }

    func testRegionIdentifierEmptyTitleParsesAsNil() {
        let identifier = AlertsEngine.regionIdentifier(cameraID: "node/7", isFlock: true, title: "")
        let parsed = AlertsEngine.parseRegionIdentifier(identifier)
        XCTAssertEqual(parsed.cameraID, "node/7")
        XCTAssertNil(parsed.title)
    }

    func testRegionIdentifierTruncatesLongTitles() {
        let long = String(repeating: "A", count: 80)
        let identifier = AlertsEngine.regionIdentifier(cameraID: "node/1", isFlock: false, title: long)
        let parsed = AlertsEngine.parseRegionIdentifier(identifier)
        XCTAssertEqual(parsed.title?.count, AlertsEngine.maxTitleLength)
    }

    func testWidgetSnapshotRecomputeUsesHomeRadius() {
        // Isolate App Group keys for the test process.
        let defaults = UserDefaults(suiteName: WidgetSnapshotStore.appGroupID)
        defaults?.removeObject(forKey: WidgetSnapshotStore.cameraPointsKey)
        defaults?.set(33.75, forKey: WidgetSnapshotStore.homeLatKey)
        defaults?.set(-84.39, forKey: WidgetSnapshotStore.homeLonKey)

        WidgetSnapshotStore.writeCameraPoints([
            .init(latitude: 33.7501, longitude: -84.3901), // ~within 1 mi
            .init(latitude: 34.5, longitude: -84.39) // far
        ])
        let result = WidgetSnapshotStore.recomputeNearbyFromHome()
        XCTAssertEqual(result.count, 1)
        XCTAssertNotNil(result.nearestMeters)
        XCTAssertLessThan(result.nearestMeters ?? 9999, WidgetSnapshotStore.radiusMeters)
    }

    // MARK: - OSM report note text

    func testNewCameraNoteIncludesStructuredFields() {
        let report = OSMCameraReport(
            kind: .newCamera,
            coordinate: CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39),
            existingCameraID: nil,
            direction: "NE",
            mountType: "Pole",
            operatorGuess: "Flock Safety",
            notes: "By the intersection"
        )
        let text = report.noteText
        XCTAssertTrue(text.contains("surveillance:type=ALPR"))
        XCTAssertTrue(text.contains("Facing: NE"))
        XCTAssertTrue(text.contains("Mount: Pole"))
        XCTAssertTrue(text.contains("Flock Safety"))
        XCTAssertTrue(text.contains("By the intersection"))
    }

    func testRemovedReportMentionsExistingElement() {
        let report = OSMCameraReport(
            kind: .removed,
            coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 2),
            existingCameraID: "node/9",
            direction: nil,
            mountType: nil,
            operatorGuess: nil,
            notes: nil
        )
        XCTAssertTrue(report.noteText.contains("node/9"))
        XCTAssertTrue(report.noteText.contains("removed"))
    }

    func testOptionalFieldsAreOmittedWhenEmpty() {
        let report = OSMCameraReport(
            kind: .newCamera,
            coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 2),
            existingCameraID: nil,
            direction: nil,
            mountType: nil,
            operatorGuess: nil,
            notes: nil
        )
        let text = report.noteText
        XCTAssertFalse(text.contains("Facing:"))
        XCTAssertFalse(text.contains("Mount:"))
        XCTAssertFalse(text.contains("operator"))
    }

    // MARK: - OSM note JSON + landing

    func testParseNoteFeatureJSON() throws {
        let json = """
        {
          "type": "Feature",
          "id": 4242,
          "geometry": { "type": "Point", "coordinates": [-84.39, 33.75] },
          "properties": {
            "id": 4242,
            "status": "open",
            "comments": [{ "text": "hello" }]
          }
        }
        """.data(using: .utf8)!
        let note = try OSMNoteParser.parseNote(from: json)
        XCTAssertEqual(note.id, 4242)
        XCTAssertFalse(note.isClosed)
        XCTAssertEqual(note.comments, ["hello"])
    }

    func testParseClosedNoteJSON() throws {
        let json = """
        {
          "type": "Feature",
          "id": 7,
          "properties": { "status": "closed", "comments": [] }
        }
        """.data(using: .utf8)!
        let note = try OSMNoteParser.parseNote(from: json)
        XCTAssertTrue(note.isClosed)
    }

    func testLandedProximityMatchesNearbyCamera() {
        let report = CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39)
        let near = (id: "osm-node-1", latitude: 33.7502, longitude: -84.3901)
        let far = (id: "osm-node-2", latitude: 34.0, longitude: -84.39)
        let match = ReportStore.landedCameraID(for: report, among: [far, near])
        XCTAssertEqual(match, "osm-node-1")
    }

    func testLandedProximityIgnoresBaselineCameras() {
        let report = CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39)
        let existing = (id: "osm-node-1", latitude: 33.7502, longitude: -84.3901)
        let match = ReportStore.landedCameraID(
            for: report,
            among: [existing],
            baselineIDs: ["osm-node-1"]
        )
        XCTAssertNil(match)
    }

    func testLandedProximityNilWhenTooFar() {
        let report = CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39)
        let far = (id: "osm-node-2", latitude: 34.0, longitude: -84.39)
        XCTAssertNil(ReportStore.landedCameraID(for: report, among: [far]))
    }

    func testFlockIdentityFromOperatorAndBrandTags() {
        XCTAssertTrue(
            ALPRIdentity.isFlock(
                manufacturer: nil,
                operatorName: "Flock Safety",
                cameraName: nil
            )
        )
        let tags = "{\"brand\":\"Flock Safety\",\"surveillance:type\":\"ALPR\"}"
        XCTAssertTrue(
            ALPRIdentity.isFlock(
                manufacturer: nil,
                operatorName: nil,
                cameraName: nil,
                tagsJSON: tags
            )
        )
        XCTAssertFalse(
            ALPRIdentity.isFlock(
                manufacturer: "Motorola",
                operatorName: "City PD",
                cameraName: "Cam 1"
            )
        )
    }
}
