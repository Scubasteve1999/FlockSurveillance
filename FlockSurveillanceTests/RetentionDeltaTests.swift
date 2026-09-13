import XCTest
@testable import FlockSurveillance

@MainActor
final class RetentionDeltaTests: XCTestCase {
    func testShippedBundleLoadsFromAppBundleWithoutNetwork() throws {
        let bundle = try RetentionDeltaStore.loadBundle(from: .main)
        XCTAssertEqual(bundle.schemaVersion, "1")
        XCTAssertEqual(bundle.agencies.count, 5)
        XCTAssertEqual(bundle.vendorDefault.days, 7)
        XCTAssertEqual(bundle.vendorDefault.version, "flock-le-recommended-7-day-2026-08-13")
        XCTAssertEqual(bundle.vendorDefault.asOf, "2026-08-13")
        XCTAssertEqual(
            bundle.agencies.map(\.id),
            [
                RetentionDeltaStore.boulderPDID,
                RetentionDeltaStore.amarilloPDID,
                RetentionDeltaStore.lafayettePDID,
                RetentionDeltaStore.tukwilaPDID,
                RetentionDeltaStore.greenBayPDID
            ]
        )
        XCTAssertTrue(bundle.attribution.note.localizedCaseInsensitiveContains("not configured"))
        XCTAssertTrue(bundle.attribution.note.localizedCaseInsensitiveContains("30-day"))

        let vendorURLs = Set(bundle.agencies.flatMap(\.sourceChips).map(\.url))
        XCTAssertTrue(vendorURLs.contains(bundle.vendorDefault.sourceURL))
        XCTAssertTrue(vendorURLs.contains("https://www.flocksafety.com/blog/how-does-flock-handle-license-plate-data-deletion"))
        XCTAssertTrue(vendorURLs.contains("https://www.flocksafety.com/blog/what-flocks-privacy-and-security-updates-mean-for-private-sector-customers"))
    }

    func testAirplaneModeStoreReloadReadsBundledJSON() async throws {
        let store = RetentionDeltaStore()
        await store.reload()
        XCTAssertTrue(store.isLoaded)
        XCTAssertNil(store.loadError)
        XCTAssertEqual(store.agencies.count, 5)
        XCTAssertEqual(store.agency(id: RetentionDeltaStore.boulderPDID)?.deltaLabel, .conflict)
    }

    func testLoadIfNeededWaitsForInFlightReload() async {
        let store = RetentionDeltaStore()
        let reloadTask = Task { await store.reload() }
        await Task.yield()
        await store.loadIfNeeded()
        XCTAssertTrue(store.isLoaded, "loadIfNeeded must wait for the in-flight decode, not return while isLoading")
        XCTAssertFalse(store.isLoading)
        XCTAssertEqual(store.agencies.count, 5)
        await reloadTask.value
    }

    func testFailedLoadCanRetryFromBundle() async {
        let store = RetentionDeltaStore()
        await store.reload(resourceName: "DoesNotExistRetentionDeltaBundle")
        XCTAssertFalse(store.isLoaded)
        XCTAssertNotNil(store.loadError)
        XCTAssertTrue(store.agencies.isEmpty)

        await store.reload()
        XCTAssertTrue(store.isLoaded)
        XCTAssertNil(store.loadError)
        XCTAssertEqual(store.agencies.first?.id, RetentionDeltaStore.boulderPDID)
    }

    func testDeltaLabelExpectationsForSeedRows() throws {
        let bundle = try RetentionDeltaStore.loadBundle(from: .main)
        let byID = Dictionary(uniqueKeysWithValues: bundle.agencies.map { ($0.id, $0) })

        let boulder = try XCTUnwrap(byID[RetentionDeltaStore.boulderPDID])
        XCTAssertEqual(boulder.deltaLabel, .conflict)
        XCTAssertTrue(boulder.sourceConflict)
        XCTAssertNil(boulder.localPolicyDays, "Do not invent a Boulder local_policy number from the 30 vs 14 conflict")
        XCTAssertNil(boulder.statuteCapDays)
        XCTAssertEqual(boulder.derivedDeltaLabel, .conflict)

        let amarillo = try XCTUnwrap(byID[RetentionDeltaStore.amarilloPDID])
        XCTAssertEqual(amarillo.deltaLabel, .statedEq)
        XCTAssertEqual(amarillo.localPolicyDays, 7)
        XCTAssertEqual(amarillo.vendorDefault.days, 7)
        XCTAssertEqual(amarillo.derivedDeltaLabel, .statedEq)

        let lafayette = try XCTUnwrap(byID[RetentionDeltaStore.lafayettePDID])
        XCTAssertEqual(lafayette.deltaLabel, .statedGtVendorPitch)
        XCTAssertEqual(lafayette.localPolicyDays, 30)
        XCTAssertEqual(lafayette.derivedDeltaLabel, .statedGtVendorPitch)

        let tukwila = try XCTUnwrap(byID[RetentionDeltaStore.tukwilaPDID])
        XCTAssertEqual(tukwila.deltaLabel, .conflict)
        XCTAssertEqual(tukwila.localPolicyDays, 30)
        XCTAssertEqual(tukwila.statuteCapDays, 21)
        XCTAssertEqual(tukwila.derivedDeltaLabel, .conflict)

        let greenBay = try XCTUnwrap(byID[RetentionDeltaStore.greenBayPDID])
        XCTAssertEqual(greenBay.deltaLabel, .statedGtVendorPitch)
        XCTAssertEqual(greenBay.localPolicyDays, 30)
        XCTAssertEqual(greenBay.derivedDeltaLabel, .statedGtVendorPitch)
    }

    func testFixtureDeltaLabelsMatchDerivedRule() throws {
        let bundle = try RetentionDeltaStore.loadBundle(from: .main)
        for agency in bundle.agencies {
            XCTAssertEqual(
                agency.deltaLabel,
                agency.derivedDeltaLabel,
                "Fixture delta_label must match RetentionDeltaLabel.derived for \(agency.id)"
            )
        }
    }

    func testDerivedRulesCoverNumericAndConflictCases() {
        XCTAssertEqual(
            RetentionDeltaLabel.derived(
                localPolicyDays: nil,
                statuteCapDays: nil,
                vendorDefaultDays: 7,
                sourceConflict: true
            ),
            .conflict
        )
        XCTAssertEqual(
            RetentionDeltaLabel.derived(
                localPolicyDays: 30,
                statuteCapDays: 21,
                vendorDefaultDays: 7,
                sourceConflict: false
            ),
            .conflict
        )
        XCTAssertEqual(
            RetentionDeltaLabel.derived(
                localPolicyDays: 30,
                statuteCapDays: nil,
                vendorDefaultDays: 7,
                sourceConflict: false
            ),
            .statedGtVendorPitch
        )
        XCTAssertEqual(
            RetentionDeltaLabel.derived(
                localPolicyDays: 7,
                statuteCapDays: nil,
                vendorDefaultDays: 7,
                sourceConflict: false
            ),
            .statedEq
        )
        XCTAssertEqual(
            RetentionDeltaLabel.derived(
                localPolicyDays: nil,
                statuteCapDays: 21,
                vendorDefaultDays: 7,
                sourceConflict: false
            ),
            .statuteOnly
        )
        XCTAssertEqual(
            RetentionDeltaLabel.derived(
                localPolicyDays: nil,
                statuteCapDays: nil,
                vendorDefaultDays: 7,
                sourceConflict: false
            ),
            .unknown
        )
    }

    func testConfiguredDaysAbsentUnlessFixtureExplicitlyHasIt() throws {
        let bundle = try RetentionDeltaStore.loadBundle(from: .main)
        for agency in bundle.agencies {
            XCTAssertNil(
                agency.configuredDays,
                "Do not invent configured_days for \(agency.id)"
            )
            XCTAssertEqual(agency.evidenceMode, .unknown)
        }
    }

    func testHonestyBannerLinesAreAlwaysPresent() {
        XCTAssertEqual(RetentionDeltaCopy.requiredBannerLines.count, 3)
        XCTAssertEqual(
            RetentionDeltaCopy.requiredBannerLines,
            [
                "These chips are dated public quotes, not live Flock settings",
                "A statute cap is not an agency-stated policy, and neither is a configured setting",
                "Vendor pages still mix 30-day and 7-day language — this card does not resolve that"
            ]
        )

        let complete = RetentionDeltaAgency(
            id: "example-pd",
            displayName: "Example PD",
            regionLabel: "Test",
            vendorDefault: RetentionVendorDefault(
                version: "test",
                days: 7,
                asOf: "2026-01-01",
                sourceURL: "https://example.com",
                label: "test"
            ),
            deltaLabel: .unknown,
            incomplete: false,
            incompleteReason: nil
        )
        XCTAssertEqual(RetentionDeltaCopy.requiredBannerLines.count, 3)
        XCTAssertNil(RetentionDeltaCopy.incompleteDisclaimer(for: complete))
        XCTAssertEqual(
            RetentionDeltaCopy.listPlaceholder(totalAgencies: 0),
            RetentionDeltaCopy.emptyList
        )
        XCTAssertNil(RetentionDeltaCopy.listPlaceholder(totalAgencies: 5))
    }

    func testCaptionWordingIsLocked() {
        XCTAssertEqual(
            RetentionDeltaCopy.caption,
            "Public policy quotes compared to a dated vendor pitch — not what any system is configured to today."
        )
        XCTAssertEqual(RetentionDeltaCopy.samplesTitle, "Retention samples")
        XCTAssertTrue(RetentionDeltaCopy.unknownNextTap.localizedCaseInsensitiveContains("open a dated source"))
        XCTAssertTrue(RetentionDeltaCopy.emptyList.localizedCaseInsensitiveContains("public records later"))
        XCTAssertEqual(RetentionDeltaCopy.notAffiliated, "Not affiliated with Flock Safety.")
    }

    func testChipsComeOnlyFromKnownFields() throws {
        let bundle = try RetentionDeltaStore.loadBundle(from: .main)
        let byID = Dictionary(uniqueKeysWithValues: bundle.agencies.map { ($0.id, $0) })

        let boulder = try XCTUnwrap(byID[RetentionDeltaStore.boulderPDID])
        XCTAssertEqual(boulder.presentChipKinds, [.vendorDefault, .unknown])
        XCTAssertFalse(boulder.presentChipKinds.contains(.localPolicy), "Do not invent a Boulder local-policy chip")
        XCTAssertFalse(boulder.presentChipKinds.contains(.statuteCap))

        let amarillo = try XCTUnwrap(byID[RetentionDeltaStore.amarilloPDID])
        XCTAssertEqual(amarillo.presentChipKinds, [.vendorDefault, .localPolicy, .unknown])

        let tukwila = try XCTUnwrap(byID[RetentionDeltaStore.tukwilaPDID])
        XCTAssertEqual(tukwila.presentChipKinds, [.vendorDefault, .localPolicy, .statuteCap, .unknown])
        XCTAssertEqual(tukwila.chipCaption(for: .statuteCap), "Statute cap · 21d")
    }

    func testIncompleteReasonSurfacedForConflictRows() throws {
        let bundle = try RetentionDeltaStore.loadBundle(from: .main)
        let boulder = try XCTUnwrap(bundle.agencies.first { $0.id == RetentionDeltaStore.boulderPDID })
        let reason = try XCTUnwrap(RetentionDeltaCopy.incompleteDisclaimer(for: boulder))
        XCTAssertTrue(reason.localizedCaseInsensitiveContains("30"))
        XCTAssertTrue(reason.localizedCaseInsensitiveContains("14"))

        let lafayette = try XCTUnwrap(bundle.agencies.first { $0.id == RetentionDeltaStore.lafayettePDID })
        XCTAssertNil(RetentionDeltaCopy.incompleteDisclaimer(for: lafayette))
    }

    func testUnknownEvidenceModeDecodesInsteadOfFailing() throws {
        let json = """
        {
          "schema_version":"1",
          "generated_at":"2026-09-13",
          "attribution":{"title":"t","url":"https://example.com","note":"n"},
          "vendor_default":{
            "version":"v","days":7,"as_of":"2026-08-13",
            "source_url":"https://example.com","label":"pitch"
          },
          "agencies":[{
            "id":"example-pd",
            "display_name":"Example PD",
            "region_label":"Test",
            "vendor_default":{
              "version":"v","days":7,"as_of":"2026-08-13",
              "source_url":"https://example.com","label":"pitch"
            },
            "evidence_mode":"somethingNew",
            "delta_label":"unknown"
          }]
        }
        """.data(using: .utf8)!

        let bundle = try RetentionDeltaStore.loadBundle(from: json)
        let agency = try XCTUnwrap(bundle.agencies.first)
        XCTAssertEqual(agency.evidenceMode, .unknown)
        XCTAssertNil(agency.configuredDays)
        XCTAssertEqual(agency.deltaLabel, .unknown)
        XCTAssertTrue(agency.presentChipKinds.contains(.unknown))
    }

    func testCopyDoesNotClaimPlateReadsOrProductRename() throws {
        let view = try readProductSource("FlockSurveillance/Features/Network/RetentionDeltaView.swift")
        let models = try readProductSource("FlockSurveillance/Models/RetentionDeltaModels.swift")
        let store = try readProductSource("FlockSurveillance/Services/RetentionDeltaStore.swift")
        let sharing = try readProductSource("FlockSurveillance/Features/Network/SharingNetworkView.swift")
        let sources = [view, models, store, sharing]

        for source in sources {
            XCTAssertFalse(source.contains("Flock Surveillance"))
            XCTAssertFalse(source.contains("can search your plate"))
            XCTAssertFalse(source.contains("detected your plate"))
            XCTAssertFalse(source.contains("they scanned you"))
            XCTAssertFalse(source.localizedCaseInsensitiveContains("radar detector"))
            XCTAssertFalse(source.contains("safest"))
        }

        XCTAssertTrue(models.contains(RetentionDeltaCopy.caption))
        XCTAssertTrue(models.contains(RetentionDeltaCopy.bannerLineA))
        XCTAssertTrue(models.contains(RetentionDeltaCopy.bannerLineB))
        XCTAssertTrue(models.contains(RetentionDeltaCopy.bannerLineC))
        XCTAssertTrue(view.contains("RetentionDeltaCopy.caption"))
        XCTAssertTrue(view.contains("RetentionDeltaCopy.requiredBannerLines"))
        XCTAssertTrue(sharing.contains("RetentionDeltaCopy.samplesTitle"))
        XCTAssertTrue(sharing.contains("RetentionDeltaSamplesList"))
        XCTAssertTrue(sharing.contains("retentionSamplesRow"))
    }

    func testStoreNeverFetchesVendorPortals() throws {
        let store = try readProductSource("FlockSurveillance/Services/RetentionDeltaStore.swift")
        XCTAssertFalse(store.contains("URLSession"))
        XCTAssertFalse(store.contains("transparency.flocksafety.com"))
        XCTAssertTrue(store.contains("RetentionDeltaBundle"))
    }

    func testProjectMembershipIncludesRetentionDeltaBundle() throws {
        let pbx = try readProductSource("FlockSurveillance.xcodeproj/project.pbxproj")
        XCTAssertTrue(
            pbx.contains("RetentionDeltaBundle.json"),
            "xcodegen/pbxproj must include the bundled JSON so it ships in the app"
        )
        XCTAssertTrue(pbx.contains("RetentionDeltaModels.swift"))
        XCTAssertTrue(pbx.contains("RetentionDeltaStore.swift"))
        XCTAssertTrue(pbx.contains("RetentionDeltaView.swift"))
        XCTAssertTrue(pbx.contains("RetentionDeltaTests.swift"))
    }

    func testHonestyLinesStayPlainLanguage() {
        XCTAssertEqual(
            RetentionDeltaCopy.honestyLine(for: .conflict, vendorDays: 7),
            "Public sources for this agency disagree — no single retention number."
        )
        XCTAssertEqual(
            RetentionDeltaCopy.honestyLine(for: .statedEq, vendorDays: 7),
            "This agency’s published policy quote matches Flock’s 7-day recommended default pitch."
        )
        XCTAssertEqual(
            RetentionDeltaCopy.honestyLine(for: .statedGtVendorPitch, vendorDays: 7),
            "This agency’s published policy quote is longer than Flock’s 7-day recommended default pitch."
        )
        XCTAssertFalse(RetentionDeltaCopy.honestyLine(for: .conflict, vendorDays: 7).localizedCaseInsensitiveContains("grade"))
        XCTAssertFalse(RetentionDeltaCopy.honestyLine(for: .statedGtVendorPitch, vendorDays: 7).localizedCaseInsensitiveContains("watched"))
    }

    private func readProductSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
