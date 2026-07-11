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
}
