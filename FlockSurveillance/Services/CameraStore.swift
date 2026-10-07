import CoreLocation
import Foundation
import MapKit
import SwiftData

/// What a background load hands back to the main actor. Only `Sendable` values cross.
struct CameraLoadResult: Sendable {
    /// Visible (not hidden, not absent) rows, newest `fetchedAt` first.
    let orderedIDs: [PersistentIdentifier]
    /// Same order as `orderedIDs`.
    let index: CameraSpatialIndex
    let latestFetchedAt: Date?

    static let empty = CameraLoadResult(orderedIDs: [], index: .empty, latestFetchedAt: nil)
}

/// One tile of an Overpass fetch: where we looked and which OSM ids came back.
struct FetchTileResult: Sendable {
    let region: MKCoordinateRegion
    let ids: Set<String>
}

/// All SwiftData diffing and saving for the camera cache, off the main actor.
/// The UI keeps reading through the main context; this actor saves through its own context and
/// the main context picks the changes up from the shared store.
@ModelActor
actor CameraStore {
    static let maxCachedCameras = 12_000
    static let maxAge: TimeInterval = 14 * 24 * 60 * 60

    /// How many batched absent-marking passes have run. One per fetch, however many tiles it had.
    private(set) var markAbsentPassCount = 0

    // MARK: Load

    func load() -> CameraLoadResult {
        Self.result(from: fetchAll())
    }

    private static func result(from all: [ALPRCamera]) -> CameraLoadResult {
        // Sort in memory to avoid Swift 6 KeyPath Sendable diagnostics from SortDescriptor.
        let visible = all
            .filter { !$0.isHidden && !$0.isAbsentFromOSM }
            .sorted { $0.fetchedAt > $1.fetchedAt }
        return CameraLoadResult(
            orderedIDs: visible.map(\.persistentModelID),
            index: CameraSpatialIndex(points: visible.map(\.point)),
            latestFetchedAt: visible.first?.fetchedAt
        )
    }

    private func fetchAll() -> [ALPRCamera] {
        (try? modelContext.fetch(FetchDescriptor<ALPRCamera>())) ?? []
    }

    // MARK: Writes

    /// Upsert + one batched absent pass + prune, saved once, then a fresh load.
    func applyFetch(
        dtos: [ALPRCameraDTO],
        tileResults: [FetchTileResult],
        protecting seen: Set<String>,
        markAbsent: Bool
    ) -> CameraLoadResult {
        var all = fetchAll()
        upsert(dtos, into: &all)
        if markAbsent {
            markAbsentFromOSM(tileResults: tileResults, protecting: seen, in: all)
        }
        prune(&all)
        try? modelContext.save()
        return Self.result(from: all)
    }

    /// Report probes and seed tiles: upsert only, then reload.
    func upsert(dtos: [ALPRCameraDTO]) -> CameraLoadResult {
        var all = fetchAll()
        upsert(dtos, into: &all)
        try? modelContext.save()
        return Self.result(from: all)
    }

    func pruneAndLoad() -> CameraLoadResult {
        var all = fetchAll()
        prune(&all)
        try? modelContext.save()
        return Self.result(from: all)
    }

    /// Soft-hide after a confirmed removal report.
    func hide(id: String) -> CameraLoadResult {
        let all = fetchAll()
        if let match = all.first(where: { $0.id == id }) {
            match.isHidden = true
            try? modelContext.save()
        }
        return Self.result(from: all)
    }

    func clearAll() {
        for camera in fetchAll() { modelContext.delete(camera) }
        try? modelContext.save()
    }

    // MARK: Internals

    private func upsert(_ dtos: [ALPRCameraDTO], into all: inout [ALPRCamera]) {
        // Index existing rows in memory instead of #Predicate KeyPaths (not Sendable in Swift 6).
        var byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for dto in dtos {
            if let current = byID[dto.id] {
                current.latitude = dto.latitude
                current.longitude = dto.longitude
                current.manufacturer = dto.manufacturer
                current.operatorName = dto.operatorName
                // Don't wipe a known direction when a mirror omits the tag.
                if let direction = dto.direction, !direction.isEmpty {
                    current.direction = direction
                }
                current.cameraName = dto.cameraName
                current.tagsJSON = dto.tagsJSON
                current.fetchedAt = dto.fetchedAt
                current.isAbsentFromOSM = false
                // Preserve local soft-hide across refetches.
            } else {
                let model = ALPRCamera(
                    id: dto.id,
                    latitude: dto.latitude,
                    longitude: dto.longitude,
                    manufacturer: dto.manufacturer,
                    operatorName: dto.operatorName,
                    direction: dto.direction,
                    cameraName: dto.cameraName,
                    tagsJSON: dto.tagsJSON,
                    fetchedAt: dto.fetchedAt
                )
                modelContext.insert(model)
                byID[dto.id] = model
                all.append(model)
            }
        }
    }

    /// Soft-mark cameras inside successfully covered tiles that OSM no longer returned.
    /// Empty `ids` is allowed; sparse-void trust lives in CoverageConfidence.
    /// `seen` holds IDs returned anywhere in this fetch batch (neighbor-tile edges).
    ///
    /// One pass for the whole fetch. Tiles are still evaluated in order and each tile's density gate
    /// sees the absences earlier tiles just marked, exactly as the old per-tile calls did.
    private func markAbsentFromOSM(
        tileResults: [FetchTileResult],
        protecting seen: Set<String>,
        in all: [ALPRCamera]
    ) {
        markAbsentPassCount += 1
        guard !tileResults.isEmpty else { return }
        // Hidden / already-absent rows must not inflate density and block sparse clear.
        var visible = all.filter { !$0.isHidden && !$0.isAbsentFromOSM }
        for tile in tileResults {
            let absent = CoverageConfidence.idsToMarkAbsent(
                cached: visible.map { ($0.id, $0.coordinate) },
                remoteIDs: tile.ids,
                regions: [tile.region],
                excluding: seen
            )
            guard !absent.isEmpty else { continue }
            for camera in all where absent.contains(camera.id) {
                // Don't override an explicit user removal hide.
                if camera.isHidden { continue }
                camera.isAbsentFromOSM = true
            }
            visible.removeAll { absent.contains($0.id) }
        }
    }

    private func prune(_ all: inout [ALPRCamera]) {
        let cutoff = Date().addingTimeInterval(-Self.maxAge)
        let sorted = all.sorted { $0.fetchedAt > $1.fetchedAt }

        var kept: [ALPRCamera] = []
        for camera in sorted {
            if camera.fetchedAt < cutoff {
                modelContext.delete(camera)
            } else {
                kept.append(camera)
            }
        }
        if kept.count > Self.maxCachedCameras {
            for camera in kept.dropFirst(Self.maxCachedCameras) { modelContext.delete(camera) }
            kept = Array(kept.prefix(Self.maxCachedCameras))
        }
        all = kept
    }
}
