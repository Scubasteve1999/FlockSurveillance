import CoreLocation
import Foundation

enum SharingDirection: String, Codable, CaseIterable, Sendable {
    case hubOut
    case hubIn
    case bidirectional

    var label: String {
        switch self {
        case .hubOut: return "Hub shares with partner"
        case .hubIn: return "Partner shares with hub"
        case .bidirectional: return "Bidirectional"
        }
    }
}

struct SharingNetworkBundle: Codable, Sendable {
    let schemaVersion: String
    let generatedAt: String
    let sourceGeneratedAt: String?
    let attribution: SharingAttribution
    let sources: [SharingSource]
    let hubs: [SharingHub]
    let partners: [SharingPartner]
    let stats: SharingStats
}

struct SharingAttribution: Codable, Sendable {
    let title: String
    let url: String
    let note: String
}

struct SharingSource: Codable, Sendable, Identifiable {
    let key: String
    let label: String
    let releaseDate: String?
    let shape: String?
    let rowCount: Int?

    var id: String { key }
}

struct SharingHub: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let shortName: String
    let latitude: Double
    let longitude: Double
    let releaseDate: String?
    let sourceRowCount: Int
    let partnerCount: Int

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct SharingHubLink: Codable, Sendable, Hashable {
    let hubId: String
    let direction: SharingDirection
    let inactive: Bool
}

struct SharingPartner: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let state: String
    let entityType: String
    let latitude: Double
    let longitude: Double
    let inactive: Bool
    let membership: String
    let hubLinks: [SharingHubLink]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func link(for hubId: String) -> SharingHubLink? {
        hubLinks.first { $0.hubId == hubId }
    }
}

struct SharingStats: Codable, Sendable {
    let partnerCount: Int
    let hubCount: Int
}

struct SharingArc: Identifiable, Hashable {
    let partner: SharingPartner
    let direction: SharingDirection

    var id: String { partner.id }
}
