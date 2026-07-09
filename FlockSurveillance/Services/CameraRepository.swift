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
        let descriptor = FetchDescriptor<ALPRCamera>(sortBy: [SortDescriptor(\.fetchedAt, order: .reverse)])
        cameras = (try? modelContext.fetch(descriptor)) ?? []
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
            upsert(remote)
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

        for camera in remote {
            let id = camera.id
            var descriptor = FetchDescriptor<ALPRCamera>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            if let existing = try? modelContext.fetch(descriptor).first {
                existing.latitude = camera.latitude
                existing.longitude = camera.longitude
                existing.manufacturer = camera.manufacturer
                existing.operatorName = camera.operatorName
                existing.direction = camera.direction
                existing.cameraName = camera.cameraName
                existing.tagsJSON = camera.tagsJSON
                existing.fetchedAt = camera.fetchedAt
            } else {
                modelContext.insert(camera)
            }
        }
        try? modelContext.save()
    }

    private func pruneCache() {
        guard let modelContext else { return }
        let cutoff = Date().addingTimeInterval(-maxAge)
        let descriptor = FetchDescriptor<ALPRCamera>(sortBy: [SortDescriptor(\.fetchedAt, order: .reverse)])
        guard let all = try? modelContext.fetch(descriptor) else { return }

        for camera in all where camera.fetchedAt < cutoff {
            modelContext.delete(camera)
        }

        let remaining = (try? modelContext.fetch(descriptor)) ?? []
        if remaining.count > maxCachedCameras {
            for camera in remaining.dropFirst(maxCachedCameras) {
                modelContext.delete(camera)
            }
        }
        try? modelContext.save()
    }
}
