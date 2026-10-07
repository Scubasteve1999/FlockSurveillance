import XCTest
@testable import FlockSurveillance

final class RecordsWallStatusTests: XCTestCase {
    private let expectedIDs = [
        "north-richland-hills-tx", "sealy-tx", "victoria-tx", "harris-county-sheriff-tx",
        "irving-tx", "carrollton-tx", "texas-dps", "txdot-tx", "live-oak-tx",
        "corinth-tx", "prosper-tx", "alexandria-va"
    ]

    private func loadDataset() throws -> RecordsWallDataset {
        try RecordsWallStatusStore.loadDataset(from: bundledJSONData())
    }

    private func repoURL(_ relative: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relative)
    }

    private func bundledJSONData() throws -> Data {
        try Data(contentsOf: repoURL("FlockSurveillance/Resources/RecordsWallStatus.json"))
    }

    private func readSource(_ relative: String) throws -> String {
        try String(contentsOf: repoURL(relative), encoding: .utf8)
    }

    private func record(_ id: String) throws -> RecordsWallRecord {
        try XCTUnwrap(loadDataset().records.first { $0.id == id }, id)
    }

    // MARK: - Decoding

    func testShippedDatasetLoadsFromTheAppBundle() throws {
        let dataset = try RecordsWallStatusStore.loadDataset(from: .main)
        XCTAssertEqual(dataset.datasetAsOf, "2026-10-06")
        XCTAssertEqual(dataset.records.map(\.id), expectedIDs)
    }

    func testAllRowsDecodeWithUniqueIDsAndHTTPSURLs() throws {
        let dataset = try loadDataset()
        XCTAssertEqual(Set(dataset.records.map(\.id)).count, dataset.records.count)
        let isoDate = try NSRegularExpression(pattern: #"^\d{4}-\d{2}-\d{2}$"#)
        for record in dataset.records {
            let range = NSRange(record.asOf.startIndex..., in: record.asOf)
            XCTAssertNotNil(isoDate.firstMatch(in: record.asOf, range: range), record.id)
            for raw in [record.sourceURL, record.secondarySourceURL, record.portalURL].compactMap({ $0 }) {
                XCTAssertEqual(URL(string: raw)?.scheme, "https", "\(record.id) \(raw)")
            }
        }
    }

    func testMetaDecodes() throws {
        let meta = try XCTUnwrap(loadDataset().meta)
        let tracker = try XCTUnwrap(meta.tracker)
        XCTAssertEqual(tracker.url, "https://www.texasprivacycoalition.com/foia")
        XCTAssertEqual([tracker.reached, tracker.received, tracker.partial], [186, 38, 111])
        let aggregate = try XCTUnwrap(meta.texasAggregate)
        XCTAssertEqual(aggregate.portals, 60)
        XCTAssertEqual(aggregate.searchSharing, 16)
        XCTAssertEqual(aggregate.camerasOnPortalsMin, 2600)
        XCTAssertEqual(aggregate.camerasApprox, 13000)
    }

    func testEnumRawValuesAreExact() {
        XCTAssertEqual(PortalStatus.allCases.map(\.rawValue),
                       ["portal_live", "portal_claimed", "portal_none_found", "portal_unknown"])
        XCTAssertEqual(SearchesPublic.allCases.map(\.rawValue),
                       ["searches_download", "searches_aggregate_only", "searches_via_foia_free",
                        "searches_via_foia_paid", "searches_withheld", "searches_unknown"])
        XCTAssertEqual(FOIAStatus.allCases.map(\.rawValue),
                       ["foia_free", "foia_quoted", "foia_paid", "foia_denied",
                        "foia_challenged_ag", "foia_pending", "foia_unknown"])
        XCTAssertEqual(RecordsSourceType.allCases.map(\.rawValue),
                       ["agency", "news", "news_secondary", "foia_tracker", "indexed_portal"])
    }

    func testSeedFacts() throws {
        let nrh = try record("north-richland-hills-tx")
        XCTAssertEqual(nrh.foiaStatus, .foiaQuoted)
        XCTAssertEqual(nrh.foiaCostUSD, 2_300_000)
        XCTAssertEqual(nrh.portalStatus, .portalUnknown)
        XCTAssertEqual(try record("sealy-tx").searchesPublic, .searchesViaFOIAFree)
        XCTAssertEqual(try record("victoria-tx").foiaCostUSD, 5000)
        XCTAssertEqual(try record("harris-county-sheriff-tx").foiaCostUSD, 121_602)
        let irving = try record("irving-tx")
        XCTAssertEqual(irving.foiaCostUSD, 70_000)
        XCTAssertEqual(irving.sourceType, .newsSecondary)
        XCTAssertEqual(try record("carrollton-tx").foiaStatus, .foiaFree)
        let dps = try record("texas-dps")
        XCTAssertEqual(dps.portalStatus, .portalNoneFound)
        XCTAssertEqual(dps.searchesPublic, .searchesWithheld)
        XCTAssertEqual(try record("txdot-tx").foiaStatus, .foiaChallengedAG)
        XCTAssertEqual(try record("live-oak-tx").portalURL, "https://transparency.flocksafety.com/live-oak-tx-pd-")
        XCTAssertEqual(try record("alexandria-va").portalStatus, .portalClaimed)
    }

    func testNRHDoesNotInventAModifiedPrice() throws {
        let nrh = try record("north-richland-hills-tx")
        XCTAssertEqual(nrh.foiaCostUSD, 2_300_000)
        let text = RecordsWallStatusCopy.chip(for: nrh).renderedLines.joined(separator: "\n")
        let amounts = text.components(separatedBy: "$").dropFirst()
        // $2,300,000 and the $15/hr rate are the only dollar figures.
        XCTAssertEqual(amounts.count, 3, text) // title, line, and note rate
        XCTAssertTrue(text.contains("$15"))
    }

    func testProsperIsCountsOnlyNeverDownload() throws {
        let prosper = try record("prosper-tx")
        XCTAssertEqual(prosper.searchesPublic, .searchesAggregateOnly)
        for record in try loadDataset().records {
            XCTAssertNotEqual(record.searchesPublic, .searchesDownload, record.id)
        }
        XCTAssertEqual(RecordsWallStatusCopy.title(for: prosper), "Portal · counts only")
        XCTAssertTrue(prosper.scopeNote?.contains("unverified") == true)
    }

    func testCorinthIsNotSearchSharing() throws {
        let corinth = try record("corinth-tx")
        XCTAssertEqual(corinth.searchesPublic, .searchesUnknown)
        XCTAssertEqual(corinth.portalStatus, .portalUnknown)
        XCTAssertTrue(corinth.scopeNote?.contains("not search sharing") == true)
    }

    // MARK: - Copy

    func testDollarFormatting() {
        XCTAssertEqual(RecordsWallStatusCopy.dollars(2_300_000), "$2,300,000")
        XCTAssertEqual(RecordsWallStatusCopy.dollars(121_602), "$121,602")
        XCTAssertEqual(RecordsWallStatusCopy.dollars(5000), "$5,000")
        XCTAssertEqual(RecordsWallStatusCopy.dollars(0), "$0")
    }

    func testNRHChipShowsQuoteAndSourceDate() throws {
        let chip = RecordsWallStatusCopy.chip(for: try record("north-richland-hills-tx"))
        XCTAssertEqual(chip.title, "Portal not checked · FOIA quote $2,300,000")
        XCTAssertEqual(chip.foiaLine, "Records request: quoted $2,300,000")
        XCTAssertEqual(chip.costFootnote,
                       "Quoted estimate as of Oct 5, 2026. Estimates can change if the request is narrowed.")
        XCTAssertEqual(chip.sourceLine, "Source · checked Oct 5, 2026")
        XCTAssertEqual(chip.sourceURL?.host, "www.texastribune.org")
    }

    func testTitlesForEachSampleKind() throws {
        XCTAssertEqual(RecordsWallStatusCopy.title(for: try record("sealy-tx")), "Portal not checked · records free")
        XCTAssertEqual(RecordsWallStatusCopy.title(for: try record("texas-dps")), "Records challenged / withheld")
        XCTAssertEqual(RecordsWallStatusCopy.title(for: try record("txdot-tx")), "Records challenged / withheld")
        XCTAssertEqual(RecordsWallStatusCopy.title(for: try record("live-oak-tx")), "Portal · search detail unchecked")
        XCTAssertEqual(RecordsWallStatusCopy.title(for: try record("alexandria-va")), "Portal · search detail unchecked")
        let none = RecordsWallRecord(
            id: "x", jurisdiction: "X", state: "TX", agency: "X PD",
            portalStatus: .portalNoneFound, portalURL: nil, searchesPublic: .searchesUnknown,
            foiaStatus: .foiaFree, foiaCostUSD: nil, foiaCostNote: nil, asOf: "2026-10-06",
            sourceURL: nil, secondarySourceURL: nil, sourceType: .agency, scopeNote: nil
        )
        XCTAssertEqual(RecordsWallStatusCopy.title(for: none), "No portal found · records free")
    }

    func testDownloadTitleIsOnlyForExplicitDownload() {
        let record = RecordsWallRecord(
            id: "d", jurisdiction: "D", state: "TX", agency: "D PD",
            portalStatus: .portalLive, portalURL: nil, searchesPublic: .searchesDownload,
            foiaStatus: .foiaUnknown, foiaCostUSD: nil, foiaCostNote: nil, asOf: "2026-10-06",
            sourceURL: nil, secondarySourceURL: nil, sourceType: .agency, scopeNote: nil
        )
        XCTAssertEqual(RecordsWallStatusCopy.title(for: record), "Portal · searches public")
    }

    func testCostFootnoteOnlyWhenDollarsShown() throws {
        for record in try loadDataset().records {
            let chip = RecordsWallStatusCopy.chip(for: record)
            XCTAssertEqual(chip.costFootnote != nil, record.foiaCostUSD != nil, record.id)
        }
    }

    func testIncompletenessBannerAndFootnote() throws {
        let dataset = try loadDataset()
        XCTAssertEqual(
            RecordsWallStatusCopy.incompletenessBanner(agencyCount: dataset.records.count, datasetAsOf: dataset.datasetAsOf),
            "Hand-checked sample of 12 agencies as of Oct 6, 2026, not every agency."
        )
        XCTAssertEqual(
            RecordsWallStatusCopy.footnote,
            "Flock offers portals; each agency chooses what to publish. A portal is not the same as a full audit log."
        )
        XCTAssertEqual(RecordsWallStatusCopy.seeAllTitle(agencyCount: 12), "See all 12")
    }

    func testTexasAggregateIsLabeledTexasOnly() throws {
        let aggregate = try XCTUnwrap(loadDataset().meta?.texasAggregate)
        let text = RecordsWallStatusCopy.texasAggregateText(aggregate)
        XCTAssertTrue(text.hasPrefix("Texas only"))
        XCTAssertTrue(text.contains("16 of 60"))
        XCTAssertTrue(text.contains("2,600"))
        XCTAssertTrue(text.contains("13,000"))
    }

    // MARK: - Banned phrases

    func testBannedPhrasesStayOutOfUserFacingText() throws {
        let dataset = try loadDataset()
        let text = RecordsWallStatusCopy.userFacingStrings(dataset: dataset).joined(separator: "\n").lowercased()
        let phrases = [
            "texas hides", "hides flock", "agencies refuse", "refuses transparency",
            "flock blocks", "national rate", "nationwide rate", "portal is down", "cloudflare"
        ]
        for phrase in phrases {
            XCTAssertFalse(text.contains(phrase), phrase)
        }
        for word in ["fine", "ransom", "bribe"] {
            let pattern = "\\b\(word)\\b"
            XCTAssertNil(text.range(of: pattern, options: .regularExpression), word)
        }
    }

    func testBannedPhrasesStayOutOfProductSourceAndJSON() throws {
        let files = [
            "FlockSurveillance/Models/RecordsWallStatus.swift",
            "FlockSurveillance/Models/RecordsWallStatusList.swift",
            "FlockSurveillance/Services/RecordsWallStatusStore.swift",
            "FlockSurveillance/Features/Network/RecordsWallStatusChip.swift",
            "FlockSurveillance/Features/Network/RecordsWallList.swift",
            "FlockSurveillance/Resources/RecordsWallStatus.json"
        ]
        for file in files {
            let text = try readSource(file).lowercased()
            for phrase in ["texas hides", "agencies refuse", "flock blocks", "ransom", "bribe"] {
                XCTAssertFalse(text.contains(phrase), "\(file) \(phrase)")
            }
        }
    }

    // MARK: - Separation, wiring, accessibility

    func testStoreIsBundleOnly() throws {
        let text = try readSource("FlockSurveillance/Services/RecordsWallStatusStore.swift")
        XCTAssertFalse(text.contains("URLSession"))
        XCTAssertFalse(text.contains("http://"))
    }

    func testDoesNotTouchOfficialMapOrPortalShareData() throws {
        let sources = try [
            "FlockSurveillance/Models/RecordsWallStatus.swift",
            "FlockSurveillance/Models/RecordsWallStatusList.swift",
            "FlockSurveillance/Services/RecordsWallStatusStore.swift",
            "FlockSurveillance/Features/Network/RecordsWallStatusChip.swift",
            "FlockSurveillance/Features/Network/RecordsWallList.swift"
        ].map(readSource)
        for text in sources {
            XCTAssertFalse(text.contains("OfficialMapStatus"))
            XCTAssertFalse(text.contains("AgencyPortalShares"))
        }
    }

    func testRecordsWallOnlyReferencedFromSharingNetwork() throws {
        for file in [
            "FlockSurveillance/Features/Map/MapRadarView.swift",
            "FlockSurveillance/Features/Network/AgencyPortalSharesView.swift"
        ] {
            guard let text = try? readSource(file) else { continue }
            XCTAssertFalse(text.contains("RecordsWall"), file)
        }
        let network = try readSource("FlockSurveillance/Features/Network/SharingNetworkView.swift")
        XCTAssertTrue(network.contains("recordsWallRow"))
        XCTAssertTrue(network.contains("RecordsWallList()"))
    }

    func testContainersUseContainAndTypographyTokens() throws {
        for file in [
            "FlockSurveillance/Features/Network/RecordsWallStatusChip.swift",
            "FlockSurveillance/Features/Network/RecordsWallList.swift"
        ] {
            let text = try readSource(file)
            XCTAssertTrue(text.contains(".accessibilityElement(children: .contain)"), file)
            XCTAssertFalse(text.contains(".font(.system(size:"), file)
            XCTAssertFalse(text.contains("AppTheme.primary"), file)
            XCTAssertFalse(text.contains("Color(hex"), file)
        }
    }

    func testOfficialMapStatusJSONUntouched() throws {
        let data = try Data(contentsOf: repoURL("FlockSurveillance/Resources/OfficialMapStatus.json"))
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["datasetAsOf"] as? String, "2026-09-30")
    }

    // MARK: - List model

    func testListModelGroupsEveryRecordOnce() throws {
        let dataset = try loadDataset()
        let model = RecordsWallListModel(dataset: dataset)
        XCTAssertEqual(model.groups.flatMap(\.records).count, dataset.records.count)
        XCTAssertEqual(Set(model.groups.flatMap(\.records).map(\.id)), Set(expectedIDs))
        let challenged = model.groups.first { $0.kind == .challenged }?.records.map(\.id) ?? []
        XCTAssertEqual(Set(challenged), ["texas-dps", "txdot-tx"])
    }
}
