import CoreLocation
import MapKit
import XCTest
@testable import FlockSurveillance

final class SensorAtlasStoreTests: XCTestCase {
    func testBundleLoadsFromMainResources() throws {
        let bundle = try SensorAtlasStore.loadBundle(from: .main, resourceName: "SensorAtlasBundle")
        XCTAssertFalse(bundle.sensors.isEmpty)
        XCTAssertTrue(bundle.attribution.lowercased().contains("not alpr"))
        XCTAssertTrue(bundle.sensors.contains { $0.city == "Madison" })
        XCTAssertTrue(bundle.sensors.contains { $0.city == "Milwaukee" })
        XCTAssertTrue(bundle.sensors.allSatisfy { $0.disclaimer.lowercased().contains("not alpr") })
    }

    @MainActor
    func testViewportFilter() {
        let store = SensorAtlasStore()
        store.applyLoadedBundle(
            SensorAtlasBundle(
                version: 1,
                updated: "test",
                attribution: "test — not ALPR",
                sensors: [
                    PublicSensor(
                        id: "in",
                        name: "Inside",
                        highway: "I-94",
                        latitude: 43.07,
                        longitude: -89.40,
                        source: "test",
                        city: "Madison",
                        imageURL: "content.dot.wi.gov/travel/cameras/cam1.jpg",
                        kind: "municipal_traffic",
                        disclaimer: "Municipal traffic camera — not ALPR, not Flock Safety"
                    ),
                    PublicSensor(
                        id: "out",
                        name: "Outside",
                        highway: "I-43",
                        latitude: 44.5,
                        longitude: -88.0,
                        source: "test",
                        city: "Green Bay",
                        imageURL: nil,
                        kind: "municipal_traffic",
                        disclaimer: "Municipal traffic camera — not ALPR, not Flock Safety"
                    ),
                ]
            )
        )
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 43.07, longitude: -89.40),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
        let visible = store.sensors(in: region)
        XCTAssertEqual(visible.map(\.id), ["in"])
        XCTAssertEqual(visible.first?.resolvedImageURL?.absoluteString, "https://content.dot.wi.gov/travel/cameras/cam1.jpg")
    }

    func testWatchedZoneCopyNeverClaimsPlateRead() {
        let body = WatchedZoneCopy.enteringBody(cameraTitle: "Main St", radiusFeet: 500)
        XCTAssertTrue(body.contains("mapped"))
        XCTAssertTrue(body.contains("not a plate-read"))
        XCTAssertFalse(body.lowercased().contains("scanned your plate"))
        XCTAssertEqual(WatchedZoneCopy.hudActiveLabel, "NEAR MAPPED PINS")
        XCTAssertTrue(WatchedZoneCopy.leftBody(passedCount: 2).contains("passed near"))
    }
}
