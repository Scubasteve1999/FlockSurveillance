import Foundation
import MapKit
import SwiftData

@MainActor
@Observable
final class CameraRepository {
    private(set) var cameras: [ALPRCamera] = []
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var lastRegion: MKCoordinateRegion?
    private(set) var lastSuccessfulFetchAt: Date?
    private(set) var isServingStale = false

    private let client: OverpassClient
    private var modelContext: ModelContext?
    private var debounceTask: Task<Void, Never>?
    private var fetchGeneration = 0

    private let maxCachedCameras = 8_000
    private let maxAge: TimeInterval = 14 * 24 * 60 * 60

    init(client: OverpassClient = .shared) {
        self.client = client
    }

    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCached()
        lastSuccessfulFetchAt = cameras.map(\.fetchedAt).max()
    }

    func loadCached() {
        guard let modelContext else { return }
        // Sort in memory to avoid Swift 6 KeyPath<ALPRCamera, Date>: Sendable diagnostics
        // from SortDescriptor(\.fetchedAt).
        let fetched = (try? modelContext.fetch(FetchDescriptor<ALPRCamera>())) ?? []
        cameras = fetched.sorted { $0.fetchedAt > $1.fetchedAt }
    }

    func scheduleFetch(for region: MKCoordinateRegion, delayNanoseconds: UInt64 = 450_000_000) {
        lastRegion = region
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard let self, !Task.isCancelled else { return }
            await self.fetch(for: region)
        }
    }

    func fetch(for region: MKCoordinateRegion) async {
        fetchGeneration += 1
        let generation = fetchGeneration
        isLoading = true
        lastError = nil

        do {
            let remote = try await client.fetchCameras(in: region)
            guard generation == fetchGeneration else { return }
            upsert(remote.map { $0.makeModel() })
            pruneCache()
            loadCached()
            lastSuccessfulFetchAt = .now
            isServingStale = false
            WidgetBridge.writeNearbySnapshot(from: cameras)
        } catch is CancellationError {
            // ignore
        } catch {
            if generation == fetchGeneration {
                lastError = error.localizedDescription
                isServingStale = !cameras.isEmpty
                if cameras.isEmpty {
                    loadCached()
                    isServingStale = !cameras.isEmpty
                }
            }
        }

        if generation == fetchGeneration {
            isLoading = false
        }
    }

    func clearCache() {
        guard let modelContext else {
            cameras = []
            return
        }
        for camera in cameras {
            modelContext.delete(camera)
        }
        try? modelContext.save()
        cameras = []
        lastSuccessfulFetchAt = nil
        isServingStale = false
        WidgetBridge.writeNearbySnapshot(from: [])
    }

    func refreshWidgetSnapshot() {
        WidgetBridge.writeNearbySnapshot(from: cameras)
    }

    func filtered(_ filter: CameraFilter) -> [ALPRCamera] {
        switch filter {
        case .all: return cameras
        case .flockOnly: return cameras.filter(\.isFlock)
        }
    }

    func cameras(in region: MKCoordinateRegion, filter: CameraFilter = .all) -> [ALPRCamera] {
        GeoHelpers.cameras(in: region, from: cameras, filter: filter)
    }

    func cameras(near coordinate: CLLocationCoordinate2D, radiusMeters: CLLocationDistance) -> [ALPRCamera] {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return cameras
            .map { ($0, $0.location.distance(from: origin)) }
            .filter { $0.1 <= radiusMeters }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    func nearest(to coordinate: CLLocationCoordinate2D, filter: CameraFilter) -> (camera: ALPRCamera, meters: CLLocationDistance)? {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return filtered(filter)
            .map { ($0, $0.location.distance(from: origin)) }
            .min { $0.1 < $1.1 }
            .map { (camera: $0.0, meters: $0.1) }
    }

    func clusters(for filter: CameraFilter, in region: MKCoordinateRegion) -> [CameraCluster] {
        GeoHelpers.clusters(for: filter, in: region, from: cameras)
    }

    var freshnessLabel: String? {
        let base = GeoHelpers.relativeFreshness(from: lastSuccessfulFetchAt)
        guard let base else { return nil }
        return isServingStale ? "\(base) · cached" : base
    }

    private func upsert(_ remote: [ALPRCamera]) {
        guard let modelContext else {
            cameras = remote
            return
        }

        // Index existing rows in memory instead of #Predicate KeyPaths (not Sendable in Swift 6).
        let existing = (try? modelContext.fetch(FetchDescriptor<ALPRCamera>())) ?? []
        var byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for camera in remote {
            if let current = byID[camera.id] {
                current.latitude = camera.latitude
                current.longitude = camera.longitude
                current.manufacturer = camera.manufacturer
                current.operatorName = camera.operatorName
                current.direction = camera.direction
                current.cameraName = camera.cameraName
                current.tagsJSON = camera.tagsJSON
                current.fetchedAt = camera.fetchedAt
            } else {
                modelContext.insert(camera)
                byID[camera.id] = camera
            }
        }
        try? modelContext.save()
    }

    private func pruneCache() {
        guard let modelContext else { return }
        let cutoff = Date().addingTimeInterval(-maxAge)
        let all = ((try? modelContext.fetch(FetchDescriptor<ALPRCamera>())) ?? [])
            .sorted { $0.fetchedAt > $1.fetchedAt }

        for camera in all where camera.fetchedAt < cutoff {
            modelContext.delete(camera)
        }

        let remaining = all.filter { $0.fetchedAt >= cutoff }
        if remaining.count > maxCachedCameras {
            for camera in remaining.dropFirst(maxCachedCameras) {
                modelContext.delete(camera)
            }
        }
        try? modelContext.save()
    }
}
