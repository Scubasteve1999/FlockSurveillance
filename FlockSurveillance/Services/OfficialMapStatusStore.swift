import Foundation

@MainActor
@Observable
final class OfficialMapStatusStore {
    nonisolated static let resourceName = "OfficialMapStatus"

    private(set) var dataset: OfficialMapDataset?
    private(set) var loadError: String?
    private(set) var isLoaded = false
    private(set) var isLoading = false
    @ObservationIgnored
    private var loadWaiters: [CheckedContinuation<Void, Never>] = []

    func loadIfNeeded() async {
        guard !isLoaded else { return }
        await reload()
    }

    /// Force a reload. Decodes off the main actor. Concurrent callers wait
    /// for the in-flight decode instead of returning immediately.
    func reload(
        resourceName: String = OfficialMapStatusStore.resourceName,
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
                try OfficialMapStatusStore.loadDataset(from: resourceBundle, resourceName: name)
            }.value
            dataset = loaded
            isLoaded = true
            loadError = nil
        } catch {
            dataset = nil
            isLoaded = false
            loadError = error.localizedDescription
        }
    }

    func applyLoadedDataset(_ dataset: OfficialMapDataset) {
        self.dataset = dataset
        isLoaded = true
        isLoading = false
        loadError = nil
    }

    nonisolated static func loadDataset(
        from bundle: Bundle = .main,
        resourceName: String = OfficialMapStatusStore.resourceName
    ) throws -> OfficialMapDataset {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw OfficialMapStatusStoreError.missingResource
        }
        let data = try Data(contentsOf: url)
        return try loadDataset(from: data)
    }

    nonisolated static func loadDataset(from data: Data) throws -> OfficialMapDataset {
        try JSONDecoder().decode(OfficialMapDataset.self, from: data)
    }
}

enum OfficialMapStatusStoreError: LocalizedError {
    case missingResource

    var errorDescription: String? {
        switch self {
        case .missingResource:
            return "Official camera-map status data is missing from the app bundle."
        }
    }
}
