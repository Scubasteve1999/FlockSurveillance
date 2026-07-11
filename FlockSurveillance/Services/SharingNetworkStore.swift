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

    /// Upper bound for partners rendered as map annotations (Markers + polylines) per hub.
    ///
    /// This isn't just a polyline-draw-performance knob: SharingNetworkView renders one
    /// Marker per arc from this same capped list, and an uncapped Marker count (a hub can
    /// have 1,000+ partners) overwhelms the accessibility tree, making the sheet's own
    /// controls (close button, hub chips) unreachable to VoiceOver/UI automation. Raising
    /// this risks silently reintroducing that bug — re-verify accessibility before raising it.
    static let maxRenderedPartners = 250

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
        var minLat = hub.latitude
        var maxLat = hub.latitude
        var minLon = hub.longitude
        var maxLon = hub.longitude
        for partner in partners {
            minLat = min(minLat, partner.latitude)
            maxLat = max(maxLat, partner.latitude)
            minLon = min(minLon, partner.longitude)
            maxLon = max(maxLon, partner.longitude)
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
