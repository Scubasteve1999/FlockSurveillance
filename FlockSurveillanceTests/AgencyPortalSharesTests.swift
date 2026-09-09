import XCTest
@testable import FlockSurveillance

@MainActor
final class AgencyPortalSharesTests: XCTestCase {
    func testShippedBundleLoadsFromAppBundleWithoutNetwork() throws {
        let bundle = try AgencyPortalSharesStore.loadBundle(from: .main)
        XCTAssertEqual(bundle.schemaVersion, "1")
        XCTAssertEqual(bundle.agencies.count, 1)

        let shelby = try XCTUnwrap(bundle.agencies.first)
        XCTAssertEqual(shelby.id, AgencyPortalSharesStore.shelbyCountySOID)
        XCTAssertEqual(shelby.displayName, "Shelby County Sheriff's Office (TN)")
        XCTAssertTrue(shelby.regionLabel.localizedCaseInsensitiveContains("mid-south"))
        XCTAssertEqual(shelby.asOfDate, "2026-09-08")
        XCTAssertEqual(shelby.sourceURL, "https://transparency.flocksafety.com/shelby-county-tn-so")
        XCTAssertEqual(shelby.shares.count, 1709)
        XCTAssertTrue(shelby.incomplete)
        XCTAssertEqual(
            shelby.incompleteReason,
            "Best-effort OCR from a portal screen recording; not an official export. Some names may be missing or misread. Letters Q/U/X were not clearly captured."
        )
        XCTAssertFalse(bundle.attribution.note.contains("live vendor"))
    }

    func testAirplaneModeStoreReloadReadsBundledJSON() async throws {
        let store = AgencyPortalSharesStore()
        await store.reload()
        XCTAssertTrue(store.isLoaded)
        XCTAssertNil(store.loadError)
        XCTAssertEqual(store.agencies.count, 1)
        XCTAssertEqual(store.midSouthSamples.map(\.id), [AgencyPortalSharesStore.shelbyCountySOID])
        XCTAssertEqual(store.agency(id: AgencyPortalSharesStore.shelbyCountySOID)?.shares.count, 1709)
    }

    func testLoadIfNeededWaitsForInFlightReload() async {
        let store = AgencyPortalSharesStore()
        let reloadTask = Task { await store.reload() }
        await Task.yield()
        await store.loadIfNeeded()
        XCTAssertTrue(store.isLoaded, "loadIfNeeded must wait for the in-flight decode, not return while isLoading")
        XCTAssertFalse(store.isLoading)
        XCTAssertEqual(store.midSouthSamples.first?.id, AgencyPortalSharesStore.shelbyCountySOID)
        await reloadTask.value
    }

    func testFailedLoadCanRetryFromBundle() async {
        let store = AgencyPortalSharesStore()
        await store.reload(resourceName: "DoesNotExistAgencyPortalSharesBundle")
        XCTAssertFalse(store.isLoaded)
        XCTAssertNotNil(store.loadError)
        XCTAssertTrue(store.agencies.isEmpty)

        await store.reload()
        XCTAssertTrue(store.isLoaded)
        XCTAssertNil(store.loadError)
        XCTAssertEqual(store.agencies.first?.id, AgencyPortalSharesStore.shelbyCountySOID)
    }

    func testHonestyBannerLinesAreAlwaysPresent() {
        XCTAssertEqual(AgencyPortalSharesCopy.requiredBannerLines.count, 3)
        XCTAssertEqual(
            AgencyPortalSharesCopy.requiredBannerLines,
            [
                "Listed 1:1 shares from this portal snapshot",
                "Statewide / National Lookup: unknown unless documented here",
                "Side-door / favor searches: not visible on this card"
            ]
        )

        let completeEmpty = AgencyPortalShareAgency(
            id: "empty-complete",
            displayName: "Example PD",
            regionLabel: "Test",
            sourceTitle: "Example",
            sourceURL: "https://example.com",
            asOfDate: "2026-01-01",
            shares: [],
            incomplete: false,
            incompleteReason: nil
        )
        XCTAssertEqual(AgencyPortalSharesCopy.requiredBannerLines.count, 3)
        XCTAssertNil(AgencyPortalSharesCopy.incompleteDisclaimer(for: completeEmpty))
        XCTAssertEqual(
            AgencyPortalSharesCopy.listPlaceholder(totalShares: 0, filteredCount: 0),
            "No public share list."
        )
    }

    func testCaptionWordingIsLocked() {
        XCTAssertEqual(
            AgencyPortalSharesCopy.caption,
            "Organizations this agency has listed as sharing with (portal) — not full reach."
        )
    }

    func testIncompleteReasonSurfacedForShelby() throws {
        let bundle = try AgencyPortalSharesStore.loadBundle(from: .main)
        let shelby = try XCTUnwrap(bundle.agencies.first)
        let reason = try XCTUnwrap(AgencyPortalSharesCopy.incompleteDisclaimer(for: shelby))
        XCTAssertTrue(reason.localizedCaseInsensitiveContains("OCR"))
        XCTAssertTrue(reason.localizedCaseInsensitiveContains("not an official export"))
    }

    func testCategoryChipsComeOnlyFromBundledShares() throws {
        let bundle = try AgencyPortalSharesStore.loadBundle(from: .main)
        let shelby = try XCTUnwrap(bundle.agencies.first)
        let present = Set(shelby.presentCategories)
        XCTAssertTrue(present.contains(.federal))
        XCTAssertTrue(present.contains(.localLE))
        XCTAssertTrue(present.contains(.outOfStateLE))
        XCTAssertTrue(present.contains(.unknown))
        XCTAssertFalse(present.contains(.private), "Do not invent a Private chip when the bundle has none")

        let federalNames = shelby.shares.filter { $0.category == .federal }.map(\.name)
        XCTAssertEqual(federalNames.count, 10)
        XCTAssertTrue(federalNames.contains("[Federal] Federal Bureau of Investigation (FBI)"))
        XCTAssertFalse(federalNames.contains { $0.localizedCaseInsensitiveContains("ICE") })
    }

    func testSearchAndCategoryFilterDoNotInventPartners() throws {
        let bundle = try AgencyPortalSharesStore.loadBundle(from: .main)
        let shelby = try XCTUnwrap(bundle.agencies.first)
        let fbi = shelby.shares(matching: "FBI", category: .federal)
        XCTAssertEqual(fbi.map(\.name), ["[Federal] Federal Bureau of Investigation (FBI)"])
        XCTAssertTrue(shelby.shares(matching: "not-a-real-partner-xyz").isEmpty)

        let store = AgencyPortalSharesStore()
        store.applyLoadedBundle(bundle)
        XCTAssertEqual(store.agencies.flatMap(\.shares).count, shelby.shares.count)
    }

    func testEmptySharesPlaceholder() {
        XCTAssertEqual(
            AgencyPortalSharesCopy.listPlaceholder(totalShares: 0, filteredCount: 0),
            AgencyPortalSharesCopy.emptyList
        )
        XCTAssertEqual(
            AgencyPortalSharesCopy.listPlaceholder(totalShares: 4, filteredCount: 0),
            AgencyPortalSharesCopy.noMatches
        )
        XCTAssertNil(AgencyPortalSharesCopy.listPlaceholder(totalShares: 4, filteredCount: 2))
    }

    func testUnknownCategoryDecodesInsteadOfFailing() throws {
        let json = """
        {
          "schemaVersion":"1",
          "generatedAt":"2026-09-09",
          "attribution":{"title":"t","url":"https://example.com","note":"n"},
          "agencies":[{
            "id":"example-pd",
            "displayName":"Example PD",
            "regionLabel":"Test",
            "sourceTitle":"Example",
            "sourceURL":"https://example.com/portal",
            "asOfDate":"2026-01-01",
            "shares":[{"name":"Mystery Org","category":"somethingNew"}]
          }]
        }
        """.data(using: .utf8)!

        let bundle = try AgencyPortalSharesStore.loadBundle(from: json)
        XCTAssertEqual(bundle.agencies.first?.shares.first?.category, .unknown)
        XCTAssertEqual(bundle.agencies.first?.presentCategories, [.unknown])
    }

    func testCopyDoesNotClaimPlateSearchOrUnlistedICEReach() throws {
        let view = try readProductSource("FlockSurveillance/Features/Network/AgencyPortalSharesView.swift")
        let models = try readProductSource("FlockSurveillance/Models/AgencyPortalSharesModels.swift")
        let store = try readProductSource("FlockSurveillance/Services/AgencyPortalSharesStore.swift")
        let sharing = try readProductSource("FlockSurveillance/Features/Network/SharingNetworkView.swift")
        let sources = [view, models, store, sharing]

        for source in sources {
            XCTAssertFalse(source.contains("can search your plate"))
            XCTAssertFalse(source.contains("detected your plate"))
            XCTAssertFalse(source.localizedCaseInsensitiveContains("ICE can search"))
            XCTAssertFalse(source.contains("deport"))
        }

        XCTAssertTrue(models.contains(AgencyPortalSharesCopy.caption))
        XCTAssertTrue(models.contains(AgencyPortalSharesCopy.bannerLineA))
        XCTAssertTrue(models.contains(AgencyPortalSharesCopy.bannerLineB))
        XCTAssertTrue(models.contains(AgencyPortalSharesCopy.bannerLineC))
        XCTAssertTrue(models.contains(AgencyPortalSharesCopy.federalExplainer))
        XCTAssertTrue(view.contains("AgencyPortalSharesCopy.caption"))
        XCTAssertTrue(view.contains("AgencyPortalSharesCopy.requiredBannerLines"))
        XCTAssertTrue(view.contains("AgencyPortalSharesCopy.federalExplainer"))
        XCTAssertTrue(sharing.contains("AgencyPortalSharesCopy.midSouthSamplesTitle"))
        XCTAssertTrue(sharing.contains("AgencyPortalSharesCard"))
    }

    func testShippedSharesDoNotIncludeICERow() throws {
        let bundle = try AgencyPortalSharesStore.loadBundle(from: .main)
        let shelby = try XCTUnwrap(bundle.agencies.first)
        let iceRows = shelby.shares.filter { share in
            let tokens = share.name
                .replacingOccurrences(of: "[Federal]", with: " ")
                .split(whereSeparator: { !$0.isLetter })
                .map { $0.lowercased() }
            return tokens.contains("ice") || share.name.localizedCaseInsensitiveContains("Immigration")
        }
        XCTAssertTrue(iceRows.isEmpty, "Do not invent an ICE share row: \(iceRows.map(\.name))")
        XCTAssertTrue(AgencyPortalSharesCopy.federalExplainer.contains("ICE has no direct contract access"))
        XCTAssertFalse(AgencyPortalSharesCopy.federalExplainer.contains("ICE can search"))
    }

    func testStoreNeverFetchesTransparencyPortal() throws {
        let store = try readProductSource("FlockSurveillance/Services/AgencyPortalSharesStore.swift")
        XCTAssertFalse(store.contains("URLSession"))
        XCTAssertFalse(store.contains("transparency.flocksafety.com"))
        XCTAssertTrue(store.contains("AgencyPortalSharesBundle"))
    }

    func testSharingNetworkMapCodeStillOwnsIA() throws {
        let source = try readProductSource("FlockSurveillance/Features/Network/SharingNetworkView.swift")
        XCTAssertTrue(source.contains("maxRenderedPartners"))
        XCTAssertTrue(source.contains("FOIA names pinned to Census places"))
        XCTAssertTrue(source.contains("midSouthSamplesRow"))
        XCTAssertFalse(source.contains("DataCentral"))
        XCTAssertFalse(source.contains("DayCast"))
    }

    private func readProductSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
