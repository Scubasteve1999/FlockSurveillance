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

/// One FOIA-accurate map node: agencies in a state, pinned at that state's centroid.
struct SharingStateGroup: Identifiable, Hashable {
    var id: String { state }

    let state: String
    let name: String
    let latitude: Double
    let longitude: Double
    let partners: [SharingPartner]
    let hubOut: Int
    let hubIn: Int
    let bidirectional: Int

    var partnerCount: Int { partners.count }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var markerTitle: String {
        "\(state) · \(partnerCount)"
    }

    /// Tint the state pin by the most common link direction.
    var dominantDirection: SharingDirection {
        if bidirectional >= hubOut, bidirectional >= hubIn, bidirectional > 0 {
            return .bidirectional
        }
        if hubIn > hubOut { return .hubIn }
        return .hubOut
    }
}

/// Honest state centroids (same table as the bundle builder). Not agency addresses.
enum SharingStateGeography {
    struct Entry: Sendable {
        let name: String
        let latitude: Double
        let longitude: Double
    }

    static func coordinate(for state: String) -> CLLocationCoordinate2D {
        let entry = table[state.uppercased()] ?? unknown
        return CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude)
    }

    static func displayName(for state: String) -> String {
        table[state.uppercased()]?.name ?? state
    }

    private static let unknown = Entry(name: "Unknown", latitude: 39.8283, longitude: -98.5795)

    static let table: [String: Entry] = [
        "AL": Entry(name: "Alabama", latitude: 32.806671, longitude: -86.791130),
        "AK": Entry(name: "Alaska", latitude: 61.370716, longitude: -152.404419),
        "AZ": Entry(name: "Arizona", latitude: 33.729759, longitude: -111.431221),
        "AR": Entry(name: "Arkansas", latitude: 34.969704, longitude: -92.373123),
        "CA": Entry(name: "California", latitude: 36.116203, longitude: -119.681564),
        "CO": Entry(name: "Colorado", latitude: 39.059811, longitude: -105.311104),
        "CT": Entry(name: "Connecticut", latitude: 41.597782, longitude: -72.755371),
        "DE": Entry(name: "Delaware", latitude: 39.318523, longitude: -75.507141),
        "DC": Entry(name: "District of Columbia", latitude: 38.897438, longitude: -77.026817),
        "FL": Entry(name: "Florida", latitude: 27.766279, longitude: -81.686783),
        "GA": Entry(name: "Georgia", latitude: 33.040619, longitude: -83.643074),
        "HI": Entry(name: "Hawaii", latitude: 21.094318, longitude: -157.498337),
        "ID": Entry(name: "Idaho", latitude: 44.240459, longitude: -114.478828),
        "IL": Entry(name: "Illinois", latitude: 40.349457, longitude: -88.986137),
        "IN": Entry(name: "Indiana", latitude: 39.849426, longitude: -86.258278),
        "IA": Entry(name: "Iowa", latitude: 42.011539, longitude: -93.210526),
        "KS": Entry(name: "Kansas", latitude: 38.526600, longitude: -96.726486),
        "KY": Entry(name: "Kentucky", latitude: 37.668140, longitude: -84.670067),
        "LA": Entry(name: "Louisiana", latitude: 31.169546, longitude: -91.867805),
        "ME": Entry(name: "Maine", latitude: 44.693947, longitude: -69.381927),
        "MD": Entry(name: "Maryland", latitude: 39.063946, longitude: -76.802101),
        "MA": Entry(name: "Massachusetts", latitude: 42.230171, longitude: -71.530106),
        "MI": Entry(name: "Michigan", latitude: 43.326618, longitude: -84.536095),
        "MN": Entry(name: "Minnesota", latitude: 45.694454, longitude: -93.900192),
        "MS": Entry(name: "Mississippi", latitude: 32.741646, longitude: -89.678696),
        "MO": Entry(name: "Missouri", latitude: 38.456085, longitude: -92.288368),
        "MT": Entry(name: "Montana", latitude: 46.921925, longitude: -110.454353),
        "NE": Entry(name: "Nebraska", latitude: 41.125370, longitude: -98.268082),
        "NV": Entry(name: "Nevada", latitude: 38.313515, longitude: -117.055374),
        "NH": Entry(name: "New Hampshire", latitude: 43.452492, longitude: -71.563896),
        "NJ": Entry(name: "New Jersey", latitude: 40.298904, longitude: -74.521011),
        "NM": Entry(name: "New Mexico", latitude: 34.840515, longitude: -106.248482),
        "NY": Entry(name: "New York", latitude: 42.165726, longitude: -74.948051),
        "NC": Entry(name: "North Carolina", latitude: 35.630066, longitude: -79.806419),
        "ND": Entry(name: "North Dakota", latitude: 47.528912, longitude: -99.784012),
        "OH": Entry(name: "Ohio", latitude: 40.388783, longitude: -82.764915),
        "OK": Entry(name: "Oklahoma", latitude: 35.565342, longitude: -96.928917),
        "OR": Entry(name: "Oregon", latitude: 44.572021, longitude: -122.070938),
        "PA": Entry(name: "Pennsylvania", latitude: 40.590752, longitude: -77.209755),
        "RI": Entry(name: "Rhode Island", latitude: 41.680893, longitude: -71.511780),
        "SC": Entry(name: "South Carolina", latitude: 33.856892, longitude: -80.945007),
        "SD": Entry(name: "South Dakota", latitude: 44.299782, longitude: -99.438828),
        "TN": Entry(name: "Tennessee", latitude: 35.747845, longitude: -86.692345),
        "TX": Entry(name: "Texas", latitude: 31.054487, longitude: -97.563461),
        "UT": Entry(name: "Utah", latitude: 40.150032, longitude: -111.862434),
        "VT": Entry(name: "Vermont", latitude: 44.045876, longitude: -72.710686),
        "VA": Entry(name: "Virginia", latitude: 37.769337, longitude: -78.169968),
        "WA": Entry(name: "Washington", latitude: 47.400902, longitude: -121.490494),
        "WV": Entry(name: "West Virginia", latitude: 38.491226, longitude: -80.954453),
        "WI": Entry(name: "Wisconsin", latitude: 44.268543, longitude: -89.616508),
        "WY": Entry(name: "Wyoming", latitude: 42.755966, longitude: -107.302490)
    ]
}
