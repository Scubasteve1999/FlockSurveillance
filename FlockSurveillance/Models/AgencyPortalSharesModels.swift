import Foundation

/// Bundled snapshot of organizations an agency has *listed* on a public
/// transparency portal as sharing with. Not live reach. Not plate-read access.
struct AgencyPortalSharesBundle: Codable, Sendable {
    let schemaVersion: String
    let generatedAt: String
    let attribution: AgencyPortalSharesAttribution
    let agencies: [AgencyPortalShareAgency]
}

struct AgencyPortalSharesAttribution: Codable, Sendable {
    let title: String
    let url: String
    let note: String
}

enum AgencyPortalShareCategory: String, Codable, CaseIterable, Sendable {
    case localLE
    case outOfStateLE
    case federal
    case `private`
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AgencyPortalShareCategory(rawValue: raw) ?? .unknown
    }

    var chipLabel: String {
        switch self {
        case .localLE: return "Local LE"
        case .outOfStateLE: return "Out-of-state LE"
        case .federal: return "Federal"
        case .private: return "Private"
        case .unknown: return "Unknown"
        }
    }
}

struct AgencyPortalShare: Codable, Sendable, Hashable, Identifiable {
    let name: String
    let category: AgencyPortalShareCategory

    var id: String { "\(category.rawValue)|\(name)" }
}

struct AgencyPortalShareAgency: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let displayName: String
    let regionLabel: String
    let sourceTitle: String
    let sourceURL: String
    let asOfDate: String
    let shares: [AgencyPortalShare]
    let notes: String?
    let incomplete: Bool
    let incompleteReason: String?

    enum CodingKeys: String, CodingKey {
        case id, displayName, regionLabel, sourceTitle, sourceURL, asOfDate
        case shares, notes, incomplete, incompleteReason
    }

    init(
        id: String,
        displayName: String,
        regionLabel: String,
        sourceTitle: String,
        sourceURL: String,
        asOfDate: String,
        shares: [AgencyPortalShare],
        notes: String? = nil,
        incomplete: Bool = false,
        incompleteReason: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.regionLabel = regionLabel
        self.sourceTitle = sourceTitle
        self.sourceURL = sourceURL
        self.asOfDate = asOfDate
        self.shares = shares
        self.notes = notes
        self.incomplete = incomplete
        self.incompleteReason = incompleteReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        regionLabel = try container.decode(String.self, forKey: .regionLabel)
        sourceTitle = try container.decode(String.self, forKey: .sourceTitle)
        sourceURL = try container.decode(String.self, forKey: .sourceURL)
        asOfDate = try container.decode(String.self, forKey: .asOfDate)
        shares = try container.decodeIfPresent([AgencyPortalShare].self, forKey: .shares) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        incomplete = try container.decodeIfPresent(Bool.self, forKey: .incomplete) ?? false
        incompleteReason = try container.decodeIfPresent(String.self, forKey: .incompleteReason)
    }

    /// Categories that actually appear on this agency's listed shares — never invented.
    var presentCategories: [AgencyPortalShareCategory] {
        let present = Set(shares.map(\.category))
        return AgencyPortalShareCategory.allCases.filter { present.contains($0) }
    }

    var sourceLink: URL? {
        URL(string: sourceURL)
    }

    func shares(
        matching query: String,
        category: AgencyPortalShareCategory? = nil
    ) -> [AgencyPortalShare] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let needle = trimmed.lowercased()
        return shares.filter { share in
            if let category, share.category != category { return false }
            if needle.isEmpty { return true }
            if share.name.lowercased().contains(needle) { return true }
            return share.category.chipLabel.lowercased().contains(needle)
        }
    }
}

/// Locked honesty copy for the per-agency portal-shares card.
enum AgencyPortalSharesCopy {
    static let caption =
        "Organizations this agency has listed as sharing with (portal) — not full reach."

    static let bannerLineA = "Listed 1:1 shares from this portal snapshot"
    static let bannerLineB = "Statewide / National Lookup: unknown unless documented here"
    static let bannerLineC = "Side-door / favor searches: not visible on this card"

    static let bannerLines: [String] = [bannerLineA, bannerLineB, bannerLineC]

    static let emptyList = "No public share list."
    static let noMatches = "No matching organizations."

    static let federalExplainer =
        "Flock says ICE has no direct contract access; local agencies may still share 1:1 or run searches."

    static let midSouthSamplesTitle = "Mid-South samples"
    static let asOfPrefix = "As of"

    /// Always-on incompleteness banner. Independent of `incomplete`.
    static var requiredBannerLines: [String] { bannerLines }

    static func incompleteDisclaimer(for agency: AgencyPortalShareAgency) -> String? {
        guard agency.incomplete else { return nil }
        let reason = agency.incompleteReason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return reason.isEmpty ? nil : reason
    }

    static func listPlaceholder(totalShares: Int, filteredCount: Int) -> String? {
        if totalShares == 0 { return emptyList }
        if filteredCount == 0 { return noMatches }
        return nil
    }
}
