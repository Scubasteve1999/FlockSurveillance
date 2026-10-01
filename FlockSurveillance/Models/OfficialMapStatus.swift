import Foundation

/// Hand-checked answer to whether an agency publishes its own ALPR locations.
/// Bundled JSON only. No network. An agency with no row is `unknown`.
enum OfficialMapStatus: String, Codable, Sendable, CaseIterable {
    case publishedLive = "published_live"
    case publishedStatic = "published_static"
    case publishedProgramEnded = "published_program_ended"
    case releasedOnRequest = "released_on_request"
    case courtDisclosed = "court_disclosed"
    case courtOrderedPending = "court_ordered_pending"
    case promised
    case promiseMissed = "promise_missed"
    case refused
    case refusedUpheld = "refused_upheld"
    case noneFound = "none_found"
    case unknown
}

enum OfficialMapSourceType: String, Codable, Sendable, CaseIterable {
    case agency
    case court
    case news
    case agOpinion = "ag_opinion"
}

struct OfficialMapDataset: Codable, Sendable, Equatable {
    let datasetAsOf: String
    let records: [OfficialMapRecord]

    func record(matchingAgencyName name: String, state: String) -> OfficialMapRecord? {
        let hits = records.filter {
            OfficialMapMatching.matches(record: $0, agencyName: name, state: state)
        }
        return hits.min { lhs, rhs in
            let left = OfficialMapMatching.identityCore(lhs).count
            let right = OfficialMapMatching.identityCore(rhs).count
            if left != right { return left > right }
            return lhs.id < rhs.id
        }
    }

    func status(matchingAgencyName name: String, state: String) -> OfficialMapStatus {
        record(matchingAgencyName: name, state: state)?.status ?? .unknown
    }
}

struct OfficialMapRecord: Codable, Sendable, Equatable, Identifiable, Hashable {
    let id: String
    let jurisdiction: String
    let state: String
    let agency: String
    let status: OfficialMapStatus
    let asOf: String
    let sourceURL: String
    let sourceType: OfficialMapSourceType
    let eventDate: String?
    let agencyUpdated: String?
    let promisedDate: String?
    let upheldBy: String?
    let scopeNote: String

    init(
        id: String,
        jurisdiction: String,
        state: String,
        agency: String,
        status: OfficialMapStatus,
        asOf: String,
        sourceURL: String,
        sourceType: OfficialMapSourceType,
        eventDate: String? = nil,
        agencyUpdated: String? = nil,
        promisedDate: String? = nil,
        upheldBy: String? = nil,
        scopeNote: String
    ) {
        self.id = id
        self.jurisdiction = jurisdiction
        self.state = state
        self.agency = agency
        self.status = status
        self.asOf = asOf
        self.sourceURL = sourceURL
        self.sourceType = sourceType
        self.eventDate = eventDate
        self.agencyUpdated = agencyUpdated
        self.promisedDate = promisedDate
        self.upheldBy = upheldBy
        self.scopeNote = scopeNote
    }

    /// Name used in sentences. A role-only agency ("police", "county") keeps the jurisdiction.
    var speakingName: String {
        let agencyName = agency.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = jurisdiction.trimmingCharacters(in: .whitespacesAndNewlines)
        let generic: Set<String> = ["police", "county", "sheriff"]
        guard generic.contains(agencyName.lowercased()) else { return agencyName }
        if place.lowercased().hasSuffix(agencyName.lowercased()) { return place }
        return "\(place) \(agencyName)"
    }
}

struct OfficialMapChipPresentation: Equatable, Sendable {
    let title: String
    let subline: String
    let agencyUpdatedLine: String?
    let scopeNote: String?
    let sourceLine: String?
    let sourceURL: URL?
    let isUnknown: Bool

    var renderedLines: [String] {
        if isUnknown { return [title] }
        var lines = [title]
        if !subline.isEmpty { lines.append(subline) }
        if let agencyUpdatedLine, !agencyUpdatedLine.isEmpty { lines.append(agencyUpdatedLine) }
        if let scopeNote, !scopeNote.isEmpty { lines.append(scopeNote) }
        if let sourceLine, !sourceLine.isEmpty { lines.append(sourceLine) }
        return lines
    }
}

enum OfficialMapStatusCopy {
    static let unknownLine = "Official map status: not checked yet"
    static let footnote = "Official lists usually cover only that agency's cameras. Private and neighboring-agency cameras can feed the same network."
    static let communityTitle = "Community-mapped (not official)"
    static let communityBody = "Map pins are volunteer-mapped OpenStreetMap data. They may include other agencies' and private cameras, and may be incomplete."

    static func incompletenessBanner(agencyCount: Int, datasetAsOf: String) -> String {
        "Hand-checked list of \(agencyCount) agencies as of \(datasetAsOf). Most agencies aren't checked yet."
    }

    static func chip(for record: OfficialMapRecord) -> OfficialMapChipPresentation {
        let name = record.speakingName
        let title: String
        let subline: String
        switch record.status {
        case .publishedLive:
            title = "Official map"
            subline = "\(name) publishes its camera locations."
        case .publishedStatic:
            title = "Official list (static)"
            subline = "\(name) posted a list or map. It may not show later changes."
        case .publishedProgramEnded:
            title = "Official list, program ended"
            subline = "Posted while cameras were active. The program was paused or ended\(onClause(record.eventDate))."
        case .releasedOnRequest:
            title = "Released on request"
            subline = "\(name) gave locations to a records request. It doesn't post them."
        case .courtDisclosed:
            title = "Made public by a court"
            subline = "Locations entered the court record\(onClause(record.eventDate)). The agency didn't post them."
        case .courtOrderedPending:
            title = "Court-ordered, not yet released"
            subline = "A court ordered disclosure\(onClause(record.eventDate)). We haven't seen the release yet."
        case .promised:
            if let promised = nonempty(record.promisedDate) {
                title = "Promised by \(promised)"
                subline = "\(name) says it will publish a map by \(promised). Nothing was live when we checked."
            } else {
                title = "Promised"
                subline = "\(name) says it will publish a map. Nothing was live when we checked."
            }
        case .promiseMissed:
            title = "Promised date passed"
            if let promised = nonempty(record.promisedDate) {
                subline = "\(name) said \(promised). As of \(record.asOf), we found no map."
            } else {
                subline = "As of \(record.asOf), we found no map."
            }
        case .refused, .refusedUpheld:
            title = "Declined to publish"
            var line = "\(name) declined\(onClause(record.eventDate))."
            if let upheld = nonempty(record.upheldBy) {
                line += " Upheld by \(upheld)."
            }
            subline = line
        case .noneFound:
            title = "No official list found"
            subline = "We looked on \(record.asOf) and found none."
        case .unknown:
            return unknownChip()
        }

        let updatedLine: String?
        if record.status == .publishedLive, let updated = nonempty(record.agencyUpdated) {
            updatedLine = "Agency last updated \(updated)"
        } else {
            updatedLine = nil
        }

        let sourceLine = "Source · checked \(record.asOf)"
        let sourceURL = httpsURL(record.sourceURL)
        return OfficialMapChipPresentation(
            title: title,
            subline: subline,
            agencyUpdatedLine: updatedLine,
            scopeNote: nonempty(record.scopeNote),
            sourceLine: sourceLine,
            sourceURL: sourceURL,
            isUnknown: false
        )
    }

    static func unknownChip() -> OfficialMapChipPresentation {
        OfficialMapChipPresentation(
            title: unknownLine,
            subline: "",
            agencyUpdatedLine: nil,
            scopeNote: nil,
            sourceLine: nil,
            sourceURL: nil,
            isUnknown: true
        )
    }

    /// Every string a person can read from the bundled rows, banner, footnote, and community line.
    /// Source URLs are omitted on purpose.
    static func userFacingStrings(dataset: OfficialMapDataset) -> [String] {
        var lines = [
            incompletenessBanner(agencyCount: dataset.records.count, datasetAsOf: dataset.datasetAsOf),
            footnote,
            communityTitle,
            communityBody,
            unknownLine
        ]
        for record in dataset.records {
            lines.append(contentsOf: chip(for: record).renderedLines)
            if let updated = nonempty(record.agencyUpdated) {
                lines.append(updated)
            }
            lines.append(record.scopeNote)
        }
        return lines
    }

    private static func onClause(_ date: String?) -> String {
        guard let date = nonempty(date) else { return "" }
        return " on \(date)"
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.compare("nil", options: .caseInsensitive) == .orderedSame {
            return nil
        }
        return trimmed
    }

    private static func httpsURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
}

enum OfficialMapMatching {
    static func matches(record: OfficialMapRecord, agencyName: String, state: String) -> Bool {
        guard normalizeState(record.state) == normalizeState(state) else { return false }
        guard !agencyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard rolesCompatible(record: role(ofAgency: record.agency), partner: role(ofFreeName: agencyName)) else {
            return false
        }

        let recordCore = identityCore(record)
        let partnerCore = placeCore(name: agencyName, state: state)
        if !recordCore.isEmpty, recordCore == partnerCore { return true }

        let recordName = normalize(record.agency)
        let partnerName = normalize(agencyName)
        if recordName.contains("state police"), partnerName.contains("state police") { return true }
        return false
    }

    static func identityCore(_ record: OfficialMapRecord) -> String {
        let fromAgency = placeCore(name: record.agency, state: record.state)
        if fromAgency.isEmpty || genericCores.contains(fromAgency) {
            return placeCore(name: record.jurisdiction, state: record.state)
        }
        return fromAgency
    }

    static func placeCore(name: String, state: String) -> String {
        let stripped = strippingParentheticals(name)
        let normalized = normalize(stripped)
        let withoutState = removeStateToken(normalized, state: state)
        return stripLeadingCityOf(stripTrailingRoles(withoutState))
    }

    static func normalize(_ raw: String) -> String {
        let folded = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let scalars = folded.lowercased().unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(scalars).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func normalizeState(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count == 2, trimmed.allSatisfy(\.isLetter) {
            return trimmed.uppercased()
        }
        let key = normalize(trimmed)
        return stateNames[key] ?? trimmed.uppercased()
    }

    private static let genericCores: Set<String> = ["police", "county", "sheriff", "pd", "so"]

    private static let trailingRoleSuffixes: [[String]] = [
        ["dept", "of", "public", "safety"],
        ["department", "of", "public", "safety"],
        ["police", "department"],
        ["sheriff", "s", "office"],
        ["sheriffs", "office"],
        ["sheriff", "office"],
        ["police"],
        ["department"],
        ["dept"],
        ["pd"],
        ["sheriff"],
        ["so"],
        ["office"],
        ["services"]
    ]

    private static func stripTrailingRoles(_ normalized: String) -> String {
        var tokens = normalized.split(separator: " ").map(String.init)
        var changed = true
        while changed, !tokens.isEmpty {
            changed = false
            for suffix in trailingRoleSuffixes where tokens.count >= suffix.count && Array(tokens.suffix(suffix.count)) == suffix {
                tokens.removeLast(suffix.count)
                changed = true
                break
            }
        }
        return tokens.joined(separator: " ")
    }

    private static func removeStateToken(_ normalized: String, state: String) -> String {
        let token = normalizeState(state).lowercased()
        return normalized.split(separator: " ").map(String.init).filter { $0 != token }.joined(separator: " ")
    }

    private static func stripLeadingCityOf(_ normalized: String) -> String {
        if normalized.hasPrefix("city of ") {
            return String(normalized.dropFirst("city of ".count))
        }
        return normalized
    }

    private static func strippingParentheticals(_ raw: String) -> String {
        var result = ""
        var depth = 0
        for character in raw {
            if character == "(" {
                depth += 1
                continue
            }
            if character == ")" {
                depth = max(0, depth - 1)
                continue
            }
            if depth == 0 { result.append(character) }
        }
        return result
    }

    private enum AgencyRole {
        case police
        case sheriff
        case county
        case other
    }

    private static func role(ofAgency agency: String) -> AgencyRole {
        let name = normalize(strippingParentheticals(agency))
        if name == "police" || name.contains("police") || hasToken(name, "pd") { return .police }
        if name == "sheriff" || name.contains("sheriff") || hasToken(name, "so") { return .sheriff }
        if name == "county" { return .county }
        return .other
    }

    private static func role(ofFreeName name: String) -> AgencyRole {
        let normalized = normalize(name)
        if normalized.contains("police") || hasToken(normalized, "pd") || normalized.contains("public safety") {
            return .police
        }
        if normalized.contains("sheriff") || hasToken(normalized, "so") { return .sheriff }
        if hasToken(normalized, "county"), !normalized.contains("task force") { return .county }
        return .other
    }

    private static func rolesCompatible(record: AgencyRole, partner: AgencyRole) -> Bool {
        switch record {
        case .police: return partner == .police
        case .sheriff: return partner == .sheriff
        case .county: return partner == .sheriff || partner == .county
        case .other: return true
        }
    }

    private static func hasToken(_ normalized: String, _ token: String) -> Bool {
        normalized.split(separator: " ").contains { $0 == token }
    }

    private static let stateNames: [String: String] = [
        "alabama": "AL", "alaska": "AK", "arizona": "AZ", "arkansas": "AR", "california": "CA",
        "colorado": "CO", "connecticut": "CT", "delaware": "DE", "florida": "FL", "georgia": "GA",
        "hawaii": "HI", "idaho": "ID", "illinois": "IL", "indiana": "IN", "iowa": "IA",
        "kansas": "KS", "kentucky": "KY", "louisiana": "LA", "maine": "ME", "maryland": "MD",
        "massachusetts": "MA", "michigan": "MI", "minnesota": "MN", "mississippi": "MS", "missouri": "MO",
        "montana": "MT", "nebraska": "NE", "nevada": "NV", "new hampshire": "NH", "new jersey": "NJ",
        "new mexico": "NM", "new york": "NY", "north carolina": "NC", "north dakota": "ND", "ohio": "OH",
        "oklahoma": "OK", "oregon": "OR", "pennsylvania": "PA", "rhode island": "RI", "south carolina": "SC",
        "south dakota": "SD", "tennessee": "TN", "texas": "TX", "utah": "UT", "vermont": "VT",
        "virginia": "VA", "washington": "WA", "west virginia": "WV", "wisconsin": "WI", "wyoming": "WY",
        "district of columbia": "DC"
    ]
}
