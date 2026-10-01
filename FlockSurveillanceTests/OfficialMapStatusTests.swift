import XCTest
@testable import FlockSurveillance

final class OfficialMapStatusTests: XCTestCase {
    func testShippedDatasetLoadsFromTheAppBundle() throws {
        let dataset = try OfficialMapStatusStore.loadDataset(from: .main)
        XCTAssertEqual(dataset.datasetAsOf, "2026-09-30")
        XCTAssertEqual(dataset.records.count, 19)
    }

    func testJSONDecodesAndEveryRecordHasRequiredFields() throws {
        let data = try bundledJSONData()
        let dataset = try OfficialMapStatusStore.loadDataset(from: data)
        XCTAssertEqual(dataset.datasetAsOf, "2026-09-30")
        XCTAssertEqual(dataset.records.count, 19)
        XCTAssertEqual(Set(dataset.records.map(\.id)).count, dataset.records.count)

        let day = try NSRegularExpression(pattern: #"^\d{4}-\d{2}-\d{2}$"#)
        let monthOrDay = try NSRegularExpression(pattern: #"^\d{4}-\d{2}(-\d{2})?$"#)
        for record in dataset.records {
            XCTAssertFalse(record.asOf.isEmpty)
            XCTAssertTrue(matches(day, record.asOf), record.id)
            XCTAssertEqual(record.asOf, "2026-09-30", record.id)
            XCTAssertTrue(record.sourceURL.hasPrefix("https://"), record.id)
            XCTAssertNotNil(URL(string: record.sourceURL), record.id)
            XCTAssertFalse(record.scopeNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, record.id)
            XCTAssertNotEqual(record.status, .unknown, record.id)
            if let eventDate = record.eventDate {
                XCTAssertTrue(matches(monthOrDay, eventDate), "\(record.id) \(eventDate)")
            }
            if let promised = record.promisedDate {
                XCTAssertTrue(matches(day, promised), record.id)
            }
        }

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["datasetAsOf", "records"])
        let rows = try XCTUnwrap(object["records"] as? [[String: Any]])
        let allowed: Set<String> = [
            "id", "jurisdiction", "state", "agency", "status", "asOf", "sourceURL", "sourceType",
            "eventDate", "agencyUpdated", "promisedDate", "upheldBy", "scopeNote"
        ]
        for row in rows {
            XCTAssertTrue(allowed.isSuperset(of: row.keys))
        }
    }

    func testSeedRecordsMatchTheCuratedBrief() throws {
        let dataset = try loadDataset()
        let byID = Dictionary(uniqueKeysWithValues: dataset.records.map { ($0.id, $0) })
        XCTAssertEqual(dataset.records.map(\.id), expectedIDs)

        let alexandria = try XCTUnwrap(byID["alexandria-va"])
        XCTAssertEqual(alexandria.jurisdiction, "Alexandria")
        XCTAssertEqual(alexandria.state, "VA")
        XCTAssertEqual(alexandria.agency, "Alexandria Police Department")
        XCTAssertEqual(alexandria.status, .promised)
        XCTAssertEqual(alexandria.promisedDate, "2026-10-01")
        XCTAssertNil(alexandria.eventDate)
        XCTAssertEqual(alexandria.sourceType, .agency)
        XCTAssertEqual(
            alexandria.sourceURL,
            "https://alexandriava.gov/police-department/license-plate-reader-dashboard-and-response-to-city-council-questions-on-flock"
        )
        XCTAssertEqual(
            alexandria.scopeNote,
            "APD reports 61 fixed ALPRs. City says a map will be published by Oct 1, 2026."
        )

        let sanDiego = try XCTUnwrap(byID["san-diego-ca"])
        XCTAssertEqual(sanDiego.status, .publishedLive)
        XCTAssertEqual(sanDiego.agencyUpdated, "3/9/2026")
        XCTAssertEqual(sanDiego.sourceType, .agency)
        XCTAssertEqual(sanDiego.scopeNote, "Covers Smart Streetlight ALPRs.")
        XCTAssertEqual(
            sanDiego.sourceURL,
            "https://webmaps.sandiego.gov/portal/apps/webappviewer/index.html?id=a70a4dc00702448da5948992b144a98f"
        )

        let lexington = try XCTUnwrap(byID["lexington-ky"])
        XCTAssertEqual(lexington.agency, "Lexington Police Department (LFUCG)")
        XCTAssertEqual(lexington.status, .publishedStatic)
        XCTAssertEqual(lexington.agencyUpdated, "Counts updated 9/25/2024; map titled Dec 4, 2025")
        XCTAssertEqual(
            lexington.scopeNote,
            "125 LFUCG-owned readers. Other agencies' and private cameras aren't on it."
        )

        let louisville = try XCTUnwrap(byID["louisville-ky"])
        XCTAssertEqual(louisville.status, .refusedUpheld)
        XCTAssertEqual(louisville.eventDate, "2026-02-02")
        XCTAssertEqual(louisville.upheldBy, "Kentucky AG 26-ORD-034")
        XCTAssertEqual(louisville.sourceType, .agOpinion)
        XCTAssertEqual(louisville.sourceURL, "https://www.ag.ky.gov/Resources/orom/2026/26-ORD-034.pdf")
        XCTAssertEqual(
            louisville.scopeNote,
            "Denied as an unreasonable burden under KRS 61.872(6). Metro Council voted 20–4 against a publish-map ordinance on Apr 23, 2026."
        )

        let herald = "https://www.kentucky.com/news/politics-government/article316599303.html"
        for id in ["bowling-green-ky", "elizabethtown-ky"] {
            let record = try XCTUnwrap(byID[id])
            XCTAssertEqual(record.agency, "police")
            XCTAssertEqual(record.status, .refusedUpheld)
            XCTAssertEqual(record.eventDate, "2025-11")
            XCTAssertEqual(record.upheldBy, "Kentucky AG")
            XCTAssertEqual(record.sourceType, .news)
            XCTAssertEqual(record.sourceURL, herald)
            XCTAssertEqual(record.scopeNote, "Denied under the HB 520 articulable-risk exemption.")
        }

        for id in ["richmond-ky", "paris-ky", "frankfort-ky"] {
            let record = try XCTUnwrap(byID[id])
            XCTAssertEqual(record.agency, "police")
            XCTAssertEqual(record.status, .refused)
            XCTAssertNil(record.eventDate)
            XCTAssertNil(record.upheldBy)
            XCTAssertEqual(record.sourceType, .news)
            XCTAssertEqual(record.sourceURL, herald)
            XCTAssertEqual(record.scopeNote, "Denied a Herald-Leader records request.")
        }

        let nicholasville = try XCTUnwrap(byID["nicholasville-ky"])
        XCTAssertEqual(nicholasville.status, .refused)
        XCTAssertNil(nicholasville.eventDate)
        XCTAssertEqual(nicholasville.scopeNote, "Denied under a public-safety exemption.")

        for id in ["berea-ky", "versailles-ky"] {
            let record = try XCTUnwrap(byID[id])
            XCTAssertEqual(record.status, .releasedOnRequest)
            XCTAssertNil(record.eventDate)
            XCTAssertEqual(record.sourceURL, herald)
            XCTAssertEqual(record.scopeNote, "Gave locations to the Herald-Leader. No public map found.")
        }

        let norfolk = try XCTUnwrap(byID["norfolk-va"])
        XCTAssertEqual(norfolk.status, .courtDisclosed)
        XCTAssertEqual(norfolk.eventDate, "2025-10-31")
        XCTAssertEqual(norfolk.sourceType, .court)
        XCTAssertEqual(
            norfolk.scopeNote,
            "Schmidt v. Norfolk (E.D. Va.) order unsealed a Flock-produced location list for public-agency customers. Private customers stayed sealed."
        )

        let massachusetts = try XCTUnwrap(byID["massachusetts-state-police"])
        XCTAssertEqual(massachusetts.jurisdiction, "Massachusetts")
        XCTAssertEqual(massachusetts.state, "MA")
        XCTAssertEqual(massachusetts.agency, "Massachusetts State Police")
        XCTAssertEqual(massachusetts.status, .courtOrderedPending)
        XCTAssertEqual(massachusetts.eventDate, "2026-09-02")
        XCTAssertEqual(massachusetts.sourceType, .news)

        let eugene = try XCTUnwrap(byID["eugene-or"])
        XCTAssertEqual(eugene.status, .publishedProgramEnded)
        XCTAssertEqual(eugene.eventDate, "2025-11-07")
        XCTAssertEqual(
            eugene.scopeNote,
            "Map posted after council recommended pausing the program (Oct 14, 2025)."
        )

        let oakPark = try XCTUnwrap(byID["oak-park-il"])
        XCTAssertEqual(oakPark.status, .publishedProgramEnded)
        XCTAssertEqual(oakPark.eventDate, "2025-08-05")
        XCTAssertEqual(oakPark.agencyUpdated, "Page updated Aug 6, 2025")
        XCTAssertEqual(oakPark.sourceType, .agency)
        XCTAssertEqual(oakPark.scopeNote, "Eight units. Village ended its Flock contract Aug 5, 2025.")

        let berkeley = try XCTUnwrap(byID["berkeley-ca"])
        XCTAssertEqual(berkeley.status, .publishedStatic)
        XCTAssertEqual(berkeley.agencyUpdated, "Jul 24, 2024 deployment plan")
        XCTAssertEqual(
            berkeley.sourceURL,
            "https://berkeleyca.gov/sites/default/files/documents/2024-07-24%20%20Fixed%20Automated%20License%20Plate%20Reader%20Deployment%20Plan.pdf"
        )
        XCTAssertEqual(berkeley.scopeNote, "52 intersections. Privately monitored readers aren't listed.")

        let genesee = try XCTUnwrap(byID["genesee-county-mi"])
        XCTAssertEqual(genesee.jurisdiction, "Genesee County")
        XCTAssertEqual(genesee.agency, "county")
        XCTAssertEqual(genesee.status, .refused)
        XCTAssertNil(genesee.eventDate)
        XCTAssertEqual(genesee.scopeNote, "Refused a location map. FOIA lawsuit pending.")

        let boulder = try XCTUnwrap(byID["boulder-co"])
        XCTAssertEqual(boulder.status, .noneFound)
        XCTAssertEqual(boulder.sourceType, .agency)
        XCTAssertEqual(
            boulder.sourceURL,
            "https://bouldercolorado.gov/services/flock-safety-cameras-and-boulder-police-department"
        )
        XCTAssertEqual(boulder.scopeNote, "City page has no location list. Flock portal couldn't be checked.")
    }

    func testPublishedRowsAreAgencySourcesAndPromisesCarryDates() throws {
        let dataset = try loadDataset()
        for record in dataset.records {
            switch record.status {
            case .publishedLive, .publishedStatic:
                XCTAssertEqual(record.sourceType, .agency, record.id)
            case .promised:
                XCTAssertNotNil(record.promisedDate, record.id)
                XCTAssertFalse(record.promisedDate?.isEmpty ?? true, record.id)
            case .refusedUpheld:
                XCTAssertNotNil(record.upheldBy, record.id)
                XCTAssertFalse(record.upheldBy?.isEmpty ?? true, record.id)
            default:
                break
            }
        }
        XCTAssertEqual(dataset.records.filter { $0.status == .publishedLive }.map(\.id), ["san-diego-ca"])
        XCTAssertEqual(
            dataset.records.filter { $0.status == .publishedStatic }.map(\.id),
            ["lexington-ky", "berkeley-ca"]
        )
        XCTAssertEqual(dataset.records.filter { $0.status == .promised }.map(\.id), ["alexandria-va"])
        XCTAssertEqual(
            dataset.records.filter { $0.status == .refusedUpheld }.map(\.id),
            ["louisville-ky", "bowling-green-ky", "elizabethtown-ky"]
        )
    }

    func testCopyRendersNilEventDateWithoutNilOrDanglingOn() {
        let refused = sample(
            status: .refused,
            agency: "Richmond Police Department",
            eventDate: nil
        )
        let upheld = sample(
            status: .refusedUpheld,
            agency: "Example Police Department",
            eventDate: nil,
            upheldBy: "Example AG"
        )
        let ended = sample(status: .publishedProgramEnded, eventDate: nil)
        let disclosed = sample(status: .courtDisclosed, eventDate: nil)
        let pending = sample(status: .courtOrderedPending, eventDate: nil)
        let missed = sample(status: .promiseMissed, eventDate: nil, promisedDate: nil)
        let promised = sample(status: .promised, eventDate: nil, promisedDate: nil)

        for record in [refused, upheld, ended, disclosed, pending, missed, promised] {
            let lines = OfficialMapStatusCopy.chip(for: record).renderedLines.joined(separator: "\n")
            XCTAssertFalse(lines.localizedCaseInsensitiveContains("nil"), record.status.rawValue)
            XCTAssertFalse(lines.contains(" on "), record.status.rawValue)
            XCTAssertFalse(lines.contains(" on."), record.status.rawValue)
            XCTAssertFalse(lines.contains(" by."), record.status.rawValue)
        }

        XCTAssertEqual(
            OfficialMapStatusCopy.chip(for: ended).subline,
            "Posted while cameras were active. The program was paused or ended."
        )
        XCTAssertEqual(
            OfficialMapStatusCopy.chip(for: disclosed).subline,
            "Locations entered the court record. The agency didn't post them."
        )
        XCTAssertEqual(
            OfficialMapStatusCopy.chip(for: pending).subline,
            "A court ordered disclosure. We haven't seen the release yet."
        )
        XCTAssertEqual(
            OfficialMapStatusCopy.chip(for: refused).subline,
            "Richmond Police Department declined."
        )
        XCTAssertEqual(
            OfficialMapStatusCopy.chip(for: upheld).subline,
            "Example Police Department declined. Upheld by Example AG."
        )
        XCTAssertEqual(OfficialMapStatusCopy.chip(for: promised).title, "Promised")
        XCTAssertFalse(OfficialMapStatusCopy.chip(for: promised).subline.contains(" by "))
        let nilDate = sample(status: .refused, eventDate: "nil")
        let nilLines = OfficialMapStatusCopy.chip(for: nilDate).renderedLines.joined(separator: "\n")
        XCTAssertFalse(nilLines.localizedCaseInsensitiveContains("nil"))
        XCTAssertFalse(nilLines.contains(" on "))
        XCTAssertEqual(
            OfficialMapStatusCopy.chip(for: missed).subline,
            "As of Sep 30, 2026, we found no map."
        )
    }

    func testShippedCopyUsesStoredDatesWithoutInventingADay() throws {
        let dataset = try loadDataset()
        let byID = Dictionary(uniqueKeysWithValues: dataset.records.map { ($0.id, $0) })

        let alexandria = OfficialMapStatusCopy.chip(for: try XCTUnwrap(byID["alexandria-va"]))
        XCTAssertEqual(alexandria.title, "Promised by Oct 1, 2026")
        XCTAssertEqual(
            alexandria.subline,
            "Alexandria Police Department says it will publish a map by Oct 1, 2026. Nothing was live when we checked."
        )
        XCTAssertEqual(alexandria.sourceLine, "Source · checked Sep 30, 2026")
        XCTAssertFalse(alexandria.renderedLines.joined(separator: "\n").contains("2026-10-01"))
        XCTAssertEqual(try XCTUnwrap(byID["alexandria-va"]).promisedDate, "2026-10-01")
        XCTAssertNil(alexandria.agencyUpdatedLine)

        let sanDiego = OfficialMapStatusCopy.chip(for: try XCTUnwrap(byID["san-diego-ca"]))
        XCTAssertEqual(sanDiego.title, "Official map")
        XCTAssertEqual(sanDiego.subline, "San Diego Police Department publishes its camera locations.")
        XCTAssertEqual(sanDiego.agencyUpdatedLine, "Agency last updated 3/9/2026")

        let lexington = OfficialMapStatusCopy.chip(for: try XCTUnwrap(byID["lexington-ky"]))
        XCTAssertEqual(lexington.title, "Official list (static)")
        XCTAssertEqual(
            lexington.subline,
            "Lexington Police Department (LFUCG) posted a list or map. It may not show later changes."
        )
        XCTAssertNil(lexington.agencyUpdatedLine)

        let louisville = OfficialMapStatusCopy.chip(for: try XCTUnwrap(byID["louisville-ky"]))
        XCTAssertEqual(louisville.title, "Declined to publish")
        XCTAssertEqual(
            louisville.subline,
            "Louisville Metro Police Department declined on Feb 2, 2026. Upheld by Kentucky AG 26-ORD-034."
        )

        let bowlingGreen = OfficialMapStatusCopy.chip(for: try XCTUnwrap(byID["bowling-green-ky"]))
        XCTAssertEqual(
            bowlingGreen.subline,
            "Bowling Green police declined in Nov 2025. Upheld by Kentucky AG."
        )
        XCTAssertFalse(bowlingGreen.subline.contains("2025-11-01"))
        XCTAssertFalse(bowlingGreen.renderedLines.joined().contains("November"))

        let genesee = OfficialMapStatusCopy.chip(for: try XCTUnwrap(byID["genesee-county-mi"]))
        XCTAssertEqual(genesee.subline, "Genesee County declined.")
        XCTAssertFalse(genesee.subline.contains(" on "))

        let eugene = OfficialMapStatusCopy.chip(for: try XCTUnwrap(byID["eugene-or"]))
        XCTAssertEqual(eugene.title, "Official list, program ended")
        XCTAssertEqual(
            eugene.subline,
            "Posted while cameras were active. The program was paused or ended on Nov 7, 2025."
        )

        let boulder = OfficialMapStatusCopy.chip(for: try XCTUnwrap(byID["boulder-co"]))
        XCTAssertEqual(boulder.title, "No official list found")
        XCTAssertEqual(boulder.subline, "We looked on Sep 30, 2026 and found none.")

        XCTAssertEqual(
            OfficialMapStatusCopy.incompletenessBanner(agencyCount: dataset.records.count, datasetAsOf: dataset.datasetAsOf),
            "Hand-checked list of 19 agencies as of Sep 30, 2026. Most agencies aren't checked yet."
        )
        XCTAssertEqual(
            OfficialMapStatusCopy.incompletenessBanner(agencyCount: 4, datasetAsOf: "2020-01-01"),
            "Hand-checked list of 4 agencies as of Jan 1, 2020. Most agencies aren't checked yet."
        )
        XCTAssertFalse(
            OfficialMapStatusCopy.incompletenessBanner(agencyCount: dataset.records.count, datasetAsOf: dataset.datasetAsOf)
                .contains("%")
        )
    }

    func testUserFacingDatesFormatWithoutShiftingTheCalendarDay() {
        let full = sample(status: .refused, eventDate: "2026-10-01")
        XCTAssertEqual(
            OfficialMapStatusCopy.chip(for: full).subline,
            "Example Police Department declined on Oct 1, 2026."
        )

        let month = sample(status: .refused, eventDate: "2025-11")
        XCTAssertEqual(
            OfficialMapStatusCopy.chip(for: month).subline,
            "Example Police Department declined in Nov 2025."
        )
        XCTAssertFalse(OfficialMapStatusCopy.chip(for: month).subline.contains(" on "))

        let missing = sample(status: .refused, eventDate: nil)
        XCTAssertEqual(
            OfficialMapStatusCopy.chip(for: missing).subline,
            "Example Police Department declined."
        )

        let unparsed = sample(status: .refused, eventDate: "not-a-date")
        XCTAssertEqual(
            OfficialMapStatusCopy.chip(for: unparsed).subline,
            "Example Police Department declined on not-a-date."
        )
        XCTAssertEqual(OfficialMapDateDisplay.render("2026-02-31").text, "2026-02-31")
        XCTAssertEqual(OfficialMapDateDisplay.render("2026-02-31").precision, .raw)

        let live = OfficialMapRecord(
            id: "sample-live",
            jurisdiction: "Example",
            state: "KY",
            agency: "Example Police Department",
            status: .publishedLive,
            asOf: "2026-09-30",
            sourceURL: "https://example.com/official-map",
            sourceType: .agency,
            agencyUpdated: "2026-03-09",
            scopeNote: "Scope note."
        )
        XCTAssertEqual(
            OfficialMapStatusCopy.chip(for: live).agencyUpdatedLine,
            "Agency last updated 2026-03-09"
        )

        let previous = NSTimeZone.default
        defer { NSTimeZone.default = previous }
        for identifier in ["Pacific/Kiritimati", "Pacific/Pago_Pago", "America/Los_Angeles", "UTC"] {
            let zone = TimeZone(identifier: identifier)!
            NSTimeZone.default = zone as NSTimeZone
            XCTAssertEqual(TimeZone.current.secondsFromGMT(), zone.secondsFromGMT(), identifier)
            XCTAssertEqual(OfficialMapDateDisplay.render("2026-10-01").text, "Oct 1, 2026", identifier)
            XCTAssertEqual(OfficialMapDateDisplay.render("2026-10-01").precision, .day, identifier)
        }
    }

    func testBannedPhrasesStayOutOfUserFacingTextAndDomainStaysOutOfJSON() throws {
        let data = try bundledJSONData()
        let raw = try XCTUnwrap(String(data: data, encoding: .utf8))
        let dataset = try OfficialMapStatusStore.loadDataset(from: data)
        let banned = ["hides", "refuses transparency", "publishes nothing", "secret"]
        let userFacing = OfficialMapStatusCopy.userFacingStrings(dataset: dataset).joined(separator: "\n")

        for phrase in banned {
            XCTAssertFalse(
                userFacing.localizedCaseInsensitiveContains(phrase),
                "User-facing text contains \(phrase)"
            )
        }

        XCTAssertTrue(
            dataset.records.contains { $0.sourceURL.localizedCaseInsensitiveContains("secret") },
            "The phrase check must not scan source URLs; one curated URL contains that word."
        )
        XCTAssertFalse(raw.localizedCaseInsensitiveContains("flocksurveillance.org"))
        XCTAssertFalse(userFacing.localizedCaseInsensitiveContains("flocksurveillance.org"))

        let product = try [
            "FlockSurveillance/Models/OfficialMapStatus.swift",
            "FlockSurveillance/Services/OfficialMapStatusStore.swift",
            "FlockSurveillance/Features/Network/OfficialMapStatusChip.swift",
            "FlockSurveillance/Features/Network/SharingNetworkView.swift"
        ].map { try readProductSource($0) }.joined(separator: "\n")
        XCTAssertFalse(product.localizedCaseInsensitiveContains("flocksurveillance.org"))
        XCTAssertFalse(product.localizedCaseInsensitiveContains("hides its cameras"))
        XCTAssertFalse(product.localizedCaseInsensitiveContains("refuses transparency"))
        XCTAssertFalse(product.localizedCaseInsensitiveContains("publishes nothing"))
        XCTAssertFalse(product.localizedCaseInsensitiveContains("they scanned you"))
    }

    func testUnmatchedAgencyIsUnknown() throws {
        let dataset = try loadDataset()
        let unmatched: [(String, String)] = [
            ("Somerset MA PD", "MA"),
            ("Louisville Airport PD", "KY"),
            ("University of Louisville KY PD", "KY"),
            ("Bowling Green Warren County Drug Task Force KY", "KY"),
            ("Alexandria IN PD", "IN"),
            ("Paris IL PD", "IL"),
            ("Richmond VA PD", "VA"),
            ("Oak Park MI Dept of Public Safety", "MI"),
            ("Metro Police Authority of Genesee County MI", "MI"),
            ("Not A Real Agency", "TX"),
            ("", "KY")
        ]
        for (name, state) in unmatched {
            XCTAssertEqual(dataset.status(matchingAgencyName: name, state: state), .unknown, "\(name) \(state)")
            XCTAssertNil(dataset.record(matchingAgencyName: name, state: state), "\(name) \(state)")
        }

        let unknown = OfficialMapStatusCopy.unknownChip()
        XCTAssertEqual(unknown.title, "Official map status: not checked yet")
        XCTAssertTrue(unknown.isUnknown)
        XCTAssertNil(unknown.sourceURL)
        XCTAssertNil(unknown.scopeNote)
        XCTAssertEqual(unknown.renderedLines, ["Official map status: not checked yet"])
    }

    func testNormalizedNameAndStateMatchSharingNetworkStyleNames() throws {
        let dataset = try loadDataset()
        let expected: [(String, String, String)] = [
            ("Alexandria Police Department", "VA", "alexandria-va"),
            ("Alexandria VA PD", "VA", "alexandria-va"),
            ("City of Alexandria Police Department", "Virginia", "alexandria-va"),
            ("San Diego CA PD", "CA", "san-diego-ca"),
            ("Lexington KY PD", "KY", "lexington-ky"),
            ("Louisville Metro KY PD", "KY", "louisville-ky"),
            ("Bowling Green KY PD", "KY", "bowling-green-ky"),
            ("Bowling Green KY PD", "OH", ""),
            ("Elizabethtown KY PD", "KY", "elizabethtown-ky"),
            ("Richmond KY PD", "KY", "richmond-ky"),
            ("Paris KY PD", "KY", "paris-ky"),
            ("Frankfort KY PD", "KY", "frankfort-ky"),
            ("Nicholasville KY PD", "KY", "nicholasville-ky"),
            ("Berea KY PD", "KY", "berea-ky"),
            ("Versailles KY PD", "KY", "versailles-ky"),
            ("Norfolk VA PD", "VA", "norfolk-va"),
            ("Massachusetts State Police", "MA", "massachusetts-state-police"),
            ("MA State Police", "MA", "massachusetts-state-police"),
            ("Eugene OR PD", "OR", "eugene-or"),
            ("Oak Park IL PD", "IL", "oak-park-il"),
            ("Berkeley CA PD", "CA", "berkeley-ca"),
            ("Berkeley IL PD", "IL", ""),
            ("Genesee County MI SO", "MI", "genesee-county-mi"),
            ("Genesee County NY SO", "NY", ""),
            ("Boulder CO PD", "CO", "boulder-co")
        ]
        for (name, state, id) in expected {
            let match = dataset.record(matchingAgencyName: name, state: state)
            if id.isEmpty {
                XCTAssertNil(match, "\(name) \(state)")
            } else {
                XCTAssertEqual(match?.id, id, "\(name) \(state)")
            }
        }
    }

    func testChipIsOnThePartnerAgencySheetAndDoesNotFetch() throws {
        let sharing = try readProductSource("FlockSurveillance/Features/Network/SharingNetworkView.swift")
        XCTAssertTrue(sharing.contains("OfficialMapStatusSurface(agencyName: partner.name, state: partner.state)"))
        XCTAssertTrue(sharing.contains("struct SharingPartnerSheet"))
        XCTAssertFalse(sharing.contains("OfficialMapStatus("))

        let chip = try readProductSource("FlockSurveillance/Features/Network/OfficialMapStatusChip.swift")
        XCTAssertTrue(chip.contains("OfficialMapStatusCopy.unknownLine"))
        XCTAssertTrue(chip.contains("AppTheme.mutedForeground"))
        XCTAssertTrue(chip.contains("Link(destination: url)"))
        XCTAssertTrue(chip.contains("official-map-status-community"))
        XCTAssertTrue(chip.contains("official-map-status-footnote"))
        XCTAssertTrue(chip.contains("official-map-status-banner"))
        XCTAssertTrue(chip.contains("AppTypography.rowTitle"))
        XCTAssertTrue(chip.contains("AppTypography.footer"))
        XCTAssertTrue(chip.contains("fixedSize(horizontal: false, vertical: true)"))
        XCTAssertFalse(chip.contains(".font(.system(size:"))
        XCTAssertFalse(chip.contains("AppTheme.primary"))
        XCTAssertFalse(chip.contains("AppTheme.critical"))
        XCTAssertFalse(chip.contains("%"))

        let store = try readProductSource("FlockSurveillance/Services/OfficialMapStatusStore.swift")
        XCTAssertFalse(store.contains("URLSession"))
        XCTAssertTrue(store.contains("OfficialMapStatus"))
        XCTAssertFalse(store.contains("http://"))

        for path in [
            "FlockSurveillance/Features/Map/MapRadarView.swift",
            "FlockSurveillance/Features/Map/CityRankingsStrip.swift",
            "FlockSurveillance/Features/Route/DriveModeView.swift",
            "FlockSurveillance/CarPlay/CarPlaySceneDelegate.swift",
            "NearbyCamerasWidget/NearbyCamerasWidget.swift",
            "FlockSurveillance/Features/Network/AgencyPortalSharesView.swift",
            "FlockSurveillance/Features/Network/RetentionDeltaView.swift"
        ] {
            let source = try readProductSource(path)
            XCTAssertFalse(source.contains("OfficialMapStatus"), path)
        }
    }

    func testHonestyLinesStaySeparateFromPinCounts() {
        XCTAssertEqual(
            OfficialMapStatusCopy.footnote,
            "Official lists usually cover only that agency's cameras. Private and neighboring-agency cameras can feed the same network."
        )
        XCTAssertEqual(OfficialMapStatusCopy.communityTitle, "Community-mapped (not official)")
        XCTAssertEqual(
            OfficialMapStatusCopy.communityBody,
            "Map pins are volunteer-mapped OpenStreetMap data. They may include other agencies' and private cameras, and may be incomplete."
        )
        XCTAssertFalse(OfficialMapStatusCopy.communityBody.contains("0"))
        XCTAssertFalse(OfficialMapStatusCopy.communityBody.contains("1"))
        XCTAssertFalse(OfficialMapStatusCopy.footnote.contains("%"))
    }

    private func loadDataset() throws -> OfficialMapDataset {
        try OfficialMapStatusStore.loadDataset(from: bundledJSONData())
    }

    private func bundledJSONData() throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FlockSurveillance/Resources/OfficialMapStatus.json")
        return try Data(contentsOf: url)
    }

    private func readProductSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func matches(_ expression: NSRegularExpression, _ value: String) -> Bool {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.firstMatch(in: value, range: range) != nil
    }

    private func sample(
        status: OfficialMapStatus,
        agency: String = "Example Police Department",
        eventDate: String?,
        promisedDate: String? = nil,
        upheldBy: String? = nil
    ) -> OfficialMapRecord {
        OfficialMapRecord(
            id: "sample",
            jurisdiction: "Example",
            state: "KY",
            agency: agency,
            status: status,
            asOf: "2026-09-30",
            sourceURL: "https://example.com/official-map",
            sourceType: .news,
            eventDate: eventDate,
            promisedDate: promisedDate,
            upheldBy: upheldBy,
            scopeNote: "Scope note."
        )
    }

    private let expectedIDs = [
        "alexandria-va",
        "san-diego-ca",
        "lexington-ky",
        "louisville-ky",
        "bowling-green-ky",
        "elizabethtown-ky",
        "richmond-ky",
        "paris-ky",
        "frankfort-ky",
        "nicholasville-ky",
        "berea-ky",
        "versailles-ky",
        "norfolk-va",
        "massachusetts-state-police",
        "eugene-or",
        "oak-park-il",
        "berkeley-ca",
        "genesee-county-mi",
        "boulder-co"
    ]
}
