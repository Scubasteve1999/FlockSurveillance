import Foundation

@MainActor
@Observable
final class RetentionDeltaStore {
    nonisolated static let resourceName = "RetentionDeltaBundle"
    nonisolated static let boulderPDID = "boulder-co-pd"
    nonisolated static let amarilloPDID = "amarillo-tx-pd"
    nonisolated static let lafayettePDID = "lafayette-co-pd"
    nonisolated static let tukwilaPDID = "tukwila-wa-pd"
    nonisolated static let greenBayPDID = "green-bay-wi-pd"

    private(set) var bundle: RetentionDeltaBundle?
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
        resourceName: String = RetentionDeltaStore.resourceName,
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
                try RetentionDeltaStore.loadBundle(from: resourceBundle, resourceName: name)
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
    func applyLoadedBundle(_ bundle: RetentionDeltaBundle) {
        self.bundle = bundle
        isLoaded = true
        isLoading = false
        loadError = nil
    }

    var agencies: [RetentionDeltaAgency] {
        bundle?.agencies ?? []
    }

    var attribution: RetentionDeltaAttribution? {
        bundle?.attribution
    }

    var vendorDefault: RetentionVendorDefault? {
        bundle?.vendorDefault
    }

    func agency(id: String) -> RetentionDeltaAgency? {
        agencies.first { $0.id == id }
    }

    nonisolated static func loadBundle(
        from bundle: Bundle = .main,
        resourceName: String = RetentionDeltaStore.resourceName
    ) throws -> RetentionDeltaBundle {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw RetentionDeltaStoreError.missingResource
        }
        let data = try Data(contentsOf: url)
        return try loadBundle(from: data)
    }

    nonisolated static func loadBundle(from data: Data) throws -> RetentionDeltaBundle {
        try JSONDecoder().decode(RetentionDeltaBundle.self, from: data)
    }
}

enum RetentionDeltaStoreError: LocalizedError {
    case missingResource

    var errorDescription: String? {
        switch self {
        case .missingResource:
            return "Retention-delta sample data is missing from the app bundle."
        }
    }
}
