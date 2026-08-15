import CoreLocation
import MapKit
import XCTest
@testable import FlockSurveillance

final class OliveBranchEntranceStoreTests: XCTestCase {
    func testShippedBundleLoadsAndLocksSummaryCounts() throws {
        let bundle = try OliveBranchEntranceStore.loadBundle(
            from: .main,
            resourceName: "OliveBranchEntranceBundle"
        )
        let summary = OliveBranchEntranceStore.makeSummary(bundle)
        XCTAssertEqual(summary.roadRowCount, 24)
        XCTAssertEqual(summary.uniqueSiteCount, 23)
        XCTAssertEqual(summary.matchCount, 8)
        XCTAssertEqual(summary.nearMissCount, 3)
        XCTAssertEqual(summary.gapCount, 12)
        XCTAssertEqual(summary.sitesWithPinWithin250, 11)
        XCTAssertEqual(summary.pinCount, 31)
        XCTAssertEqual(summary.entrancePinCount, 11)
        XCTAssertEqual(summary.leftoverPinCount, 20)

        XCTAssertTrue(bundle.attribution.lowercased().contains("reconstruction"))
        XCTAssertTrue(bundle.attribution.lowercased().contains("odbl"))
        XCTAssertTrue(bundle.attribution.lowercased().contains("not official"))
        XCTAssertTrue(bundle.attribution.lowercased().contains("utility"))
        XCTAssertFalse(bundle.sources.isEmpty)
    }

    func testW3AndW4AreOnePhysicalSite() throws {
        let bundle = try OliveBranchEntranceStore.loadBundle(
            from: .main,
            resourceName: "OliveBranchEntranceBundle"
        )
        let w3 = try XCTUnwrap(bundle.sites.first { $0.id == "W3" })
        let w4 = try XCTUnwrap(bundle.sites.first { $0.id == "W4" })
        XCTAssertEqual(w3.uniqueSiteId, "W3-W4")
        XCTAssertEqual(w4.uniqueSiteId, "W3-W4")
        XCTAssertEqual(w3.nearestOsmNode, w4.nearestOsmNode)
        XCTAssertEqual(w3.quality, .match)
        XCTAssertEqual(w4.quality, .match)

        let unique = OliveBranchEntranceStore.makeUniqueSites(from: bundle.sites)
        let pair = try XCTUnwrap(unique.first { $0.uniqueSiteId == "W3-W4" })
        XCTAssertTrue(pair.isCoincident)
        XCTAssertEqual(pair.rows.map(\.id), ["W3", "W4"])
        XCTAssertEqual(unique.filter { $0.uniqueSiteId == "W3" || $0.uniqueSiteId == "W4" }.count, 0)
    }

    func testPublishedQualityMatchesDistanceWindows() throws {
        let bundle = try OliveBranchEntranceStore.loadBundle(
            from: .main,
            resourceName: "OliveBranchEntranceBundle"
        )
        for site in bundle.sites {
            XCTAssertEqual(
                EntranceMatchQuality.classify(distanceMeters: site.distanceMeters),
                site.quality,
                "Site \(site.id) quality was recomputed instead of matching the published table."
            )
        }
        let n5 = try XCTUnwrap(bundle.sites.first { $0.id == "N5" })
        XCTAssertEqual(n5.distanceMeters, 167)
        XCTAssertEqual(n5.quality, .nearMiss)
        XCTAssertEqual(n5.nearestOsmNode, "14056099801")
    }

    func testPinClassSplitAndMotorolaIsLeftover() throws {
        let bundle = try OliveBranchEntranceStore.loadBundle(
            from: .main,
            resourceName: "OliveBranchEntranceBundle"
        )
        let entrance = bundle.pins.filter { $0.locationClass == .cityLimitEntrance }
        let leftover = bundle.pins.filter(\.isLeftover)
        XCTAssertEqual(entrance.count, 11)
        XCTAssertEqual(leftover.count, 20)

        let motorola = bundle.pins.filter { $0.vendor == .motorola }
        XCTAssertEqual(motorola.count, 1)
        XCTAssertEqual(motorola.first?.id, "13920361501")
        XCTAssertEqual(motorola.first?.locationClass, .inside)
        XCTAssertTrue(motorola.first?.isLeftover == true)
        XCTAssertFalse(entrance.contains { $0.vendor == .motorola })
    }

    func testForced24DropsS2ChurchDuplicate() throws {
        let bundle = try OliveBranchEntranceStore.loadBundle(
            from: .main,
            resourceName: "OliveBranchEntranceBundle"
        )
        let s2 = try XCTUnwrap(bundle.sites.first { $0.id == "S2" })
        XCTAssertFalse(s2.includeInForced24)
        XCTAssertEqual(bundle.sites.filter(\.includeInForced24).count, 23)
        XCTAssertFalse(bundle.sites.filter(\.includeInForced24).contains { $0.id == "S2" })
        XCTAssertTrue(bundle.sites.filter(\.includeInForced24).contains { $0.id == "S1" })
        XCTAssertTrue(bundle.sites.filter(\.includeInForced24).contains { $0.id == "W3" })
        XCTAssertTrue(bundle.sites.filter(\.includeInForced24).contains { $0.id == "W4" })

        let unique = OliveBranchEntranceStore.makeUniqueSites(from: bundle.sites)
        XCTAssertEqual(unique.filter(\.includeInForced24).count, 22)
        XCTAssertFalse(unique.filter(\.includeInForced24).contains { $0.id == "S2" })
    }

    func testValidationRejectsEmptyDuplicateAndBadQuality() {
        XCTAssertThrowsError(try OliveBranchEntranceStore.validate(fixture(sites: [], pins: [Self.validPin()])))
        XCTAssertThrowsError(try OliveBranchEntranceStore.validate(fixture(sites: [Self.validSite()], pins: [])))

        let duplicateSites = fixture(
            sites: [Self.validSite(), Self.validSite(id: "N2")],
            pins: [Self.validPin()]
        )
        XCTAssertThrowsError(try OliveBranchEntranceStore.validate(duplicateSites))

        let duplicatePins = fixture(
            sites: [Self.validSite(), Self.validSite(id: "N4", nearest: "13162178977")],
            pins: [Self.validPin(), Self.validPin()]
        )
        XCTAssertThrowsError(try OliveBranchEntranceStore.validate(duplicatePins))

        let blankID = fixture(
            sites: [Self.validSite(id: " ")],
            pins: [Self.validPin()]
        )
        XCTAssertThrowsError(try OliveBranchEntranceStore.validate(blankID))

        let badMatch = fixture(
            sites: [Self.validSite(distance: 200, quality: .match)],
            pins: [Self.validPin()]
        )
        XCTAssertThrowsError(try OliveBranchEntranceStore.validate(badMatch))

        let badNearMiss = fixture(
            sites: [Self.validSite(distance: 80, quality: .nearMiss)],
            pins: [Self.validPin()]
        )
        XCTAssertThrowsError(try OliveBranchEntranceStore.validate(badNearMiss))

        let badGap = fixture(
            sites: [Self.validSite(distance: 100, quality: .noPin)],
            pins: [Self.validPin()]
        )
        XCTAssertThrowsError(try OliveBranchEntranceStore.validate(badGap))

        let matchWithoutNode = fixture(
            sites: [Self.validSite(nearest: nil)],
            pins: [Self.validPin()]
        )
        XCTAssertThrowsError(try OliveBranchEntranceStore.validate(matchWithoutNode))

        let matchUnknownNode = fixture(
            sites: [Self.validSite(nearest: "999")],
            pins: [Self.validPin()]
        )
        XCTAssertThrowsError(try OliveBranchEntranceStore.validate(matchUnknownNode))

        let gapUnknownFarNode = fixture(
            sites: [Self.validSite(id: "N3", distance: 483, quality: .noPin, nearest: "999")],
            pins: [Self.validPin()]
        )
        XCTAssertThrowsError(try OliveBranchEntranceStore.validate(gapUnknownFarNode))
    }

    func testUniqueSiteInitRejectsEmptyRowsAndClassifiesPinOwnership() throws {
        XCTAssertNil(OliveBranchUniqueSite(uniqueSiteId: "N2", rows: []))

        let n2 = try XCTUnwrap(
            OliveBranchEntranceStore.makeUniqueSites(from: [Self.validSite()]).first
        )
        let n3 = try XCTUnwrap(
            OliveBranchEntranceStore.makeUniqueSites(from: [
                Self.validSite(id: "N3", distance: 483, quality: .noPin, nearest: "12856671911")
            ]).first
        )
        let n2Pin = Self.validPin()
        XCTAssertTrue(n2.isBestEntrance(for: n2Pin))
        XCTAssertFalse(n3.isBestEntrance(for: n2Pin))
    }

    @MainActor
    func testViewportReturnsUniqueSitesAndCaps() {
        let store = OliveBranchEntranceStore()
        var sites: [OliveBranchEntranceSite] = [
            Self.validSite(id: "N2", latitude: 34.994358, longitude: -89.883774),
            Self.validSite(id: "W3", uniqueSiteId: "W3-W4", latitude: 34.947822, longitude: -89.919013),
            Self.validSite(
                id: "W4",
                uniqueSiteId: "W3-W4",
                road: "Malone Road",
                latitude: 34.947934,
                longitude: -89.919018,
                distance: 81
            ),
        ]
        sites.append(
            Self.validSite(id: "E3", latitude: 44.0, longitude: -88.0, distance: 400, quality: .noPin, nearest: nil)
        )
        store.applyLoadedBundle(
            fixture(
                sites: sites,
                pins: [
                    Self.validPin(),
                    Self.validPin(id: "12856624768", bestEntranceId: "W3-W4", distance: 79),
                ]
            )
        )
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 34.96, longitude: -89.90),
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
        let visible = store.uniqueSites(in: region, limit: 10)
        XCTAssertEqual(visible.map(\.id).sorted(), ["N2", "W3-W4"])
        XCTAssertEqual(store.uniqueSites.count, 3)
        XCTAssertEqual(store.gapSites.count, 1)
        XCTAssertEqual(store.forced24UniqueSites.count, 3)
    }

    @MainActor
    func testStoreFiltersLeftoverAndEntrancePins() {
        let store = OliveBranchEntranceStore()
        store.applyLoadedBundle(
            fixture(
                sites: [Self.validSite()],
                pins: [
                    Self.validPin(),
                    Self.validPin(
                        id: "13920361501",
                        vendor: .motorola,
                        locationClass: .inside,
                        bestEntranceId: "N2",
                        distance: 463
                    ),
                ]
            )
        )
        XCTAssertEqual(store.entrancePins.map(\.id), ["12856671911"])
        XCTAssertEqual(store.leftoverPins.map(\.id), ["13920361501"])
        XCTAssertEqual(store.pin(id: "12856671911")?.vendor, .flock)
    }

    private func fixture(
        sites: [OliveBranchEntranceSite],
        pins: [OliveBranchEntrancePin]
    ) -> OliveBranchEntranceBundle {
        OliveBranchEntranceBundle(
            version: 1,
            updated: "test",
            attribution: "test reconstruction — ODbL — not official Utility locations",
            sources: [],
            sites: sites,
            pins: pins
        )
    }

    private static func validSite(
        id: String = "N2",
        uniqueSiteId: String? = nil,
        road: String = "Davidson Road",
        latitude: Double = 34.994358,
        longitude: Double = -89.883774,
        distance: CLLocationDistance? = 9,
        quality: EntranceMatchQuality = .match,
        includeInForced24: Bool = true,
        nearest: String? = "12856671911"
    ) -> OliveBranchEntranceSite {
        OliveBranchEntranceSite(
            id: id,
            uniqueSiteId: uniqueSiteId ?? id,
            road: road,
            cardinal: .north,
            edge: "North (TN / State Line)",
            latitude: latitude,
            longitude: longitude,
            nearestOsmNode: nearest,
            distanceMeters: distance,
            quality: quality,
            includeInForced24: includeInForced24,
            notes: "test"
        )
    }

    private static func validPin(
        id: String = "12856671911",
        vendor: OliveBranchPinVendor = .flock,
        locationClass: EntranceLocationClass = .cityLimitEntrance,
        bestEntranceId: String = "N2",
        distance: CLLocationDistance = 9
    ) -> OliveBranchEntrancePin {
        OliveBranchEntrancePin(
            id: id,
            latitude: 34.994296,
            longitude: -89.883837,
            vendor: vendor,
            nearestRoad: "Davidson Rd",
            locationClass: locationClass,
            bestEntranceId: bestEntranceId,
            distanceMeters: distance,
            notes: "test"
        )
    }
}
