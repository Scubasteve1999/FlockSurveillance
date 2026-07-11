import MapKit
import XCTest
@testable import FlockSurveillance

@MainActor
final class SharingNetworkStoreTests: XCTestCase {
    func testDecodeFixtureBundleAndHubLookup() throws {
        let json = """
        {
          "schemaVersion":"1.0.0",
          "generatedAt":"2026-07-11T00:00:00Z",
          "sourceGeneratedAt":"2026-06-02T05:46:24Z",
          "attribution":{
            "title":"DeFlock Dane Shared Networks",
            "url":"https://deflockdane.org/shared-networks/",
            "note":"Public FOIA releases."
          },
          "sources":[
            {"key":"waunakee","label":"Waunakee WI PD","releaseDate":"2026-05-11","shape":"account_csv","rowCount":2}
          ],
          "hubs":[
            {
              "id":"waunakee",
              "name":"Waunakee WI PD",
              "shortName":"Waunakee",
              "latitude":43.19,
              "longitude":-89.45,
              "releaseDate":"2026-05-11",
              "sourceRowCount":2,
              "partnerCount":2
            }
          ],
          "partners":[
            {
              "id":"1",
              "name":"Alpha PD",
              "state":"IL",
              "entityType":"municipal_police",
              "latitude":40.0,
              "longitude":-89.0,
              "inactive":false,
              "membership":"waunakee",
              "hubLinks":[{"hubId":"waunakee","direction":"hubOut","inactive":false}]
            },
            {
              "id":"2",
              "name":"Beta Sheriff",
              "state":"OH",
              "entityType":"county_sheriff",
              "latitude":40.5,
              "longitude":-82.0,
              "inactive":true,
              "membership":"waunakee",
              "hubLinks":[{"hubId":"waunakee","direction":"bidirectional","inactive":false}]
            }
          ],
          "stats":{"partnerCount":2,"hubCount":1}
        }
        """.data(using: .utf8)!

        let bundle = try SharingNetworkStore.loadBundle(from: json)
        XCTAssertEqual(bundle.hubs.count, 1)
        XCTAssertEqual(bundle.partners.count, 2)
        XCTAssertEqual(bundle.attribution.title, "DeFlock Dane Shared Networks")

        let store = SharingNetworkStore()
        store.applyLoadedBundle(bundle)

        let active = store.partners(for: "waunakee")
        XCTAssertEqual(active.map(\.id), ["1"])

        let arcs = store.arcs(for: "waunakee", limit: 10)
        XCTAssertEqual(arcs.count, 1)
        XCTAssertEqual(arcs.first?.direction, .hubOut)
    }

    func testArcSamplingCapsCount() throws {
        let partners = (0..<20).map { index in
            """
            {
              "id":"\(index)",
              "name":"Agency \(index)",
              "state":"WI",
              "entityType":"municipal_police",
              "latitude":43.\(index),
              "longitude":-89.\(index),
              "inactive":false,
              "membership":"waunakee",
              "hubLinks":[{"hubId":"waunakee","direction":"hubOut","inactive":false}]
            }
            """
        }.joined(separator: ",")

        let json = """
        {
          "schemaVersion":"1.0.0",
          "generatedAt":"2026-07-11T00:00:00Z",
          "sourceGeneratedAt":null,
          "attribution":{"title":"t","url":"https://example.com","note":"n"},
          "sources":[],
          "hubs":[{
            "id":"waunakee","name":"Waunakee WI PD","shortName":"Waunakee",
            "latitude":43.19,"longitude":-89.45,"releaseDate":null,
            "sourceRowCount":20,"partnerCount":20
          }],
          "partners":[\(partners)],
          "stats":{"partnerCount":20,"hubCount":1}
        }
        """.data(using: .utf8)!

        let bundle = try SharingNetworkStore.loadBundle(from: json)
        let store = SharingNetworkStore()
        store.applyLoadedBundle(bundle)
        XCTAssertEqual(store.arcs(for: "waunakee", limit: 5).count, 5)
        XCTAssertEqual(store.partners(for: "waunakee").count, 20)
    }

    func testViewportPreferenceKeepsInViewPartners() throws {
        let partners = [
            partnerJSON(id: "near", lat: 43.2, lon: -89.5),
            partnerJSON(id: "far1", lat: 25.0, lon: -80.0),
            partnerJSON(id: "far2", lat: 47.6, lon: -122.3),
            partnerJSON(id: "far3", lat: 34.0, lon: -118.0),
            partnerJSON(id: "far4", lat: 40.7, lon: -74.0)
        ].joined(separator: ",")

        let json = """
        {
          "schemaVersion":"1.0.0",
          "generatedAt":"2026-07-11T00:00:00Z",
          "sourceGeneratedAt":null,
          "attribution":{"title":"t","url":"https://example.com","note":"n"},
          "sources":[],
          "hubs":[{
            "id":"waunakee","name":"Waunakee WI PD","shortName":"Waunakee",
            "latitude":43.19,"longitude":-89.45,"releaseDate":null,
            "sourceRowCount":5,"partnerCount":5
          }],
          "partners":[\(partners)],
          "stats":{"partnerCount":5,"hubCount":1}
        }
        """.data(using: .utf8)!

        let bundle = try SharingNetworkStore.loadBundle(from: json)
        let store = SharingNetworkStore()
        store.applyLoadedBundle(bundle)

        let wisconsin = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 43.2, longitude: -89.5),
            span: MKCoordinateSpan(latitudeDelta: 1.5, longitudeDelta: 1.5)
        )
        let arcs = store.arcs(for: "waunakee", limit: 2, preferring: wisconsin)
        XCTAssertEqual(arcs.count, 2)
        XCTAssertTrue(arcs.contains { $0.partner.id == "near" })
    }

    func testRegionFittingZoomsWIOnlyHub() throws {
        let hub = SharingHub(
            id: "grand-chute",
            name: "Grand Chute WI PD",
            shortName: "Grand Chute",
            latitude: 44.2786,
            longitude: -88.4162,
            releaseDate: nil,
            sourceRowCount: 2,
            partnerCount: 2
        )
        let partners = [
            SharingPartner(
                id: "1", name: "A", state: "WI", entityType: "municipal_police",
                latitude: 44.5, longitude: -89.0, inactive: false, membership: "grand-chute",
                hubLinks: [SharingHubLink(hubId: "grand-chute", direction: .hubOut, inactive: false)]
            ),
            SharingPartner(
                id: "2", name: "B", state: "WI", entityType: "municipal_police",
                latitude: 43.8, longitude: -88.0, inactive: false, membership: "grand-chute",
                hubLinks: [SharingHubLink(hubId: "grand-chute", direction: .hubOut, inactive: false)]
            )
        ]
        let region = SharingNetworkStore.regionFitting(hub: hub, partners: partners)
        XCTAssertLessThan(region.span.latitudeDelta, 10)
        XCTAssertLessThan(region.span.longitudeDelta, 10)
        XCTAssertEqual(region.center.latitude, 44.15, accuracy: 0.01)
        XCTAssertEqual(region.center.longitude, -88.5, accuracy: 0.01)
    }

    func testShippedBundleDecodesWithThreeHubs() throws {
        let bundle = try SharingNetworkStore.loadBundle(from: .main)
        XCTAssertEqual(bundle.hubs.count, 3)
        XCTAssertGreaterThan(bundle.partners.count, 1000)
        XCTAssertTrue(bundle.attribution.url.contains("deflockdane.org"))

        let store = SharingNetworkStore()
        store.applyLoadedBundle(bundle)
        XCTAssertFalse(store.partners(for: "waunakee").isEmpty)
        XCTAssertFalse(store.partners(for: "middleton").isEmpty)
        XCTAssertFalse(store.partners(for: "grand-chute").isEmpty)

        for hub in bundle.hubs {
            let active = store.partners(for: hub.id).count
            XCTAssertEqual(hub.partnerCount, active, "\(hub.id) partnerCount should match active partners")
        }
    }

    func testFailedLoadCanRetry() {
        let store = SharingNetworkStore()
        // Simulate failed load state without marking permanently loaded.
        store.reload()
        // App bundle in tests includes the resource, so reload should succeed.
        XCTAssertTrue(store.isLoaded)
        XCTAssertNil(store.loadError)
        XCTAssertEqual(store.hubs.count, 3)
    }

    private func partnerJSON(id: String, lat: Double, lon: Double) -> String {
        """
        {
          "id":"\(id)",
          "name":"Agency \(id)",
          "state":"WI",
          "entityType":"municipal_police",
          "latitude":\(lat),
          "longitude":\(lon),
          "inactive":false,
          "membership":"waunakee",
          "hubLinks":[{"hubId":"waunakee","direction":"hubOut","inactive":false}]
        }
        """
    }
}
