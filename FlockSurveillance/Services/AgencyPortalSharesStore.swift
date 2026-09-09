import Foundation

@MainActor
@Observable
final class AgencyPortalSharesStore {
    static let resourceName = "AgencyPortalSharesBundle"
    static let shelbyCountySOID = "shelby-county-tn-so"

    private(set) var bundle: AgencyPortalSharesBundle?
    private(set) var loadError: String?
    private(set) var isLoaded = false
    private(set) var isLoading = false
    @ObservationIgnored
    private var loadWaiters: [CheckedContinuation<Void, Never>] = []

    func loadIfNeeded() async {
        guard !isLoaded else { return }
        await reload()
    }

    /// Force a reload. Decodes off the main actor. Keeps the previous
    /// `loadError` visible until this attempt resolves. Concurrent callers
    /// wait for the in-flight decode instead of returning immediately.
    func reload(
        resourceName: String = AgencyPortalSharesStore.resourceName,
        from resourceBundle: Bundle = .main
    ) async {
        if isLoading {
            await withCheckedContinuation { continuation in
                loadWaiters.append(continuation)
            }
            return
        }
        isLoading = true
        defer {
            isLoading = false
            let waiters = loadWaiters
            loadWaiters.removeAll()
            for waiter in waiters {
                waiter.resume()
            }
        }
        do {
            let name = resourceName
            let loaded = try await Task.detached(priority: .userInitiated) {
                try AgencyPortalSharesStore.loadBundle(from: resourceBundle, resourceName: name)
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
    func applyLoadedBundle(_ bundle: AgencyPortalSharesBundle) {
        self.bundle = bundle
        isLoaded = true
        isLoading = false
        loadError = nil
    }

    var agencies: [AgencyPortalShareAgency] {
        bundle?.agencies ?? []
    }

    var attribution: AgencyPortalSharesAttribution? {
        bundle?.attribution
    }

    func agency(id: String) -> AgencyPortalShareAgency? {
        agencies.first { $0.id == id }
    }

    /// Bundled Mid-South samples only — currently Shelby County TN SO.
    var midSouthSamples: [AgencyPortalShareAgency] {
        agencies.filter { $0.regionLabel.localizedCaseInsensitiveContains("mid-south") }
    }

    nonisolated static func loadBundle(
        from bundle: Bundle = .main,
        resourceName: String = AgencyPortalSharesStore.resourceName
    ) throws -> AgencyPortalSharesBundle {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw AgencyPortalSharesStoreError.missingResource
        }
        let data = try Data(contentsOf: url)
        return try loadBundle(from: data)
    }

    nonisolated static func loadBundle(from data: Data) throws -> AgencyPortalSharesBundle {
        try JSONDecoder().decode(AgencyPortalSharesBundle.self, from: data)
    }
}

enum AgencyPortalSharesStoreError: LocalizedError {
    case missingResource

    var errorDescription: String? {
        switch self {
        case .missingResource:
            return "Agency portal-shares data is missing from the app bundle."
        }
    }
}
