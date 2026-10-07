import CoreLocation
import Foundation
import MapKit

struct ClusterSnapshot: Sendable, Identifiable, Hashable {
    let id: String
    let latitude: Double
    let longitude: Double
    let cameraIDs: [String]
    let isFlockDominant: Bool

    var count: Int { cameraIDs.count }
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct NearestSnapshot: Sendable, Equatable {
    let id: String
    let meters: Double
    let latitude: Double
    let longitude: Double
    let manufacturer: String
}

/// Everything the Map body needs, computed once off the main actor and published as one value.
struct MapSnapshot: Sendable {
    var inViewCount: Int
    /// Share of in-view pins carrying a parseable `direction` tag (0–100).
    var facingPercent: Int
    var clusters: [ClusterSnapshot]
    var nearest: NearestSnapshot?
    /// First pins in view (original order) that have a facing direction — drives the FOV wedges.
    var fovPoints: [CameraPoint]

    static let empty = MapSnapshot(inViewCount: 0, facingPercent: 0, clusters: [], nearest: nil, fovPoints: [])
    static let maxFOVPoints = 40
}

enum MapSnapshotBuilder {
    /// Pure and `Sendable`-in / `Sendable`-out, so it runs happily in `Task.detached`.
    /// Mirrors the old computed properties: `GeoHelpers.cameras(in:)`, `GeoHelpers.clusters`,
    /// and a min-distance scan, but through the spatial index.
    nonisolated static func build(
        index: CameraSpatialIndex,
        region: MKCoordinateRegion?,
        filter: CameraFilter,
        user: CLLocationCoordinate2D?
    ) -> MapSnapshot {
        var snapshot = MapSnapshot.empty

        if let region {
            let inView = index.points(in: region, filter: filter)
            snapshot.inViewCount = inView.count
            if !inView.isEmpty {
                let facing = inView.reduce(0) { $0 + ($1.directionDegrees != nil ? 1 : 0) }
                snapshot.facingPercent = Int((Double(facing) / Double(inView.count) * 100).rounded())
            }
            snapshot.clusters = clusters(from: inView, region: region)
            snapshot.fovPoints = Array(inView.lazy.filter { $0.directionDegrees != nil }.prefix(MapSnapshot.maxFOVPoints))
        }

        if let user, let hit = index.nearest(to: user, filter: filter) {
            snapshot.nearest = NearestSnapshot(
                id: hit.point.id,
                meters: hit.meters,
                latitude: hit.point.latitude,
                longitude: hit.point.longitude,
                manufacturer: hit.point.manufacturer
            )
        }
        return snapshot
    }

    /// Same bucketing as `GeoHelpers.clusters(for:in:from:)` (cell size and key format included).
    nonisolated static func clusters(from inView: [CameraPoint], region: MKCoordinateRegion) -> [ClusterSnapshot] {
        let span = max(region.span.latitudeDelta, region.span.longitudeDelta)
        let cellSize = max(span / 12, 0.0008)
        var buckets: [String: [CameraPoint]] = [:]
        for point in inView {
            let latBucket = Int((point.latitude / cellSize).rounded(.down))
            let lonBucket = Int((point.longitude / cellSize).rounded(.down))
            buckets["\(latBucket):\(lonBucket)", default: []].append(point)
        }
        return buckets.compactMap { key, group in
            guard !group.isEmpty else { return nil }
            let lat = group.map(\.latitude).reduce(0, +) / Double(group.count)
            let lon = group.map(\.longitude).reduce(0, +) / Double(group.count)
            let flockCount = group.filter(\.isFlock).count
            return ClusterSnapshot(
                id: key,
                latitude: lat,
                longitude: lon,
                cameraIDs: group.map(\.id),
                isFlockDominant: flockCount >= group.count - flockCount
            )
        }
    }
}
