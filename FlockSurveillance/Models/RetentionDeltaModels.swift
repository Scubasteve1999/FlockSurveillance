import Foundation

/// Bundled snapshot of public retention *quotes* vs a dated vendor pitch.
/// Not configured days. Not a live vendor scrape. Not plate-read access.
struct RetentionDeltaBundle: Codable, Sendable {
    let schemaVersion: String
    let generatedAt: String
    let attribution: RetentionDeltaAttribution
    let vendorDefault: RetentionVendorDefault
    let agencies: [RetentionDeltaAgency]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case generatedAt = "generated_at"
        case attribution
        case vendorDefault = "vendor_default"
        case agencies
    }
}

struct RetentionDeltaAttribution: Codable, Sendable {
    let title: String
    let url: String
    let note: String
}

/// Versioned vendor pitch — not a configured setting for any agency.
struct RetentionVendorDefault: Codable, Sendable, Hashable {
    let version: String
    let days: Int
    let asOf: String
    let sourceURL: String
    let label: String

    enum CodingKeys: String, CodingKey {
        case version, days, label
        case asOf = "as_of"
        case sourceURL = "source_url"
    }
}

struct RetentionSourceChip: Codable, Sendable, Hashable, Identifiable {
    let title: String
    let url: String
    let asOfDate: String

    enum CodingKeys: String, CodingKey {
        case title, url
        case asOfDate = "as_of_date"
    }

    var id: String { "\(asOfDate)|\(url)" }

    var link: URL? { URL(string: url) }
}

enum RetentionEvidenceMode: String, Codable, Sendable {
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = RetentionEvidenceMode(rawValue: raw) ?? .unknown
    }
}

/// Frozen on each fixture row. Canonical rule is `derived(...)` — tests require they match.
enum RetentionDeltaLabel: String, Codable, Sendable, Hashable {
    case statedGtVendorPitch = "stated_gt_vendor_pitch"
    case statedEq = "stated_eq"
    case statuteOnly = "statute_only"
    case unknown
    case conflict

    /// Derive a label from known fields. Documented rule (do not invent numbers):
    /// 1. `conflict` if agency sources disagree (`sourceConflict`) **or**
    ///    `localPolicyDays` and `statuteCapDays` are both known and differ
    /// 2. `stated_gt_vendor_pitch` if `localPolicyDays` > vendor default days
    /// 3. `stated_eq` if those two are equal
    /// 4. `statute_only` if only the statute cap is known
    /// 5. `unknown` otherwise
    static func derived(
        localPolicyDays: Int?,
        statuteCapDays: Int?,
        vendorDefaultDays: Int,
        sourceConflict: Bool
    ) -> RetentionDeltaLabel {
        if sourceConflict { return .conflict }
        if let local = localPolicyDays, let statute = statuteCapDays, local != statute {
            return .conflict
        }
        if let local = localPolicyDays {
            if local > vendorDefaultDays { return .statedGtVendorPitch }
            if local == vendorDefaultDays { return .statedEq }
            return .unknown
        }
        if statuteCapDays != nil { return .statuteOnly }
        return .unknown
    }
}

enum RetentionChipKind: String, CaseIterable, Sendable {
    case vendorDefault
    case localPolicy
    case statuteCap
    case unknown

    var chipLabel: String {
        switch self {
        case .vendorDefault: return "Vendor default"
        case .localPolicy: return "Local policy"
        case .statuteCap: return "Statute cap"
        case .unknown: return "Unknown"
        }
    }
}

struct RetentionDeltaAgency: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let displayName: String
    let regionLabel: String
    let vendorDefault: RetentionVendorDefault
    let localPolicyDays: Int?
    let localPolicySource: RetentionSourceChip?
    let statuteCapDays: Int?
    let statuteCapSource: RetentionSourceChip?
    let evidenceMode: RetentionEvidenceMode
    let configuredDays: Int?
    let sourceConflict: Bool
    let deltaLabel: RetentionDeltaLabel
    let sourceChips: [RetentionSourceChip]
    let notes: String?
    let incomplete: Bool
    let incompleteReason: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case regionLabel = "region_label"
        case vendorDefault = "vendor_default"
        case localPolicyDays = "local_policy_days"
        case localPolicySource = "local_policy_source"
        case statuteCapDays = "statute_cap_days"
        case statuteCapSource = "statute_cap_source"
        case evidenceMode = "evidence_mode"
        case configuredDays = "configured_days"
        case sourceConflict = "source_conflict"
        case deltaLabel = "delta_label"
        case sourceChips = "source_chips"
        case notes, incomplete
        case incompleteReason = "incomplete_reason"
    }

    init(
        id: String,
        displayName: String,
        regionLabel: String,
        vendorDefault: RetentionVendorDefault,
        localPolicyDays: Int? = nil,
        localPolicySource: RetentionSourceChip? = nil,
        statuteCapDays: Int? = nil,
        statuteCapSource: RetentionSourceChip? = nil,
        evidenceMode: RetentionEvidenceMode = .unknown,
        configuredDays: Int? = nil,
        sourceConflict: Bool = false,
        deltaLabel: RetentionDeltaLabel,
        sourceChips: [RetentionSourceChip] = [],
        notes: String? = nil,
        incomplete: Bool = false,
        incompleteReason: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.regionLabel = regionLabel
        self.vendorDefault = vendorDefault
        self.localPolicyDays = localPolicyDays
        self.localPolicySource = localPolicySource
        self.statuteCapDays = statuteCapDays
        self.statuteCapSource = statuteCapSource
        self.evidenceMode = evidenceMode
        self.configuredDays = configuredDays
        self.sourceConflict = sourceConflict
        self.deltaLabel = deltaLabel
        self.sourceChips = sourceChips
        self.notes = notes
        self.incomplete = incomplete
        self.incompleteReason = incompleteReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        regionLabel = try container.decode(String.self, forKey: .regionLabel)
        vendorDefault = try container.decode(RetentionVendorDefault.self, forKey: .vendorDefault)
        localPolicyDays = try container.decodeIfPresent(Int.self, forKey: .localPolicyDays)
        localPolicySource = try container.decodeIfPresent(RetentionSourceChip.self, forKey: .localPolicySource)
        statuteCapDays = try container.decodeIfPresent(Int.self, forKey: .statuteCapDays)
        statuteCapSource = try container.decodeIfPresent(RetentionSourceChip.self, forKey: .statuteCapSource)
        evidenceMode = try container.decodeIfPresent(RetentionEvidenceMode.self, forKey: .evidenceMode) ?? .unknown
        configuredDays = try container.decodeIfPresent(Int.self, forKey: .configuredDays)
        sourceConflict = try container.decodeIfPresent(Bool.self, forKey: .sourceConflict) ?? false
        deltaLabel = try container.decode(RetentionDeltaLabel.self, forKey: .deltaLabel)
        sourceChips = try container.decodeIfPresent([RetentionSourceChip].self, forKey: .sourceChips) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        incomplete = try container.decodeIfPresent(Bool.self, forKey: .incomplete) ?? false
        incompleteReason = try container.decodeIfPresent(String.self, forKey: .incompleteReason)
    }

    /// Chips that actually have a value in this snapshot — never invented.
    var presentChipKinds: [RetentionChipKind] {
        var kinds: [RetentionChipKind] = [.vendorDefault]
        if localPolicyDays != nil { kinds.append(.localPolicy) }
        if statuteCapDays != nil { kinds.append(.statuteCap) }
        if configuredDays == nil || evidenceMode == .unknown {
            kinds.append(.unknown)
        }
        return kinds
    }

    var derivedDeltaLabel: RetentionDeltaLabel {
        RetentionDeltaLabel.derived(
            localPolicyDays: localPolicyDays,
            statuteCapDays: statuteCapDays,
            vendorDefaultDays: vendorDefault.days,
            sourceConflict: sourceConflict
        )
    }

    func chipCaption(for kind: RetentionChipKind) -> String {
        switch kind {
        case .vendorDefault:
            return "\(kind.chipLabel) · \(vendorDefault.days)d"
        case .localPolicy:
            if let days = localPolicyDays {
                return "\(kind.chipLabel) · \(days)d"
            }
            return kind.chipLabel
        case .statuteCap:
            if let days = statuteCapDays {
                return "\(kind.chipLabel) · \(days)d"
            }
            return kind.chipLabel
        case .unknown:
            if configuredDays != nil {
                return "\(kind.chipLabel) · evidence"
            }
            return "\(kind.chipLabel) · configured"
        }
    }
}

/// Locked honesty copy for the retention-delta card.
enum RetentionDeltaCopy {
    static let samplesTitle = "Retention samples"
    static let samplesSubtitle = "Public policy quotes vs vendor pitch"

    static let caption =
        "Public policy quotes compared to a dated vendor pitch — not what any system is configured to today."

    static let bannerLineA = "These chips are dated public quotes, not live Flock settings"
    static let bannerLineB = "A statute cap is not an agency-stated policy, and neither is a configured setting"
    static let bannerLineC = "Vendor pages still mix 30-day and 7-day language — this card does not resolve that"

    static let bannerLines: [String] = [bannerLineA, bannerLineB, bannerLineC]

    /// Always-on incompleteness banner. Independent of `incomplete`.
    static var requiredBannerLines: [String] { bannerLines }

    static let emptyList =
        "No retention samples in this snapshot. Open a dated source, or request the agency’s public records later."

    static let unknownNextTap =
        "Configured days are unknown here. Open a dated source, or request public records later."

    static let notAffiliated = "Not affiliated with Flock Safety."

    static let asOfPrefix = "As of"

    static func incompleteDisclaimer(for agency: RetentionDeltaAgency) -> String? {
        guard agency.incomplete else { return nil }
        let reason = agency.incompleteReason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return reason.isEmpty ? nil : reason
    }

    static func honestyLine(for label: RetentionDeltaLabel, vendorDays: Int) -> String {
        switch label {
        case .statedGtVendorPitch:
            return "This agency’s published policy quote is longer than Flock’s \(vendorDays)-day recommended default pitch."
        case .statedEq:
            return "This agency’s published policy quote matches Flock’s \(vendorDays)-day recommended default pitch."
        case .statuteOnly:
            return "Only a statute cap is quoted here — no local policy number in this snapshot."
        case .unknown:
            return "Not enough public quotes in this snapshot to compare."
        case .conflict:
            return "Public sources for this agency disagree — no single retention number."
        }
    }

    static func listPlaceholder(totalAgencies: Int) -> String? {
        totalAgencies == 0 ? emptyList : nil
    }
}
