import Foundation

enum RecordsWallGroupKind: String, Sendable, CaseIterable {
    case portal
    case recordsRequests
    case challenged
    case unchecked

    var title: String {
        switch self {
        case .portal: return "Portal listed"
        case .recordsRequests: return "Records requests"
        case .challenged: return "Challenged / withheld"
        case .unchecked: return "Not checked yet"
        }
    }
}

struct RecordsWallGroup: Identifiable, Equatable, Sendable {
    let kind: RecordsWallGroupKind
    let records: [RecordsWallRecord]
    var id: String { kind.rawValue }
    var title: String { kind.title }
}

struct RecordsWallListModel: Equatable, Sendable {
    let banner: String
    let groups: [RecordsWallGroup]

    init(dataset: RecordsWallDataset) {
        banner = RecordsWallStatusCopy.incompletenessBanner(
            agencyCount: dataset.records.count,
            datasetAsOf: dataset.datasetAsOf
        )
        let sorted = dataset.records.sorted(by: Self.order)
        groups = RecordsWallGroupKind.allCases.compactMap { kind in
            let members = sorted.filter { Self.kind(for: $0) == kind }
            return members.isEmpty ? nil : RecordsWallGroup(kind: kind, records: members)
        }
    }

    static func kind(for record: RecordsWallRecord) -> RecordsWallGroupKind {
        if record.foiaStatus == .foiaDenied || record.foiaStatus == .foiaChallengedAG
            || record.searchesPublic == .searchesWithheld {
            return .challenged
        }
        if record.portalStatus == .portalLive || record.portalStatus == .portalClaimed {
            return .portal
        }
        switch record.foiaStatus {
        case .foiaFree, .foiaQuoted, .foiaPaid, .foiaPending: return .recordsRequests
        default: return .unchecked
        }
    }

    private static func order(_ lhs: RecordsWallRecord, _ rhs: RecordsWallRecord) -> Bool {
        if lhs.state != rhs.state { return lhs.state < rhs.state }
        let place = lhs.jurisdiction.localizedStandardCompare(rhs.jurisdiction)
        if place != .orderedSame { return place == .orderedAscending }
        return lhs.id < rhs.id
    }
}
