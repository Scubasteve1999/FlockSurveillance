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
                let entity = partner.entityType
                    .replacingOccurrences(of: "_", with: " ")
                    .lowercased()
                return entity.contains(needle)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .prefix(limit)
            .map { $0 }
    }

    /// Upper bound for map annotations (state pins + spokes) per hub.
    ///
    /// The state map is ~41 markers, well under this. Keep the cap so a future
    /// partner-pin path cannot reintroduce the VoiceOver hang (1,000+ Markers).
    /// Do not raise without an accessibility re-check.
    static let maxRenderedPartners = 250

    /// Active partners grouped by state, pinned at honest state centroids.
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
