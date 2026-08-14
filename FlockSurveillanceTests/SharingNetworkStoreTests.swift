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
        XCTAssertEqual(store.reachPoints(for: "waunakee").count, 20)
    }

    func testMatchingPartnersSearchesNameStateAndEntityType() throws {
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
            "sourceRowCount":3,"partnerCount":2
          }],
          "partners":[
            {
              "id":"1","name":"Alpha PD","state":"IL","entityType":"municipal_police",
              "latitude":40.0,"longitude":-89.0,"inactive":false,"membership":"waunakee",
              "hubLinks":[{"hubId":"waunakee","direction":"hubOut","inactive":false}]
            },
            {
              "id":"2","name":"Beta Sheriff","state":"OH","entityType":"county_sheriff",
              "latitude":40.5,"longitude":-82.0,"inactive":false,"membership":"waunakee",
              "hubLinks":[{"hubId":"waunakee","direction":"bidirectional","inactive":false}]
            },
            {
              "id":"3","name":"Ghost PD","state":"WI","entityType":"municipal_police",
              "latitude":43.0,"longitude":-89.0,"inactive":true,"membership":"waunakee",
              "hubLinks":[{"hubId":"waunakee","direction":"hubOut","inactive":false}]
            }
          ],
          "stats":{"partnerCount":3,"hubCount":1}
        }
        """.data(using: .utf8)!

        let store = SharingNetworkStore()
        store.applyLoadedBundle(try SharingNetworkStore.loadBundle(from: json))

        XCTAssertTrue(store.matchingPartners(for: "waunakee", query: "   ").isEmpty)
        XCTAssertEqual(store.matchingPartners(for: "waunakee", query: "alpha").map(\.id), ["1"])
        XCTAssertEqual(store.matchingPartners(for: "waunakee", query: "oh").map(\.id), ["2"])
        XCTAssertEqual(
            store.matchingPartners(for: "waunakee", query: "county sheriff").map(\.id),
            ["2"]
        )
        // Inactive partners stay out of search (same as map).
        XCTAssertTrue(store.matchingPartners(for: "waunakee", query: "ghost").isEmpty)
    }

    func testMatchingPartnersRespectsLimitAndSort() throws {
        let partners = (0..<10).map { index in
            """
            {
              "id":"\(index)",
              "name":"Agency \(String(format: "%02d", 9 - index))",
              "state":"WI",
              "entityType":"municipal_police",
              "latitude":43.0,"longitude":-89.0,"inactive":false,
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
            "sourceRowCount":10,"partnerCount":10
          }],
          "partners":[\(partners)],
          "stats":{"partnerCount":10,"hubCount":1}
        }
        """.data(using: .utf8)!

        let store = SharingNetworkStore()
        store.applyLoadedBundle(try SharingNetworkStore.loadBundle(from: json))
        let matches = store.matchingPartners(for: "waunakee", query: "agency", limit: 3)
        XCTAssertEqual(matches.count, 3)
        XCTAssertEqual(matches.map(\.name), ["Agency 00", "Agency 01", "Agency 02"])
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
        let groups = SharingNetworkStore.makeStateGroups(partners: partners, hubId: hub.id)
        XCTAssertEqual(groups.map(\.state), ["WI"])
        let region = SharingNetworkStore.regionFitting(hub: hub, stateGroups: groups)
        let wisconsin = SharingStateGeography.coordinate(for: "WI")
        XCTAssertLessThan(region.span.latitudeDelta, 10)
        XCTAssertLessThan(region.span.longitudeDelta, 10)
        XCTAssertEqual(region.center.latitude, (hub.latitude + wisconsin.latitude) / 2, accuracy: 0.05)
        XCTAssertEqual(region.center.longitude, (hub.longitude + wisconsin.longitude) / 2, accuracy: 0.05)
        XCTAssertFalse(GeoHelpers.region(region, contains: CLLocationCoordinate2D(latitude: 31.05, longitude: -97.56)))
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

    /// Regression for the Sharing Network accessibility hang: the view renders one Marker
    /// per arc from `arcs(for:)` (default limit = `maxRenderedPartners`). Uncapped hubs
    /// (1,000+ partners) overwhelmed VoiceOver / UI automation. Keep the default cap.
    func testDefaultArcCapProtectsAccessibilityAtHubScale() throws {
        let bundle = try SharingNetworkStore.loadBundle(from: .main)
        let store = SharingNetworkStore()
        store.applyLoadedBundle(bundle)

        let cap = SharingNetworkStore.maxRenderedPartners
        var sawOversizedHub = false

        for hub in bundle.hubs {
            let reach = store.reachPoints(for: hub.id)
            let arcs = store.arcs(for: hub.id)
            XCTAssertEqual(
                arcs.count,
                min(reach.count, cap),
                "\(hub.id): rendered arcs must equal min(reach, maxRenderedPartners)"
            )
            XCTAssertLessThanOrEqual(
                arcs.count,
                cap,
                "\(hub.id): Marker/polyline list must stay at or under accessibility cap"
            )
            if reach.count > cap {
                sawOversizedHub = true
            }
        }

        XCTAssertTrue(
            sawOversizedHub,
            "Shipped bundle should include at least one hub above the render cap so this stays a scale regression"
        )
    }

    func testStateGroupsSumToActivePartnerCount() throws {
        let bundle = try SharingNetworkStore.loadBundle(from: .main)
        let store = SharingNetworkStore()
        store.applyLoadedBundle(bundle)

        for hub in bundle.hubs {
            let groups = store.stateGroups(for: hub.id)
            let summed = groups.reduce(0) { $0 + $1.partnerCount }
            XCTAssertEqual(summed, hub.partnerCount, "\(hub.id): state counts must sum to active partners")
            XCTAssertLessThanOrEqual(groups.count, 51, "\(hub.id): unique states must stay at or under 51")
            XCTAssertLessThanOrEqual(
                groups.count,
                SharingNetworkStore.maxRenderedPartners,
                "\(hub.id): state markers must stay under the accessibility cap"
            )
            XCTAssertFalse(groups.isEmpty, "\(hub.id) should have at least one state")
        }
    }

    func testStateGroupDirectionTotalsMatchPartners() throws {
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
            "sourceRowCount":3,"partnerCount":3
          }],
          "partners":[
            {
              "id":"1","name":"Alpha PD","state":"TX","entityType":"municipal_police",
              "latitude":31.0,"longitude":-97.0,"inactive":false,"membership":"waunakee",
              "hubLinks":[{"hubId":"waunakee","direction":"hubOut","inactive":false}]
            },
            {
              "id":"2","name":"Beta PD","state":"TX","entityType":"municipal_police",
              "latitude":31.1,"longitude":-97.1,"inactive":false,"membership":"waunakee",
              "hubLinks":[{"hubId":"waunakee","direction":"hubIn","inactive":false}]
            },
            {
              "id":"3","name":"Gamma PD","state":"TX","entityType":"municipal_police",
              "latitude":31.2,"longitude":-97.2,"inactive":false,"membership":"waunakee",
              "hubLinks":[{"hubId":"waunakee","direction":"bidirectional","inactive":false}]
            }
          ],
          "stats":{"partnerCount":3,"hubCount":1}
        }
        """.data(using: .utf8)!

        let store = SharingNetworkStore()
        store.applyLoadedBundle(try SharingNetworkStore.loadBundle(from: json))
        let groups = store.stateGroups(for: "waunakee")
        XCTAssertEqual(groups.count, 1)
        let texas = try XCTUnwrap(groups.first)
        XCTAssertEqual(texas.state, "TX")
        XCTAssertEqual(texas.name, "Texas")
        XCTAssertEqual(texas.partnerCount, 3)
        XCTAssertEqual(texas.hubOut, 1)
        XCTAssertEqual(texas.hubIn, 1)
        XCTAssertEqual(texas.bidirectional, 1)
        XCTAssertEqual(texas.partners.map(\.name), ["Alpha PD", "Beta PD", "Gamma PD"])
        let centroid = SharingStateGeography.coordinate(for: "TX")
        XCTAssertEqual(texas.latitude, centroid.latitude, accuracy: 0.0001)
        XCTAssertEqual(texas.longitude, centroid.longitude, accuracy: 0.0001)
    }

    func testCountyGroupsExcludeUngroupedAndSumWithThem() throws {
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
            "sourceRowCount":4,"partnerCount":4
          }],
          "partners":[
            {
              "id":"1","name":"Austin PD","state":"TX","entityType":"municipal_police",
              "latitude":30.27,"longitude":-97.74,"inactive":false,"membership":"waunakee",
              "hubLinks":[{"hubId":"waunakee","direction":"hubOut","inactive":false}],
              "county":"Travis","placeName":"Austin","geocode":"place"
            },
            {
              "id":"2","name":"Travis County Sheriff","state":"TX","entityType":"county_sheriff",
              "latitude":30.33,"longitude":-97.78,"inactive":false,"membership":"waunakee",
              "hubLinks":[{"hubId":"waunakee","direction":"hubIn","inactive":false}],
              "county":"Travis","placeName":null,"geocode":"county"
            },
            {
              "id":"3","name":"Dallas PD","state":"TX","entityType":"municipal_police",
              "latitude":32.78,"longitude":-96.80,"inactive":false,"membership":"waunakee",
              "hubLinks":[{"hubId":"waunakee","direction":"bidirectional","inactive":false}],
              "county":"Dallas","placeName":"Dallas","geocode":"place"
            },
            {
              "id":"4","name":"Mystery Task Force","state":"TX","entityType":"task_force",
              "latitude":31.05,"longitude":-97.56,"inactive":false,"membership":"waunakee",
              "hubLinks":[{"hubId":"waunakee","direction":"hubOut","inactive":false}],
              "county":null,"placeName":null,"geocode":"none"
            }
          ],
          "stats":{"partnerCount":4,"hubCount":1}
        }
        """.data(using: .utf8)!

        let store = SharingNetworkStore()
        store.applyLoadedBundle(try SharingNetworkStore.loadBundle(from: json))
        let counties = store.countyGroups(for: "waunakee", state: "TX")
        let ungrouped = store.ungroupedPartners(for: "waunakee", state: "TX")
        XCTAssertEqual(counties.map(\.county), ["Travis", "Dallas"])
        XCTAssertEqual(counties.first?.partnerCount, 2)
        XCTAssertEqual(counties.first?.hubOut, 1)
        XCTAssertEqual(counties.first?.hubIn, 1)
        XCTAssertEqual(ungrouped.map(\.id), ["4"])
        XCTAssertEqual(
            counties.reduce(0) { $0 + $1.partnerCount } + ungrouped.count,
            store.partners(for: "waunakee", state: "TX").count
        )
        XCTAssertFalse(counties.contains { group in group.partners.contains { $0.geocode == "none" } })
    }

    func testGeocodeNoneNeverBecomesCountyMarker() throws {
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
            "sourceRowCount":1,"partnerCount":1
          }],
          "partners":[
            {
              "id":"1","name":"Highway Patrol","state":"CA","entityType":"state_agency",
              "latitude":36.11,"longitude":-119.68,"inactive":false,"membership":"waunakee",
              "hubLinks":[{"hubId":"waunakee","direction":"hubOut","inactive":false}],
              "county":"Sacramento","placeName":null,"geocode":"none"
            }
          ],
          "stats":{"partnerCount":1,"hubCount":1}
        }
        """.data(using: .utf8)!

        let store = SharingNetworkStore()
        store.applyLoadedBundle(try SharingNetworkStore.loadBundle(from: json))
        XCTAssertTrue(store.countyGroups(for: "waunakee", state: "CA").isEmpty)
        XCTAssertEqual(store.ungroupedPartners(for: "waunakee", state: "CA").map(\.id), ["1"])
    }

    func testShippedBundleCountyGroupsStayUnderRenderCap() throws {
        let bundle = try SharingNetworkStore.loadBundle(from: .main)
        let store = SharingNetworkStore()
        store.applyLoadedBundle(bundle)
        let cap = SharingNetworkStore.maxRenderedPartners

        for hub in bundle.hubs {
            let states = store.stateGroups(for: hub.id)
            XCTAssertLessThanOrEqual(states.count, cap, "\(hub.id): state pins")
            for state in states {
                let counties = store.countyGroups(for: hub.id, state: state.state)
                let ungrouped = store.ungroupedPartners(for: hub.id, state: state.state)
                XCTAssertEqual(
                    counties.reduce(0) { $0 + $1.partnerCount } + ungrouped.count,
                    state.partnerCount,
                    "\(hub.id) \(state.state): county + ungrouped must equal state partners"
                )
                XCTAssertLessThanOrEqual(counties.count, cap, "\(hub.id) \(state.state): county pins")
                XCTAssertFalse(
                    counties.contains { $0.partners.contains { !$0.hasInferredLocation } },
                    "\(hub.id) \(state.state): county pins must not include geocode none"
                )
                if SharingNetworkStore.shouldPinAgenciesDirectly(partnerCount: state.partnerCount) {
                    let agencyPins = store.partners(for: hub.id, state: state.state).filter(\.hasInferredLocation)
                    XCTAssertLessThanOrEqual(agencyPins.count, cap, "\(hub.id) \(state.state): agency pins")
                }
                for county in counties {
                    XCTAssertLessThanOrEqual(county.partners.count, cap, "\(hub.id) \(county.county): agency list")
                }
            }
        }
    }

    func testMatchingPartnersSearchesCounty() throws {
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
            "sourceRowCount":1,"partnerCount":1
          }],
          "partners":[
            {
              "id":"1","name":"Alpha PD","state":"TX","entityType":"municipal_police",
              "latitude":30.27,"longitude":-97.74,"inactive":false,"membership":"waunakee",
              "hubLinks":[{"hubId":"waunakee","direction":"hubOut","inactive":false}],
              "county":"Travis","placeName":"Austin","geocode":"place"
            }
          ],
          "stats":{"partnerCount":1,"hubCount":1}
        }
        """.data(using: .utf8)!

        let store = SharingNetworkStore()
        store.applyLoadedBundle(try SharingNetworkStore.loadBundle(from: json))
        XCTAssertEqual(store.matchingPartners(for: "waunakee", query: "travis").map(\.id), ["1"])
        XCTAssertEqual(store.matchingPartners(for: "waunakee", query: "austin").map(\.id), ["1"])
    }

    func testDirectAgencyPinThreshold() {
        XCTAssertTrue(SharingNetworkStore.shouldPinAgenciesDirectly(partnerCount: 12))
        XCTAssertFalse(SharingNetworkStore.shouldPinAgenciesDirectly(partnerCount: 13))
    }

    func testFailedLoadCanRetry() async {
        let store = SharingNetworkStore()
        await store.reload(resourceName: "DoesNotExistSharingNetworkBundle")
        XCTAssertFalse(store.isLoaded)
        XCTAssertNotNil(store.loadError)
        XCTAssertTrue(store.hubs.isEmpty)

        await store.reload()
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
