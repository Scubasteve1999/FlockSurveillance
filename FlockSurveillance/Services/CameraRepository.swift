import Foundation
import MapKit
import SwiftData

@MainActor
@Observable
final class CameraRepository {
    private(set) var cameras: [ALPRCamera] = []
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var coverageHint: String?
    private(set) var lastRegion: MKCoordinateRegion?
    private(set) var lastSuccessfulFetchAt: Date?
    private(set) var isServingStale = false
    private(set) var isSeeding = false

    private let client: OverpassClient
    private var modelContext: ModelContext?
    private var debounceTask: Task<Void, Never>?
    private var seedTask: Task<Void, Never>?
    private var fetchGeneration = 0

    private let maxCachedCameras = 12_000
    private let maxAge: TimeInterval = 14 * 24 * 60 * 60
    private let seedMinimumCacheCount = 250

    init(client: OverpassClient = .shared) {
        self.client = client
    }

    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCached()
        lastSuccessfulFetchAt = cameras.map(\.fetchedAt).max()
        if cameras.count < seedMinimumCacheCount {
            startSeedIfNeeded()
        }
    }

    func loadCached() {
        guard let modelContext else { return }
        // Sort in memory to avoid Swift 6 KeyPath Sendable diagnostics from SortDescriptor.
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

    func fetch(for region: MKCoordinateRegion, collapseContinental: Bool = true) async {
        fetchGeneration += 1
        let generation = fetchGeneration
        isLoading = true
        lastError = nil

        let tooLarge = collapseContinental && GeoHelpers.isRegionTooLargeForFullFetch(region)
        coverageHint = tooLarge
            ? "Zoom into a city to load more cameras — Overpass only serves metro-sized areas."
            : nil

        let tiles = GeoHelpers.queryTiles(
            for: region,
            collapseContinental: collapseContinental,
            maxTiles: collapseContinental ? GeoHelpers.maxTilesPerFetch : 24
        )

        do {
            var combined: [ALPRCameraDTO] = []
            var seen = Set<String>()
            for tile in tiles {
                guard generation == fetchGeneration else { return }
                let remote = try await client.fetchCameras(in: tile)
                for dto in remote where seen.insert(dto.id).inserted {
                    combined.append(dto)
                }
            }

            guard generation == fetchGeneration else { return }
            upsert(combined.map { $0.makeModel() })
            pruneCache()
            loadCached()
            lastSuccessfulFetchAt = .now
            isServingStale = false
            WidgetBridge.writeNearbySnapshot(from: cameras)
        } catch is CancellationError {
            // ignore
        } catch {
            if generation == fetchGeneration {
                lastError = tooLarge
                    ? nil
                    : error.localizedDescription
                if tooLarge {
                    coverageHint = "Zoom into a city to load more cameras — showing cached pins only."
                }
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

    func startSeedIfNeeded() {
        guard !isSeeding, cameras.count < seedMinimumCacheCount else { return }
        seedTask?.cancel()
        isSeeding = true
        coverageHint = "Loading major metro areas…"

        seedTask = Task { [weak self] in
            guard let self else { return }
            var loadedAny = false
            for metro in GeoHelpers.seedMetros {
                if Task.isCancelled { break }
                // Skip seed tiles that already have dense local cache.
                let region = GeoHelpers.seedRegion(for: metro.coordinate)
                let existingNearby = self.cameras(in: region).count
                if existingNearby >= 40 { continue }

                do {
                    let remote = try await self.client.fetchCameras(in: region)
                    if !remote.isEmpty {
                        self.upsert(remote.map { $0.makeModel() })
                        loadedAny = true
                        self.loadCached()
                        self.lastSuccessfulFetchAt = .now
                        self.isServingStale = false
                        WidgetBridge.writeNearbySnapshot(from: self.cameras)
                    }
                } catch {
                    // Soft-fail individual seed tiles; continue warming the rest.
                }

                if self.cameras.count >= self.seedMinimumCacheCount { break }
                // Pace seed requests so Overpass rate limits don't reject the whole pass.
                try? await Task.sleep(nanoseconds: 700_000_000)
            }

            self.pruneCache()
            self.loadCached()
            self.isSeeding = false
            if loadedAny {
                self.coverageHint = nil
            } else if self.cameras.count < self.seedMinimumCacheCount {
                self.coverageHint = "Zoom into a city to load cameras from OpenStreetMap."
            }
        }
    }

    func clearCache() {
        seedTask?.cancel()
        isSeeding = false
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
        coverageHint = nil
        WidgetBridge.writeNearbySnapshot(from: [])
        startSeedIfNeeded()
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

    /// Warm cache along each route corridor without collapsing long unions to a center tile.
    func fetchCamerasAlong(routes: [MKRoute]) async -> [ALPRCamera] {
        var seen = Set<String>()
        var combined: [ALPRCamera] = []
        for route in routes {
            let region = GeoHelpers.region(for: route)
            await fetch(for: region, collapseContinental: false)
            for camera in cameras(in: region) where seen.insert(camera.id).inserted {
                combined.append(camera)
            }
        }
        return combined
    }

    func placeScore(near coordinate: CLLocationCoordinate2D, radiusMeters: CLLocationDistance = 1609.34) -> PlaceScore {
        GeoHelpers.placeScore(cameras: cameras, near: coordinate, radiusMeters: radiusMeters)
    }

    var freshnessLabel: String? {
        let base = GeoHelpers.relativeFreshness(from: lastSuccessfulFetchAt)
        guard let base else { return nil }
        if isSeeding { return "\(base) · seeding metros" }
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
                if byID[camera.id] == nil {
                    byID[camera.id] = camera
                }
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
