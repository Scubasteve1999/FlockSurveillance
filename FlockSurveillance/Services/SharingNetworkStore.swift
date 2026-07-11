import Foundation

@MainActor
@Observable
final class SharingNetworkStore {
    private(set) var bundle: SharingNetworkBundle?
    private(set) var loadError: String?
    private(set) var isLoaded = false

    func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        do {
            bundle = try Self.loadBundle()
            loadError = nil
        } catch {
            bundle = nil
            loadError = error.localizedDescription
        }
    }

    /// Test / preview helper.
    func applyLoadedBundle(_ bundle: SharingNetworkBundle) {
        self.bundle = bundle
        self.isLoaded = true
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

    func arcs(for hubId: String, limit: Int = 250) -> [SharingArc] {
        let all = partners(for: hubId).compactMap { partner -> SharingArc? in
            guard let link = partner.link(for: hubId) else { return nil }
            return SharingArc(partner: partner, direction: link.direction)
        }
        if all.count <= limit { return all }
        // Prefer a stable geographic sample so the map stays readable.
        let step = max(1, all.count / limit)
        var sampled: [SharingArc] = []
        sampled.reserveCapacity(limit)
        var index = 0
        while sampled.count < limit, index < all.count {
            sampled.append(all[index])
            index += step
        }
        return sampled
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
