import CoreLocation
import Foundation
import MapKit
import SwiftData

@MainActor
@Observable
final class CameraRepository {
    private(set) var cameras: [ALPRCamera] = []
    /// Grid index over `cameras`, rebuilt whenever the cache changes. Safe to hand to detached work.
    private(set) var spatialIndex = CameraSpatialIndex.empty
    /// Bumps on every cache change so the Map knows to rebuild its snapshot.
    private(set) var indexVersion = 0
    private var camerasByID: [String: ALPRCamera] = [:]
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
    /// Background actor that owns all SwiftData diffing and saving.
    private var store: CameraStore?
    /// Latest-wins guard: a store result applies only if no newer store call has started since.
    private var loadToken = 0
    private var debounceTask: Task<Void, Never>?
    private var seedTask: Task<Void, Never>?
    private var fetchGeneration = 0
    private var inFlightFetchGenerations = Set<Int>()

    private let seedMinimumCacheCount = 250

    init(client: OverpassClient = .shared) {
        self.client = client
    }

    func attach(modelContext: ModelContext) {
        // Idempotent — onboarding → map can call this more than once.
        if self.modelContext != nil { return }
        self.modelContext = modelContext
        store = CameraStore(modelContainer: modelContext.container)
        Task { [weak self] in
            guard let self else { return }
            await self.reloadFromStore()
            self.lastSuccessfulFetchAt = self.cameras.map(\.fetchedAt).max()
            if self.cameras.count < self.seedMinimumCacheCount {
                self.startSeedIfNeeded()
            }
        }
    }

    /// Re-read the cache. The fetch, filter, sort and index build run on the store actor.
    func loadCached() {
        Task { await reloadFromStore() }
    }

    private func reloadFromStore() async {
        guard let store else { return }
        let token = nextLoadToken()
        let result = await store.load()
        apply(result, token: token)
    }

    private func nextLoadToken() -> Int {
        loadToken &+= 1
        return loadToken
    }

    /// Resolve a background load into main-context models and publish it.
    private func apply(_ result: CameraLoadResult, token: Int) {
        guard token == loadToken, let modelContext else { return }
        let models = result.orderedIDs.compactMap { modelContext.model(for: $0) as? ALPRCamera }
        // Normally identical; rebuild if any row vanished between the background save and now.
        let index = models.count == result.orderedIDs.count ? result.index : nil
        setCameras(models, index: index)
        // Heavy distance ranking must not block the main thread (onboarding → map).
        Task { await publishAlertCandidatesAsync() }
    }

    /// Single write path for `cameras`: keeps the spatial index and id lookup in step.
    private func setCameras(_ new: [ALPRCamera], index: CameraSpatialIndex? = nil) {
        cameras = new
        camerasByID = Dictionary(new.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        spatialIndex = index ?? CameraSpatialIndex(points: new.map(\.point))
        indexVersion &+= 1
    }

    /// Resolve snapshot ids back to live models (e.g. a tapped cluster). Unknown ids are dropped.
    func cameras(withIDs ids: [String]) -> [ALPRCamera] {
        ids.compactMap { camerasByID[$0] }
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

        let result = await Task.detached(priority: .utility) { () -> (data: Data?, signature: [String], points: [WidgetSnapshotStore.CameraPoint]) in
            let candidates = AlertCandidateRanking.select(
                from: snapshot,
                home: home,
                viewport: regionCenter,
                fallback: fallback
            )
            let signature = candidates.map(\.id)
            let data = try? JSONEncoder().encode(candidates)

            let widgetAnchor = home ?? regionCenter ?? fallback
            let homeOrigin = CLLocation(latitude: widgetAnchor.latitude, longitude: widgetAnchor.longitude)
            let widgetPoints = snapshot
                .map { row -> (row: (id: String, latitude: Double, longitude: Double, isFlock: Bool, title: String), distance: CLLocationDistance) in
                    let location = CLLocation(latitude: row.latitude, longitude: row.longitude)
                    return (row, location.distance(from: homeOrigin))
                }
                .filter { $0.distance <= 5 * 1609.34 }
                .sorted { $0.distance < $1.distance }
                .prefix(1_000)
                .map { WidgetSnapshotStore.CameraPoint(latitude: $0.row.latitude, longitude: $0.row.longitude) }

            return (data, signature, Array(widgetPoints))
        }.value

        let candidatesChanged: Bool
        if let data = result.data {
            candidatesChanged = AlertCandidateStore.replaceEncodedIfChanged(data, signature: result.signature)
        } else {
            candidatesChanged = false
        }
        WidgetSnapshotStore.writeCameraPoints(result.points)
        // Reseed only when the ranked set actually changed (Home / new metro),
        // not on every map-pan Overpass fetch.
        if candidatesChanged, AppPreferences.alertsEnabled {
            AlertsEngine.shared.reseedFromLastKnownLocation()
        }
    }

    /// Re-rank alert candidates after Home / cache changes, then reseed geofences.
    func republishAlertCandidates() {
        Task { await publishAlertCandidatesAsync() }
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
                await upsertDTOs(remote)
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
            ? "Zoom into a city to load more mapped pins — Overpass only serves metro-sized areas."
            : nil

        let tiles = GeoHelpers.queryTiles(
            for: region,
            collapseContinental: collapseContinental,
            maxTiles: collapseContinental ? GeoHelpers.maxTilesPerFetch : 24
        )

        do {
            var combined: [ALPRCameraDTO] = []
            var seen = Set<String>()
            // Include empty tiles: OverpassClient only returns [] after multi-mirror consensus.
            // CoverageConfidence refuses dense empty clears; sparse voids can soft-clear.
            // `seen` protects cameras upserted from a neighbor tile on a shared edge.
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
            // One background pass per fetch: upsert, a single batched absent diff, prune, one save.
            if let store {
                let token = nextLoadToken()
                let result = await store.applyFetch(
                    dtos: combined,
                    tileResults: tileResults.map { FetchTileResult(region: $0.region, ids: $0.ids) },
                    protecting: seen,
                    markAbsent: updateSettledRegion && !tooLarge
                )
                apply(result, token: token)
            } else {
                upsertInMemory(combined.map { $0.makeModel() })
            }
            if updateSettledRegion {
                // Only the tiles we actually queried — never the scheduled
                // continental / capped viewport (false Place Score Clear).
                lastFetchedRegion = GeoHelpers.unionRegion(of: tiles)
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
                    coverageHint = "Zoom into a city to load more mapped pins — showing cached pins only."
                }
                isServingStale = !cameras.isEmpty
                if cameras.isEmpty {
                    await reloadFromStore()
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
        coverageHint = "Seeding Memphis / DeSoto + major metros…"

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
                        await self.upsertDTOs(remote)
                        loadedAny = true
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

            if let store = self.store {
                let token = self.nextLoadToken()
                let result = await store.pruneAndLoad()
                self.apply(result, token: token)
            }
            self.isSeeding = false
            if loadedAny {
                self.coverageHint = nil
            } else if self.cameras.count < self.seedMinimumCacheCount {
                self.coverageHint = "Zoom into a city to load mapped pins from OpenStreetMap."
            }
        }
    }

    func clearCache() {
        seedTask?.cancel()
        isSeeding = false
        guard let store else {
            setCameras([])
            lastSuccessfulFetchAt = nil
            lastFetchedRegion = nil
            lastRegion = nil
            AlertCandidateStore.clear()
            WidgetSnapshotStore.clearNearbySnapshot()
            AlertsEngine.shared.clearGeofences()
            return
        }
        // Invalidate any in-flight load so rows being deleted aren't resurrected.
        loadToken &+= 1
        setCameras([])
        lastSuccessfulFetchAt = nil
        lastFetchedRegion = nil
        lastRegion = nil
        isServingStale = false
        coverageHint = nil
        AlertCandidateStore.clear()
        WidgetSnapshotStore.clearNearbySnapshot()
        AlertsEngine.shared.clearGeofences()
        WidgetBridge.writeNearbySnapshot(from: [])
        Task { [weak self] in
            await store.clearAll()
            self?.startSeedIfNeeded()
        }
    }

    func refreshWidgetSnapshot() {
        WidgetBridge.writeNearbySnapshot(from: cameras)
    }

    /// Soft-hide a camera after a confirmed removal report.
    func hideCamera(id: String) {
        // Optimistic: the pin disappears now; the store persists the hide and we reload.
        setCameras(cameras.filter { $0.id != id })
        WidgetBridge.writeNearbySnapshot(from: cameras)
        guard let store else { return }
        Task { [weak self] in
            guard let self else { return }
            let token = self.nextLoadToken()
            let result = await store.hide(id: id)
            self.apply(result, token: token)
            WidgetBridge.writeNearbySnapshot(from: self.cameras)
        }
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
        cameras
            .map { ($0, GeoDistance.meters(
                fromLatitude: coordinate.latitude, longitude: coordinate.longitude,
                toLatitude: $0.latitude, longitude: $0.longitude
            )) }
            .filter { $0.1 <= radiusMeters }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    func nearest(to coordinate: CLLocationCoordinate2D, filter: CameraFilter) -> (camera: ALPRCamera, meters: CLLocationDistance)? {
        guard let hit = spatialIndex.nearest(to: coordinate, filter: filter),
              let camera = camerasByID[hit.point.id]
        else { return nil }
        return (camera: camera, meters: hit.meters)
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

    func placeScore(
        near coordinate: CLLocationCoordinate2D,
        radiusMeters: CLLocationDistance = 1609.34,
        isPersonal: Bool = true
    ) -> PlaceScore {
        GeoHelpers.placeScore(
            cameras: cameras,
            near: coordinate,
            radiusMeters: radiusMeters,
            isPersonal: isPersonal
        )
    }

    var freshnessLabel: String? {
        let base = GeoHelpers.relativeFreshness(from: lastSuccessfulFetchAt)
        guard let base else { return nil }
        if isSeeding { return "\(base) · seeding metros" }
        return isServingStale ? "\(base) · cached" : base
    }

    private func upsertDTOs(_ dtos: [ALPRCameraDTO]) async {
        guard let store else {
            upsertInMemory(dtos.map { $0.makeModel() })
            return
        }
        let token = nextLoadToken()
        let result = await store.upsert(dtos: dtos)
        apply(result, token: token)
    }

    /// Only used before a store is attached (no persistence): merge into the in-memory list.
    private func upsertInMemory(_ remote: [ALPRCamera]) {
        var byID = Dictionary(cameras.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for camera in remote {
            byID[camera.id] = camera
        }
        setCameras(Array(byID.values))
    }
}
