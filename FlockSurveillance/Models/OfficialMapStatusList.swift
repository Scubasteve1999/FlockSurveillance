import Foundation

/// One status section of the official camera-map list.
/// Order follows `OfficialMapStatus.allCases`. Empty statuses are omitted.
struct OfficialMapStatusGroup: Equatable, Sendable, Identifiable {
    let status: OfficialMapStatus
    let records: [OfficialMapRecord]

    var id: String { status.rawValue }

    /// Chip title when every row shares one. Nil when a date changes the title,
    /// so the section header does not invent wording. `refused_upheld` gets its own
    /// header so it doesn't repeat the `refused` header.
    var title: String? {
        if status == .refusedUpheld { return OfficialMapStatusCopy.refusedUpheldGroupTitle }
        let titles = Set(records.map { OfficialMapStatusCopy.chip(for: $0).title })
        guard titles.count == 1 else { return nil }
        return titles.first
    }
}

/// Read-only grouping of the bundled official-map dataset.
struct OfficialMapStatusListModel: Equatable, Sendable {
    let banner: String
    let groups: [OfficialMapStatusGroup]

    var records: [OfficialMapRecord] {
        groups.flatMap(\.records)
    }

    init(dataset: OfficialMapDataset) {
        banner = OfficialMapStatusCopy.incompletenessBanner(
            agencyCount: dataset.records.count,
            datasetAsOf: dataset.datasetAsOf
        )
        groups = Self.groups(from: dataset.records)
    }

    static func rowTitle(for record: OfficialMapRecord) -> String {
        OfficialMapStatusCopy.chip(for: record).title
    }

    /// Row and detail title. Never a bare role word like "police" or "county".
    static func agencyTitle(for record: OfficialMapRecord) -> String {
        record.displayName
    }

    static func placeLine(for record: OfficialMapRecord) -> String {
        record.placeLine
    }

    static func groups(from records: [OfficialMapRecord]) -> [OfficialMapStatusGroup] {
        let ordered = records.sorted(by: isBefore(_:_:))
        return OfficialMapStatus.allCases.compactMap { status in
            let rows = ordered.filter { $0.status == status }
            guard !rows.isEmpty else { return nil }
            return OfficialMapStatusGroup(status: status, records: rows)
        }
    }

    static func isBefore(_ lhs: OfficialMapRecord, _ rhs: OfficialMapRecord) -> Bool {
        let state = lhs.state.localizedStandardCompare(rhs.state)
        if state != .orderedSame { return state == .orderedAscending }
        let place = lhs.jurisdiction.localizedStandardCompare(rhs.jurisdiction)
        if place != .orderedSame { return place == .orderedAscending }
        return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
    }
}
