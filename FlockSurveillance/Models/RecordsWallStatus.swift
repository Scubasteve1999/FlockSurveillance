import Foundation

/// Does the agency have a transparency portal? Raw values are the JSON contract.
enum PortalStatus: String, Codable, Sendable, Equatable, CaseIterable {
    case portalLive = "portal_live"
    case portalClaimed = "portal_claimed"
    case portalNoneFound = "portal_none_found"
    case portalUnknown = "portal_unknown"
}

/// How much search detail the public can see.
enum SearchesPublic: String, Codable, Sendable, Equatable, CaseIterable {
    case searchesDownload = "searches_download"
    case searchesAggregateOnly = "searches_aggregate_only"
    case searchesViaFOIAFree = "searches_via_foia_free"
    case searchesViaFOIAPaid = "searches_via_foia_paid"
    case searchesWithheld = "searches_withheld"
    case searchesUnknown = "searches_unknown"
}

enum FOIAStatus: String, Codable, Sendable, Equatable, CaseIterable {
    case foiaFree = "foia_free"
    case foiaQuoted = "foia_quoted"
    case foiaPaid = "foia_paid"
    case foiaDenied = "foia_denied"
    case foiaChallengedAG = "foia_challenged_ag"
    case foiaPending = "foia_pending"
    case foiaUnknown = "foia_unknown"
}

enum RecordsSourceType: String, Codable, Sendable, Equatable, CaseIterable {
    case agency
    case news
    case newsSecondary = "news_secondary"
    case foiaTracker = "foia_tracker"
    case indexedPortal = "indexed_portal"
}

struct RecordsWallRecord: Codable, Sendable, Equatable, Identifiable, Hashable {
    let id: String
    let jurisdiction: String
    let state: String
    let agency: String
    let portalStatus: PortalStatus
    let portalURL: String?
    let searchesPublic: SearchesPublic
    let foiaStatus: FOIAStatus
    let foiaCostUSD: Int?
    let foiaCostNote: String?
    let asOf: String
    let sourceURL: String?
    let secondarySourceURL: String?
    let sourceType: RecordsSourceType
    let scopeNote: String?

    enum CodingKeys: String, CodingKey {
        case id, jurisdiction, state, agency
        case portalStatus = "portal_status"
        case portalURL = "portal_url"
        case searchesPublic = "searches_public"
        case foiaStatus = "foia_status"
        case foiaCostUSD = "foia_cost_usd"
        case foiaCostNote = "foia_cost_note"
        case asOf = "as_of"
        case sourceURL = "source_url"
        case secondarySourceURL = "secondary_source_url"
        case sourceType = "source_type"
        case scopeNote = "scope_note"
    }

    var displayName: String { agency }

    /// True when the jurisdiction is the state itself ("Texas" / "TX").
    var isStatewide: Bool {
        OfficialMapMatching.normalizeState(jurisdiction) == OfficialMapMatching.normalizeState(state)
    }

    var placeLine: String {
        isStatewide ? "Statewide, \(state)" : "\(jurisdiction), \(state)"
    }
}

struct RecordsWallTracker: Codable, Sendable, Equatable {
    let label: String
    let url: String
    let reached: Int
    let received: Int
    let partial: Int
    let asOf: String
}

/// Texas-only aggregate. Never presented as a US rate.
struct RecordsWallTexasAggregate: Codable, Sendable, Equatable {
    let portals: Int
    let searchSharing: Int
    let camerasOnPortalsMin: Int
    let camerasApprox: Int
    let sourceURL: String
    let asOf: String
}

struct RecordsWallMeta: Codable, Sendable, Equatable {
    let tracker: RecordsWallTracker?
    let texasAggregate: RecordsWallTexasAggregate?
}

struct RecordsWallDataset: Codable, Sendable, Equatable {
    let datasetAsOf: String
    let meta: RecordsWallMeta?
    let records: [RecordsWallRecord]
}

struct RecordsWallChipPresentation: Equatable, Sendable {
    let title: String
    let portalLine: String
    let searchesLine: String
    let foiaLine: String
    let costNote: String?
    let costFootnote: String?
    let scopeNote: String?
    let sourceLine: String?
    let sourceURL: URL?
    let secondarySourceURL: URL?
    let portalURL: URL?

    var renderedLines: [String] {
        [title, portalLine, searchesLine, foiaLine, costNote, costFootnote, scopeNote, sourceLine]
            .compactMap { $0 }
    }
}

enum RecordsWallStatusCopy {
    static let listTitle = "Records wall"

    static let footnote =
        "Flock offers portals; each agency chooses what to publish. A portal is not the same as a full audit log."

    static let texasAggregateLabel = "Texas sample only"

    static func incompletenessBanner(agencyCount: Int, datasetAsOf: String) -> String {
        "Hand-checked sample of \(agencyCount) agencies as of \(displayDate(datasetAsOf)), not every agency."
    }

    static func seeAllTitle(agencyCount: Int) -> String {
        "See all \(agencyCount)"
    }

    static func costFootnote(asOf: String) -> String {
        "Quoted estimate as of \(displayDate(asOf)). Estimates can change if the request is narrowed."
    }

    /// Whole dollars with grouping, e.g. 2300000 -> "$2,300,000".
    static func dollars(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        formatter.maximumFractionDigits = 0
        return "$" + (formatter.string(from: NSNumber(value: amount)) ?? String(amount))
    }

    static func title(for record: RecordsWallRecord) -> String {
        if isChallengedOrWithheld(record) {
            return "Records challenged / withheld"
        }
        let lead: String
        switch record.portalStatus {
        case .portalLive, .portalClaimed:
            switch record.searchesPublic {
            case .searchesDownload: lead = "Portal · searches public"
            case .searchesAggregateOnly: lead = "Portal · counts only"
            default: lead = "Portal · search detail unchecked"
            }
        case .portalNoneFound:
            lead = "No portal found"
        case .portalUnknown:
            lead = "Portal not checked"
        }
        guard let suffix = foiaSuffix(record) else { return lead }
        return "\(lead) · \(suffix)"
    }

    static func chip(for record: RecordsWallRecord) -> RecordsWallChipPresentation {
        let hasCost = record.foiaCostUSD != nil
        return RecordsWallChipPresentation(
            title: title(for: record),
            portalLine: portalLine(record.portalStatus),
            searchesLine: searchesLine(record.searchesPublic),
            foiaLine: foiaLine(record),
            costNote: nonempty(record.foiaCostNote),
            costFootnote: hasCost ? costFootnote(asOf: record.asOf) : nil,
            scopeNote: nonempty(record.scopeNote),
            sourceLine: sourceLine(record),
            sourceURL: httpsURL(record.sourceURL),
            secondarySourceURL: httpsURL(record.secondarySourceURL),
            portalURL: httpsURL(record.portalURL)
        )
    }

    static func texasAggregateText(_ aggregate: RecordsWallTexasAggregate) -> String {
        "Texas only: \(aggregate.portals) agencies have portals, out of hundreds of Texas agencies. "
            + "\(aggregate.searchSharing) of \(aggregate.portals) share search detail. "
            + "Portals cover more than \(group(aggregate.camerasOnPortalsMin)) of about \(group(aggregate.camerasApprox)) cameras. "
            + "These figures describe Texas, not other states."
    }

    static func trackerText(_ tracker: RecordsWallTracker) -> String {
        "\(tracker.label): \(tracker.reached) agencies reached, \(tracker.received) responded with records, "
            + "\(tracker.partial) partial, as of \(displayDate(tracker.asOf))."
    }

    /// Every user-visible string. Source URLs are deliberately left out.
    static func userFacingStrings(dataset: RecordsWallDataset) -> [String] {
        var strings = [
            listTitle,
            footnote,
            texasAggregateLabel,
            incompletenessBanner(agencyCount: dataset.records.count, datasetAsOf: dataset.datasetAsOf),
            seeAllTitle(agencyCount: dataset.records.count)
        ]
        for record in dataset.records {
            strings.append(record.agency)
            strings.append(record.placeLine)
            strings.append(contentsOf: chip(for: record).renderedLines)
        }
        if let aggregate = dataset.meta?.texasAggregate {
            strings.append(texasAggregateText(aggregate))
        }
        if let tracker = dataset.meta?.tracker {
            strings.append(trackerText(tracker))
        }
        return strings
    }

    // MARK: - Private

    private static func isChallengedOrWithheld(_ record: RecordsWallRecord) -> Bool {
        switch record.foiaStatus {
        case .foiaDenied, .foiaChallengedAG: return true
        default: return record.searchesPublic == .searchesWithheld
        }
    }

    private static func foiaSuffix(_ record: RecordsWallRecord) -> String? {
        switch record.foiaStatus {
        case .foiaFree: return "records free"
        case .foiaQuoted:
            return record.foiaCostUSD.map { "FOIA quote \(dollars($0))" } ?? "FOIA quote"
        case .foiaPaid:
            return record.foiaCostUSD.map { "FOIA paid \(dollars($0))" } ?? "FOIA paid"
        case .foiaPending: return "FOIA pending"
        case .foiaDenied, .foiaChallengedAG, .foiaUnknown: return nil
        }
    }

    private static func portalLine(_ status: PortalStatus) -> String {
        switch status {
        case .portalLive: return "Portal: live"
        case .portalClaimed: return "Portal: listed, not verified here"
        case .portalNoneFound: return "Portal: none found"
        case .portalUnknown: return "Portal: not checked"
        }
    }

    private static func searchesLine(_ status: SearchesPublic) -> String {
        switch status {
        case .searchesDownload: return "Searches: downloadable"
        case .searchesAggregateOnly: return "Searches: counts only"
        case .searchesViaFOIAFree: return "Searches: through a records request, free"
        case .searchesViaFOIAPaid: return "Searches: through a records request, paid"
        case .searchesWithheld: return "Searches: withheld"
        case .searchesUnknown: return "Searches: not checked"
        }
    }

    private static func foiaLine(_ record: RecordsWallRecord) -> String {
        switch record.foiaStatus {
        case .foiaFree: return "Records request: free"
        case .foiaQuoted:
            return record.foiaCostUSD.map { "Records request: quoted \(dollars($0))" } ?? "Records request: quoted"
        case .foiaPaid:
            return record.foiaCostUSD.map { "Records request: paid \(dollars($0))" } ?? "Records request: paid"
        case .foiaDenied: return "Records request: denied"
        case .foiaChallengedAG: return "Records request: challenged at the Attorney General"
        case .foiaPending: return "Records request: pending"
        case .foiaUnknown: return "Records request: not checked"
        }
    }

    private static func sourceLine(_ record: RecordsWallRecord) -> String? {
        guard httpsURL(record.sourceURL) != nil else { return nil }
        return "Source · checked \(displayDate(record.asOf))"
    }

    private static func displayDate(_ raw: String) -> String {
        OfficialMapDateDisplay.render(raw).text
    }

    private static func group(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func httpsURL(_ raw: String?) -> URL? {
        guard let raw = nonempty(raw), let url = URL(string: raw), url.scheme?.lowercased() == "https" else {
            return nil
        }
        return url
    }
}
