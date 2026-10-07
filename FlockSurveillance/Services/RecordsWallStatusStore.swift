import Foundation

@MainActor
@Observable
final class RecordsWallStatusStore {
    nonisolated static let resourceName = "RecordsWallStatus"

    private(set) var dataset: RecordsWallDataset?
    private(set) var loadError: String?
    private(set) var isLoaded = false
    private(set) var isLoading = false
    @ObservationIgnored
    private var loadWaiters: [CheckedContinuation<Void, Never>] = []

    func loadIfNeeded() async {
        guard !isLoaded else { return }
        await reload()
    }

    func reload(
        resourceName: String = RecordsWallStatusStore.resourceName,
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
                try RecordsWallStatusStore.loadDataset(from: resourceBundle, resourceName: name)
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

    func applyLoadedDataset(_ dataset: RecordsWallDataset) {
        self.dataset = dataset
        isLoaded = true
        isLoading = false
        loadError = nil
    }

    nonisolated static func loadDataset(
        from bundle: Bundle = .main,
        resourceName: String = RecordsWallStatusStore.resourceName
    ) throws -> RecordsWallDataset {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw RecordsWallStatusStoreError.missingResource
        }
        let data = try Data(contentsOf: url)
        return try loadDataset(from: data)
    }

    nonisolated static func loadDataset(from data: Data) throws -> RecordsWallDataset {
        try JSONDecoder().decode(RecordsWallDataset.self, from: data)
    }
}

enum RecordsWallStatusStoreError: LocalizedError {
    case missingResource

    var errorDescription: String? {
        switch self {
        case .missingResource:
            return "Records wall data is missing from the app bundle."
        }
    }
}
