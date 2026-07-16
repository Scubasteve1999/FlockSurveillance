import CoreLocation
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
    /// Region of the last *successful* Overpass fetch. Used for Place Score
    /// settlement — unlike `lastRegion`, this is not set at schedule time and
    /// is not updated on failure (avoids false Clear).
    private(set) var lastFetchedRegion: MKCoordinateRegion?
    private(set) var lastSuccessfulFetchAt: Date?
    private(set) var isServingStale = false
    private(set) var isSeeding = false

    private let client: OverpassClient
    private var modelContext: ModelContext?
    private var debounceTask: Task<Void, Never>?
    private var seedTask: Task<Void, Never>?
    private var fetchGeneration = 0
    private var inFlightFetchGenerations = Set<Int>()

    private let maxCachedCameras = 12_000
    private let maxAge: TimeInterval = 14 * 24 * 60 * 60
    private let seedMinimumCacheCount = 250

    init(client: OverpassClient = .shared) {
        self.client = client
    }

    func attach(modelContext: ModelContext) {
        // Idempotent — onboarding → map can call this more than once.
        if self.modelContext != nil { return }
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
        cameras = fetched
            .filter { !$0.isHidden && !$0.isAbsentFromOSM }
            .sorted { $0.fetchedAt > $1.fetchedAt }
        // Heavy distance ranking must not block the main thread (onboarding → map).
        Task { await publishAlertCandidatesAsync() }
    }

    /// Snapshot cameras to disk so AlertsEngine can reseed geofences on
    /// background wake-ups without opening SwiftData.
    /// Prefer cameras nearest Home (then last viewport, then Atlanta) — not the
    /// most recently fetched — so travel / a large cache still geofences locally.
    private func publishAlertCandidatesAsync() async {
        let snapshot = cameras.map {
            (
                id: $0.id,
                latitude: $0.latitude,
                longitude: $0.longitude,
                isFlock: $0.isFlock,
                title: $0.displayTitle
            )
        }
        let home = WidgetBridge.homeCoordinate()
        let regionCenter = lastRegion?.center
        let fallback = CLLocationCoordinate2D(latitude: 33.7490, longitude: -84.3880)

        let result = await Task.detached(priority: .utility) { () -> (candidates: [AlertCandidate], points: [WidgetSnapshotStore.CameraPoint]) in
            let anchor = home ?? regionCenter ?? fallback
            let origin = CLLocation(latitude: anchor.latitude, longitude: anchor.longitude)
            let ranked = snapshot
                .map { row -> (row: (id: String, latitude: Double, longitude: Double, isFlock: Bool, title: String), distance: CLLocationDistance) in
                    let location = CLLocation(latitude: row.latitude, longitude: row.longitude)
                    return (row, location.distance(from: origin))
                }
                .sorted { $0.distance < $1.distance }

            let candidates = ranked.prefix(5_000).map {
                AlertCandidate(
                    id: $0.row.id,
                    latitude: $0.row.latitude,
                    longitude: $0.row.longitude,
                    isFlock: $0.row.isFlock,
                    title: $0.row.title
                )
            }

            let homeOrigin: CLLocation
            if let home {
                homeOrigin = CLLocation(latitude: home.latitude, longitude: home.longitude)
            } else {
                homeOrigin = origin
            }
            let widgetPoints = snapshot
                .map { row -> (row: (id: String, latitude: Double, longitude: Double, isFlock: Bool, title: String), distance: CLLocationDistance) in
                    let location = CLLocation(latitude: row.latitude, longitude: row.longitude)
                    return (row, location.distance(from: homeOrigin))
                }
                .filter { $0.distance <= 5 * 1609.34 }
                .sorted { $0.distance < $1.distance }
                .prefix(1_000)
                .map { WidgetSnapshotStore.CameraPoint(latitude: $0.row.latitude, longitude: $0.row.longitude) }

            return (Array(candidates), Array(widgetPoints))
        }.value

        AlertCandidateStore.write(result.candidates)
        WidgetSnapshotStore.writeCameraPoints(result.points)
    }

    func scheduleFetch(for region: MKCoordinateRegion, delayNanoseconds: UInt64 = 450_000_000) {
        lastRegion = region
        debounceTask?.cancel()
        // Invalidate any in-flight fetch so a newer focus/score request isn't
        // cleared by an older Overpass response finishing first.
        fetchGeneration += 1
        let generation = fetchGeneration
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard let self, !Task.isCancelled else { return }
            guard generation == self.fetchGeneration else { return }
            await self.fetch(for: region, generation: generation)
        }
    }

    func fetch(for region: MKCoordinateRegion, collapseContinental: Bool = true) async {
        lastRegion = region
        fetchGeneration += 1
        _ = await fetch(for: region, generation: fetchGeneration, collapseContinental: collapseContinental)
    }

    /// Fetches and upserts cameras; returns remote IDs from a successful response, or nil on failure.
    /// - Parameter updateSettledRegion: When false (report probes), do not write `lastFetchedRegion`
    ///   so Place Score Clear settlement is not poisoned by a tiny verification bbox.
    @discardableResult
    func fetchReturningRemoteIDs(
        for region: MKCoordinateRegion,
        collapseContinental: Bool = true,
        updateSettledRegion: Bool = true
    ) async -> Set<String>? {
        if updateSettledRegion {
            lastRegion = region
        }
        fetchGeneration += 1
        return await fetch(
            for: region,
            generation: fetchGeneration,
            collapseContinental: collapseContinental,
            updateSettledRegion: updateSettledRegion
        )
    }

    /// Side-channel Overpass probe for report baseline / verification.
    /// Does not bump fetchGeneration, isLoading, or lastFetchedRegion.
    func probeCameras(in region: MKCoordinateRegion) async -> Set<String>? {
        do {
            let remote = try await client.fetchCameras(in: region)
            if !remote.isEmpty {
                upsert(remote.map { $0.makeModel() })
                loadCached()
            }
            return Set(remote.map(\.id))
        } catch {
            return nil
        }
    }

    /// True when a successful Overpass fetch covering `coordinate` has finished
    /// and nothing is still in flight — safe to trust a Clear Place Score.
    func hasSettledFetch(covering coordinate: CLLocationCoordinate2D) -> Bool {
        GeoHelpers.placeScoreIsSettled(
            coordinate: coordinate,
            isLoading: isLoading,
            lastFetchedRegion: lastFetchedRegion
        )
    }

    @discardableResult
    private func fetch(
        for region: MKCoordinateRegion,
        generation: Int,
        collapseContinental: Bool = true,
        updateSettledRegion: Bool = true
    ) async -> Set<String>? {
        beginFetch(generation)
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
            // Include empty tiles: OverpassClient already confirmed [] across mirrors.
            // CoverageConfidence refuses dense empty clears; sparse voids can soft-clear.
            var tileResults: [(region: MKCoordinateRegion, ids: Set<String>)] = []
            for tile in tiles {
                guard generation == fetchGeneration else {
                    endFetch(generation)
                    return nil
                }
                let remote = try await client.fetchCameras(in: tile)
                var tileIDs = Set<String>()
                for dto in remote {
                    tileIDs.insert(dto.id)
                    if seen.insert(dto.id).inserted {
                        combined.append(dto)
                    }
                }
                tileResults.append((tile, tileIDs))
            }

            guard generation == fetchGeneration else {
                endFetch(generation)
                return nil
            }
            upsert(combined.map { $0.makeModel() })
            if updateSettledRegion, !tooLarge {
                for tileResult in tileResults {
                    markAbsentFromOSM(remoteIDs: tileResult.ids, in: [tileResult.region])
                }
            }
            pruneCache()
            loadCached()
            if updateSettledRegion {
                lastFetchedRegion = region
            }
            lastSuccessfulFetchAt = .now
            isServingStale = false
            WidgetBridge.writeNearbySnapshot(from: cameras)
            endFetch(generation)
            return seen
        } catch is CancellationError {
            endFetch(generation)
            return nil
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
            // Failed fetch must not update lastFetchedRegion (false Clear).
            endFetch(generation)
            return nil
        }
    }

    private func beginFetch(_ generation: Int) {
        inFlightFetchGenerations.insert(generation)
        isLoading = true
    }

    private func endFetch(_ generation: Int) {
        inFlightFetchGenerations.remove(generation)
        isLoading = !inFlightFetchGenerations.isEmpty
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
            lastSuccessfulFetchAt = nil
            lastFetchedRegion = nil
            lastRegion = nil
            AlertCandidateStore.clear()
            WidgetSnapshotStore.clearNearbySnapshot()
            AlertsEngine.shared.clearGeofences()
            return
        }
        let all = (try? modelContext.fetch(FetchDescriptor<ALPRCamera>())) ?? []
        for camera in all {
            modelContext.delete(camera)
        }
        try? modelContext.save()
        cameras = []
        lastSuccessfulFetchAt = nil
        lastFetchedRegion = nil
        lastRegion = nil
        isServingStale = false
        coverageHint = nil
        AlertCandidateStore.clear()
        WidgetSnapshotStore.clearNearbySnapshot()
        AlertsEngine.shared.clearGeofences()
        WidgetBridge.writeNearbySnapshot(from: [])
        startSeedIfNeeded()
    }

    func refreshWidgetSnapshot() {
        WidgetBridge.writeNearbySnapshot(from: cameras)
    }

    /// Soft-hide a camera after a confirmed removal report.
    func hideCamera(id: String) {
        guard let modelContext else {
            cameras.removeAll { $0.id == id }
            return
        }
        let all = (try? modelContext.fetch(FetchDescriptor<ALPRCamera>())) ?? []
        if let match = all.first(where: { $0.id == id }) {
            match.isHidden = true
            try? modelContext.save()
        }
        loadCached()
        WidgetBridge.writeNearbySnapshot(from: cameras)
        Task { await publishAlertCandidatesAsync() }
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
                // Don't wipe a known direction when a mirror omits the tag.
                if let direction = camera.direction, !direction.isEmpty {
                    current.direction = direction
                }
                current.cameraName = camera.cameraName
                current.tagsJSON = camera.tagsJSON
                current.fetchedAt = camera.fetchedAt
                current.isAbsentFromOSM = false
                // Preserve local soft-hide across refetches.
            } else {
                modelContext.insert(camera)
                if byID[camera.id] == nil {
                    byID[camera.id] = camera
                }
            }
        }
        try? modelContext.save()
    }

    /// Soft-mark cameras inside successfully covered tiles that OSM no longer returned.
    /// Empty `remoteIDs` is allowed — sparse-void trust lives in CoverageConfidence.
    private func markAbsentFromOSM(remoteIDs: Set<String>, in regions: [MKCoordinateRegion]) {
        guard let modelContext, !regions.isEmpty else { return }
        let existing = (try? modelContext.fetch(FetchDescriptor<ALPRCamera>())) ?? []
        let absent = CoverageConfidence.idsToMarkAbsent(
            cached: existing.map { ($0.id, $0.coordinate) },
            remoteIDs: remoteIDs,
            regions: regions
        )
        guard !absent.isEmpty else { return }
        for camera in existing where absent.contains(camera.id) {
            // Don't override an explicit user removal hide.
            if camera.isHidden { continue }
            camera.isAbsentFromOSM = true
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
