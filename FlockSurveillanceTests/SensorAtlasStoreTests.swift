import CoreLocation
import MapKit
import XCTest
@testable import FlockSurveillance

final class SensorAtlasStoreTests: XCTestCase {
    func testBundleLoadsAndPassesLint() throws {
        let bundle = try SensorAtlasStore.loadBundle(from: .main, resourceName: "SensorAtlasBundle")
        XCTAssertFalse(bundle.sensors.isEmpty)
        XCTAssertTrue(bundle.attribution.lowercased().contains("not alpr"))
        XCTAssertTrue(bundle.sensors.contains { $0.city == "Madison" })
        XCTAssertTrue(bundle.sensors.contains { $0.city == "Milwaukee" })
        XCTAssertTrue(bundle.sensors.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty })
        XCTAssertTrue(bundle.sensors.allSatisfy { !$0.id.contains(" ") })
        XCTAssertTrue(bundle.sensors.allSatisfy { ($0.imageURL ?? "").lowercased().contains("pull.web") == false })
        XCTAssertTrue(bundle.sensors.allSatisfy { sensor in
            guard sensor.imageURL != nil else { return true }
            return sensor.resolvedImageURL != nil
        })
        XCTAssertTrue(bundle.sensors.allSatisfy { $0.disclaimer.lowercased().contains("not alpr") })
    }

    func testRejectsPullWebAndBlankNames() {
        let bad = SensorAtlasBundle(
            version: 1,
            updated: "test",
            attribution: "test — not ALPR",
            sensors: [
                PublicSensor(
                    id: "bad-1",
                    name: " ",
                    highway: "",
                    latitude: 43.07,
                    longitude: -89.40,
                    source: "test",
                    city: "Madison",
                    imageURL: "https://content.dot.wi.gov/travel/cameras/cam1.jpg",
                    kind: "municipal_traffic",
                    disclaimer: "Municipal traffic camera — not ALPR, not Flock Safety"
                )
            ]
        )
        XCTAssertThrowsError(try SensorAtlasStore.validate(bad))

        let pull = SensorAtlasBundle(
            version: 1,
            updated: "test",
            attribution: "test — not ALPR",
            sensors: [
                PublicSensor(
                    id: "bad-2",
                    name: "Live pull",
                    highway: "",
                    latitude: 43.07,
                    longitude: -89.40,
                    source: "test",
                    city: "Madison",
                    imageURL: "https://cameras.cityofmadison.com/pull.web?camera=1",
                    kind: "municipal_traffic",
                    disclaimer: "Municipal traffic camera — not ALPR, not Flock Safety"
                )
            ]
        )
        XCTAssertThrowsError(try SensorAtlasStore.validate(pull))
        XCTAssertNil(pull.sensors[0].resolvedImageURL)
    }

    @MainActor
    func testViewportFilterSortsByDistanceAndCaps() {
        let store = SensorAtlasStore()
        var sensors: [PublicSensor] = []
        for i in 0..<5 {
            sensors.append(
                PublicSensor(
                    id: "c-\(i)",
                    name: "Cam \(i)",
                    highway: "I-94",
                    latitude: 43.07 + Double(i) * 0.01,
                    longitude: -89.40,
                    source: "test",
                    city: "Madison",
                    imageURL: "https://content.dot.wi.gov/travel/cameras/cam\(i).jpg",
                    kind: "municipal_traffic",
                    disclaimer: "Municipal traffic camera — not ALPR, not Flock Safety"
                )
            )
        }
        // Far pin first in array order — must not win when near center.
        sensors.insert(
            PublicSensor(
                id: "far",
                name: "Far",
                highway: "I-43",
                latitude: 44.5,
                longitude: -88.0,
                source: "test",
                city: "Green Bay",
                imageURL: nil,
                kind: "municipal_traffic",
                disclaimer: "Municipal traffic camera — not ALPR, not Flock Safety"
            ),
            at: 0
        )
        store.applyLoadedBundle(
            SensorAtlasBundle(version: 1, updated: "test", attribution: "test — not ALPR", sensors: sensors)
        )
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 43.07, longitude: -89.40),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
        let visible = store.sensors(in: region, limit: 3)
        XCTAssertEqual(visible.count, 3)
        XCTAssertEqual(visible.first?.id, "c-0")
        XCTAssertFalse(visible.contains { $0.id == "far" })
        XCTAssertEqual(
            visible.first?.resolvedImageURL?.absoluteString,
            "https://content.dot.wi.gov/travel/cameras/cam0.jpg"
        )
    }

    func testWatchedZoneCopyNeverClaimsPlateRead() {
        let body = WatchedZoneCopy.enteringBody(cameraTitle: "Main St", radiusFeet: 500)
        XCTAssertTrue(body.contains("mapped"))
        XCTAssertTrue(body.contains("not a plate-read"))
        XCTAssertFalse(body.lowercased().contains("scanned your plate"))
        XCTAssertEqual(WatchedZoneCopy.hudActiveLabel, "NEAR MAPPED PINS")
        XCTAssertTrue(WatchedZoneCopy.leftBody(passedCount: 2).contains("passed near"))
        XCTAssertTrue(WatchedZoneCopy.enteringTitle.lowercased().contains("mapped alpr"))
    }

    func testAllowlistBlocksForeignHosts() {
        let sensor = PublicSensor(
            id: "x",
            name: "X",
            highway: "",
            latitude: 0,
            longitude: 0,
            source: "t",
            city: "t",
            imageURL: "https://evil.example/cam.jpg",
            kind: "municipal_traffic",
            disclaimer: "Municipal traffic camera — not ALPR, not Flock Safety"
        )
        XCTAssertNil(sensor.resolvedImageURL)
    }
}
