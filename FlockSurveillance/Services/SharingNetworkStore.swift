import Foundation
import MapKit

@MainActor
@Observable
final class SharingNetworkStore {
    private(set) var bundle: SharingNetworkBundle?
    private(set) var loadError: String?
    private(set) var isLoaded = false
    private(set) var isLoading = false

    func loadIfNeeded() async {
        guard !isLoaded else { return }
        await reload()
    }

    /// Force a reload (e.g. after a failed first attempt). Decodes off the main actor.
    /// Keeps the previous `loadError` visible until this attempt resolves.
    func reload(
        resourceName: String = "SharingNetworkBundle",
        from resourceBundle: Bundle = .main
    ) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let name = resourceName
            let loaded = try await Task.detached(priority: .userInitiated) {
                try SharingNetworkStore.loadBundle(from: resourceBundle, resourceName: name)
            }.value
            bundle = loaded
            isLoaded = true
            loadError = nil
        } catch {
            bundle = nil
            isLoaded = false
            loadError = error.localizedDescription
        }
    }

    /// Test / preview helper.
    func applyLoadedBundle(_ bundle: SharingNetworkBundle) {
        self.bundle = bundle
        self.isLoaded = true
        self.isLoading = false
        self.loadError = nil
    }

    var hubs: [SharingHub] {
        bundle?.hubs ?? []
    }

    var attribution: SharingAttribution? {
        bundle?.attribution
    }

    func partners(for hubId: String, includeInactive: Bool = false) -> [SharingPartner] {
        guard let bundle else { return [] }
        return bundle.partners.filter { partner in
            guard let link = partner.link(for: hubId) else { return false }
            if !includeInactive, partner.inactive || link.inactive { return false }
            return true
        }
    }

    /// Full-list search for the Find partners sheet — uncapped source, capped results.
    /// Does not affect map Marker rendering (`maxRenderedPartners`).
    func matchingPartners(
        for hubId: String,
        query: String,
        limit: Int = 100
    ) -> [SharingPartner] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, limit > 0 else { return [] }
        let needle = trimmed.lowercased()
        return partners(for: hubId)
            .filter { partner in
                if partner.name.lowercased().contains(needle) { return true }
                if partner.state.lowercased().contains(needle) { return true }
                if let county = partner.inferredCountyName?.lowercased(), county.contains(needle) {
                    return true
                }
                if let place = partner.placeName?.lowercased(), place.contains(needle) {
                    return true
                }
                let entity = partner.entityType
                    .replacingOccurrences(of: "_", with: " ")
                    .lowercased()
                return entity.contains(needle)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .prefix(limit)
            .map { $0 }
    }

    /// Upper bound for map annotations (state, county, or agency pins) per view.
    ///
    /// Do not raise without an accessibility re-check. Illinois alone has 280
    /// Waunakee partners — pin counties there, not every agency.
    static let maxRenderedPartners = 250

    /// States at or under this many agencies skip the county step and pin agencies.
    static let directAgencyPinThreshold = 12

    /// Active partners grouped by state, pinned at state centroids.
    func stateGroups(for hubId: String) -> [SharingStateGroup] {
        Self.makeStateGroups(partners: partners(for: hubId), hubId: hubId)
    }

    static func makeStateGroups(partners: [SharingPartner], hubId: String) -> [SharingStateGroup] {
        var buckets: [String: [SharingPartner]] = [:]
        for partner in partners {
            let key = partner.state.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let state = key.isEmpty ? "UNKNOWN" : key
            buckets[state, default: []].append(partner)
        }
        return buckets.map { state, members in
            let sorted = members.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            var hubOut = 0
            var hubIn = 0
            var bidirectional = 0
            for partner in sorted {
                switch partner.link(for: hubId)?.direction {
                case .hubOut: hubOut += 1
                case .hubIn: hubIn += 1
                case .bidirectional: bidirectional += 1
                case nil: break
                }
            }
            let point = SharingStateGeography.coordinate(for: state)
            return SharingStateGroup(
                state: state,
                name: SharingStateGeography.displayName(for: state),
                latitude: point.latitude,
                longitude: point.longitude,
                partners: sorted,
                hubOut: hubOut,
                hubIn: hubIn,
                bidirectional: bidirectional
            )
        }
        .sorted { lhs, rhs in
            if lhs.partnerCount != rhs.partnerCount {
                return lhs.partnerCount > rhs.partnerCount
            }
            return lhs.state < rhs.state
        }
    }

    /// Geocoded partners in `state` grouped by inferred county. `none` stays out.
    func countyGroups(for hubId: String, state: String) -> [SharingCountyGroup] {
        Self.makeCountyGroups(partners: partners(for: hubId, state: state), hubId: hubId)
    }

    func ungroupedPartners(for hubId: String, state: String) -> [SharingPartner] {
        partners(for: hubId, state: state).filter { $0.inferredCountyName == nil || !$0.hasInferredLocation }
    }

    func partners(for hubId: String, state: String, includeInactive: Bool = false) -> [SharingPartner] {
        let wanted = state.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return partners(for: hubId, includeInactive: includeInactive).filter {
            $0.state.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == wanted
        }
    }

    static func makeCountyGroups(partners: [SharingPartner], hubId: String) -> [SharingCountyGroup] {
        var buckets: [String: [SharingPartner]] = [:]
        for partner in partners {
            guard partner.hasInferredLocation, let county = partner.inferredCountyName else { continue }
            buckets[county, default: []].append(partner)
        }
        return buckets.map { county, members in
            let sorted = members.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            var hubOut = 0
            var hubIn = 0
            var bidirectional = 0
            for partner in sorted {
                switch partner.link(for: hubId)?.direction {
                case .hubOut: hubOut += 1
                case .hubIn: hubIn += 1
                case .bidirectional: bidirectional += 1
                case nil: break
                }
            }
            let latitude = sorted.map(\.latitude).reduce(0, +) / Double(sorted.count)
            let longitude = sorted.map(\.longitude).reduce(0, +) / Double(sorted.count)
            return SharingCountyGroup(
                state: sorted[0].state.uppercased(),
                county: county,
                latitude: latitude,
                longitude: longitude,
                partners: sorted,
                hubOut: hubOut,
                hubIn: hubIn,
                bidirectional: bidirectional
            )
        }
        .sorted { lhs, rhs in
            if lhs.partnerCount != rhs.partnerCount {
                return lhs.partnerCount > rhs.partnerCount
            }
            return lhs.county.localizedCaseInsensitiveCompare(rhs.county) == .orderedAscending
        }
    }

    static func shouldPinAgenciesDirectly(partnerCount: Int) -> Bool {
        partnerCount <= directAgencyPinThreshold
    }

    /// Prefer partners inside `preferring` when capping arcs, then stride-sample the rest.
    func arcs(
        for hubId: String,
        limit: Int = maxRenderedPartners,
        preferring region: MKCoordinateRegion? = nil
    ) -> [SharingArc] {
        let all = reachPoints(for: hubId)
        if all.count <= limit { return all }

        guard let region else {
            return Self.strideSample(all, limit: limit)
        }

        var inView: [SharingArc] = []
        var outOfView: [SharingArc] = []
        inView.reserveCapacity(min(all.count, limit))
        outOfView.reserveCapacity(all.count)
        for arc in all {
            if GeoHelpers.region(region, contains: arc.partner.coordinate) {
                inView.append(arc)
            } else {
                outOfView.append(arc)
            }
        }

        if inView.count >= limit {
            return Self.strideSample(inView, limit: limit)
        }

        var sampled = inView
        let remaining = limit - sampled.count
        sampled.append(contentsOf: Self.strideSample(outOfView, limit: remaining))
        return sampled
    }

    /// Every active partner for a hub (reach points), uncapped.
    func reachPoints(for hubId: String) -> [SharingArc] {
        partners(for: hubId).compactMap { partner -> SharingArc? in
            guard let link = partner.link(for: hubId) else { return nil }
            return SharingArc(partner: partner, direction: link.direction)
        }
    }

    static func regionFitting(hub: SharingHub, partners: [SharingPartner]) -> MKCoordinateRegion {
        regionFitting(hub: hub, stateGroups: makeStateGroups(partners: partners, hubId: hub.id))
    }

    static func regionFitting(hub: SharingHub, stateGroups: [SharingStateGroup]) -> MKCoordinateRegion {
        var minLat = hub.latitude
        var maxLat = hub.latitude
        var minLon = hub.longitude
        var maxLon = hub.longitude
        for group in stateGroups {
            minLat = min(minLat, group.latitude)
            maxLat = max(maxLat, group.latitude)
            minLon = min(minLon, group.longitude)
            maxLon = max(maxLon, group.longitude)
        }
        let latPad = max((maxLat - minLat) * 0.18, 0.6)
        let lonPad = max((maxLon - minLon) * 0.18, 0.6)
        let latDelta = max((maxLat - minLat) + latPad * 2, 2.5)
        let lonDelta = max((maxLon - minLon) + lonPad * 2, 2.5)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: min(latDelta, 45),
                longitudeDelta: min(lonDelta, 60)
            )
        )
    }

    static func regionFitting(hub: SharingHub, countyGroups: [SharingCountyGroup]) -> MKCoordinateRegion {
        var points = countyGroups.map(\.coordinate)
        if points.isEmpty {
            points.append(hub.coordinate)
        }
        return regionFitting(coordinates: points, minimumSpan: 0.8)
    }

    static func regionFitting(partners: [SharingPartner], fallback: CLLocationCoordinate2D) -> MKCoordinateRegion {
        let points = partners.filter(\.hasInferredLocation).map(\.coordinate)
        if points.isEmpty {
            return MKCoordinateRegion(
                center: fallback,
                span: MKCoordinateSpan(latitudeDelta: 1.2, longitudeDelta: 1.2)
            )
        }
        return regionFitting(coordinates: points, minimumSpan: 0.35)
    }

    static func regionFitting(
        coordinates: [CLLocationCoordinate2D],
        minimumSpan: Double
    ) -> MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.8, longitude: -98.5),
                span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 50)
            )
        }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for point in coordinates.dropFirst() {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude)
            maxLon = max(maxLon, point.longitude)
        }
        let latPad = max((maxLat - minLat) * 0.22, minimumSpan * 0.25)
        let lonPad = max((maxLon - minLon) * 0.22, minimumSpan * 0.25)
        let latDelta = max((maxLat - minLat) + latPad * 2, minimumSpan)
        let lonDelta = max((maxLon - minLon) + lonPad * 2, minimumSpan)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: min(latDelta, 20),
                longitudeDelta: min(lonDelta, 20)
            )
        )
    }

    nonisolated static func loadBundle(
        from bundle: Bundle = .main,
        resourceName: String = "SharingNetworkBundle"
    ) throws -> SharingNetworkBundle {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw SharingNetworkStoreError.missingResource
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SharingNetworkBundle.self, from: data)
    }

    nonisolated static func loadBundle(from data: Data) throws -> SharingNetworkBundle {
        try JSONDecoder().decode(SharingNetworkBundle.self, from: data)
    }

    private static func strideSample(_ arcs: [SharingArc], limit: Int) -> [SharingArc] {
        guard limit > 0 else { return [] }
        if arcs.count <= limit { return arcs }
        let step = max(1, arcs.count / limit)
        var sampled: [SharingArc] = []
        sampled.reserveCapacity(limit)
        var index = 0
        while sampled.count < limit, index < arcs.count {
            sampled.append(arcs[index])
            index += step
        }
        return sampled
    }
}

enum SharingNetworkStoreError: LocalizedError {
    case missingResource

    var errorDescription: String? {
        switch self {
        case .missingResource:
            return "Sharing network data is missing from the app bundle."
        }
    }
}
