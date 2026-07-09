import XCTest
@testable import FlockSurveillance

final class OverpassParserTests: XCTestCase {
    func testParsesNodesAndWaysWithCenter() throws {
        let json = """
        {
          "elements": [
            {
              "type": "node",
              "id": 111,
              "lat": 33.75,
              "lon": -84.39,
              "tags": {
                "surveillance:type": "ALPR",
                "manufacturer": "Flock Safety",
                "operator": "City PD"
              }
            },
            {
              "type": "way",
              "id": 222,
              "center": { "lat": 33.76, "lon": -84.38 },
              "tags": {
                "surveillance:type": "ALPR",
                "brand": "Motorola"
              }
            },
            {
              "type": "relation",
              "id": 333,
              "bounds": {
                "minlat": 33.70,
                "minlon": -84.40,
                "maxlat": 33.72,
                "maxlon": -84.36
              },
              "tags": {
                "surveillance:type": "ALPR"
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let cameras = try OverpassParser.cameras(from: json)
        XCTAssertEqual(cameras.count, 3)

        let node = try XCTUnwrap(cameras.first { $0.id == "osm-node-111" })
        XCTAssertEqual(node.manufacturer, "Flock Safety")
        XCTAssertEqual(node.operatorName, "City PD")
        XCTAssertTrue(node.isFlock)

        let way = try XCTUnwrap(cameras.first { $0.id == "osm-way-222" })
        XCTAssertEqual(way.latitude, 33.76, accuracy: 0.0001)
        XCTAssertEqual(way.manufacturer, "Motorola")
        XCTAssertFalse(way.isFlock)

        let relation = try XCTUnwrap(cameras.first { $0.id == "osm-relation-333" })
        XCTAssertEqual(relation.latitude, 33.71, accuracy: 0.0001)

        // DTO → model conversion stays on MainActor in production; validate fields here.
        XCTAssertEqual(node.id, "osm-node-111")
        XCTAssertEqual(way.id, "osm-way-222")
        XCTAssertEqual(relation.id, "osm-relation-333")

    }

    func testOSMURLForTypedAndLegacyIDs() {
        XCTAssertEqual(
            OverpassParser.osmURL(forCameraID: "osm-node-111")?.absoluteString,
            "https://www.openstreetmap.org/node/111"
        )
        XCTAssertEqual(
            OverpassParser.osmURL(forCameraID: "osm-999")?.absoluteString,
            "https://www.openstreetmap.org/node/999"
        )
    }
}
