import CoreLocation
import Foundation

/// Published match window from the Olive Branch entrance reconstruction.
/// Do not recompute from live Overpass and overwrite the bundled table.
enum EntranceMatchQuality: String, Codable, Sendable, CaseIterable {
    case match
    case nearMiss = "near-miss"
    case noPin = "no-pin"

    static let matchMaxMeters: CLLocationDistance = 150
    static let nearMissMaxMeters: CLLocationDistance = 250

    var label: String {
        switch self {
        case .match: return "Match"
        case .nearMiss: return "Near-miss"
        case .noPin: return "No pin"
        }
    }

    var windowLabel: String {
        switch self {
        case .match: return "≤150 m"
        case .nearMiss: return "150–250 m"
        case .noPin: return ">250 m"
        }
    }

    /// Classify a published distance. Nil (no nearest pin) is a gap.
    static func classify(distanceMeters: CLLocationDistance?) -> EntranceMatchQuality {
        guard let distanceMeters else { return .noPin }
        if distanceMeters <= matchMaxMeters { return .match }
        if distanceMeters <= nearMissMaxMeters { return .nearMiss }
        return .noPin
    }
}

enum EntranceCardinal: String, Codable, Sendable, CaseIterable {
    case north
    case west
    case south
    case east

    var label: String {
        rawValue.capitalized
    }
}

enum EntranceLocationClass: String, Codable, Sendable, CaseIterable {
    case cityLimitEntrance = "city-limit entrance"
    case inside

    var label: String {
        switch self {
        case .cityLimitEntrance: return "City-limit entrance"
        case .inside: return "Inside"
        }
    }
}

enum OliveBranchPinVendor: String, Codable, Sendable, CaseIterable {
    case flock = "Flock"
    case motorola = "Motorola"
}

struct OliveBranchEntranceSource: Codable, Sendable, Hashable, Identifiable {
    let title: String
    let url: String

    var id: String { url }
}

/// One named-road row at a city-limit crossing. W3 and W4 share `uniqueSiteId`.
struct OliveBranchEntranceSite: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let uniqueSiteId: String
    let road: String
    let cardinal: EntranceCardinal
    let edge: String
    let latitude: Double
    let longitude: Double
    let nearestOsmNode: String?
    let distanceMeters: CLLocationDistance?
    let quality: EntranceMatchQuality
    let includeInForced24: Bool
    let notes: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayRoad: String {
        let trimmed = road.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? id : trimmed
    }

    var isCoincidentPairMember: Bool {
        uniqueSiteId != id
    }

    var nearestOsmURL: URL? {
        guard let nearestOsmNode, !nearestOsmNode.isEmpty else { return nil }
        return URL(string: "https://www.openstreetmap.org/node/\(nearestOsmNode)")
    }
}

/// One crowdsourced OSM / DeFlock pin classified against the curated crossings.
struct OliveBranchEntrancePin: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let latitude: Double
    let longitude: Double
    let vendor: OliveBranchPinVendor
    let nearestRoad: String
    let locationClass: EntranceLocationClass
    let bestEntranceId: String
    let distanceMeters: CLLocationDistance
    let notes: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayRoad: String? {
        let trimmed = nearestRoad.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var isLeftover: Bool {
        locationClass == .inside
    }

    var osmURL: URL? {
        URL(string: "https://www.openstreetmap.org/node/\(id)")
    }
}

/// Coincident road-rows collapsed to one physical crossing (W3+W4).
/// `rows` is never empty — `init` fails and `makeUniqueSites` drops empty groups.
struct OliveBranchUniqueSite: Identifiable, Hashable, Sendable {
    let uniqueSiteId: String
    let rows: [OliveBranchEntranceSite]
    let representative: OliveBranchEntranceSite

    var id: String { uniqueSiteId }

    init?(uniqueSiteId: String, rows: [OliveBranchEntranceSite]) {
        guard let first = rows.first else { return nil }
        self.uniqueSiteId = uniqueSiteId
        self.rows = rows
        self.representative = first
    }

    func isBestEntrance(for pin: OliveBranchEntrancePin) -> Bool {
        pin.bestEntranceId == uniqueSiteId || rows.contains { $0.id == pin.bestEntranceId }
    }

    var coordinate: CLLocationCoordinate2D {
        representative.coordinate
    }

    var quality: EntranceMatchQuality {
        if rows.contains(where: { $0.quality == .match }) { return .match }
        if rows.contains(where: { $0.quality == .nearMiss }) { return .nearMiss }
        return .noPin
    }

    var isCoincident: Bool { rows.count > 1 }

    var isGap: Bool { quality == .noPin }

    var includeInForced24: Bool {
        rows.contains(where: \.includeInForced24)
    }

    var displayRoad: String {
        let names = rows.map(\.displayRoad)
        if names.count > 1 {
            return names.joined(separator: " / ")
        }
        return representative.displayRoad
    }

    var edge: String { representative.edge }

    var cardinal: EntranceCardinal { representative.cardinal }

    var nearestOsmNode: String? { representative.nearestOsmNode }

    var distanceMeters: CLLocationDistance? {
        rows.compactMap(\.distanceMeters).min()
    }

    var notes: String { representative.notes }
}

struct OliveBranchEntranceSummary: Equatable, Sendable {
    let roadRowCount: Int
    let uniqueSiteCount: Int
    let matchCount: Int
    let nearMissCount: Int
    let gapCount: Int
    let sitesWithPinWithin250: Int
    let pinCount: Int
    let entrancePinCount: Int
    let leftoverPinCount: Int
}

struct OliveBranchEntranceBundle: Codable, Sendable {
    let version: Int
    let updated: String
    let attribution: String
    let sources: [OliveBranchEntranceSource]
    let sites: [OliveBranchEntranceSite]
    let pins: [OliveBranchEntrancePin]
}
