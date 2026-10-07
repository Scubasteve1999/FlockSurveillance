import CoreLocation
import Foundation
import MapKit

/// Plain-double distance. Replaces a per-row `CLLocation` allocation in hot loops.
///
/// Equirectangular on the local WGS84 ellipsoid (meridional / prime-vertical radii of curvature),
/// so it tracks `CLLocation.distance(from:)` to well under a metre at city scale. A spherical
/// haversine would drift from CoreLocation by up to ~0.3%.
enum GeoDistance {
    private static let semiMajor = 6_378_137.0
    private static let eccentricitySquared = 0.006_694_379_990_14

    nonisolated static func meters(
        fromLatitude lat1: Double,
        longitude lon1: Double,
        toLatitude lat2: Double,
        longitude lon2: Double
    ) -> Double {
        let toRadians = Double.pi / 180
        let meanLat = (lat1 + lat2) / 2 * toRadians
        let s = sin(meanLat)
        let w = 1 - eccentricitySquared * s * s
        let sqrtW = w.squareRoot()
        let meridional = semiMajor * (1 - eccentricitySquared) / (w * sqrtW)
        let primeVertical = semiMajor / sqrtW

        var dLon = lon2 - lon1
        if dLon > 180 { dLon -= 360 } else if dLon < -180 { dLon += 360 }

        let dy = (lat2 - lat1) * toRadians * meridional
        let dx = dLon * toRadians * primeVertical * cos(meanLat)
        return (dx * dx + dy * dy).squareRoot()
    }
}

/// Value-type projection of a camera for off-main work. `@Model` objects can't cross actors.
struct CameraPoint: Sendable, Equatable, Identifiable {
    let id: String
    let latitude: Double
    let longitude: Double
    let isFlock: Bool
    /// Parsed once from the OSM `direction` tag; nil when absent or unparseable.
    let directionDegrees: Double?
    let manufacturer: String

    init(
        id: String,
        latitude: Double,
        longitude: Double,
        isFlock: Bool,
        directionDegrees: Double? = nil,
        manufacturer: String = "Unknown"
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.isFlock = isFlock
        self.directionDegrees = directionDegrees
        self.manufacturer = manufacturer
    }
}

/// Simple uniform grid over `CameraPoint`s. Viewport and nearest lookups touch only nearby cells
/// instead of scanning every camera. Immutable and `Sendable`: build once per cache change,
/// share freely with detached work.
struct CameraSpatialIndex: Sendable {
    static let cellDegrees = 0.02
    static let empty = CameraSpatialIndex(points: [])

    /// Original (repository) order is preserved so results match the old linear scans.
    let points: [CameraPoint]
    private let cells: [Int: [Int]]
    private let minLatCell: Int
    private let maxLatCell: Int
    private let minLonCell: Int
    private let maxLonCell: Int

    var count: Int { points.count }

    init(points: [CameraPoint]) {
        self.points = points
        var cells: [Int: [Int]] = [:]
        var minLat = Int.max, maxLat = Int.min, minLon = Int.max, maxLon = Int.min
        for (index, point) in points.enumerated() {
            let latCell = Self.cell(point.latitude)
            let lonCell = Self.cell(point.longitude)
            cells[Self.key(latCell, lonCell), default: []].append(index)
            minLat = min(minLat, latCell); maxLat = max(maxLat, latCell)
            minLon = min(minLon, lonCell); maxLon = max(maxLon, lonCell)
        }
        self.cells = cells
        self.minLatCell = points.isEmpty ? 0 : minLat
        self.maxLatCell = points.isEmpty ? 0 : maxLat
        self.minLonCell = points.isEmpty ? 0 : minLon
        self.maxLonCell = points.isEmpty ? 0 : maxLon
    }

    // MARK: Viewport

    /// Points inside the region (inclusive edges, same rule as `GeoHelpers.cameras(in:)`),
    /// in original order.
    func points(in region: MKCoordinateRegion, filter: CameraFilter = .all) -> [CameraPoint] {
        let latMin = region.center.latitude - region.span.latitudeDelta / 2
        let latMax = region.center.latitude + region.span.latitudeDelta / 2
        let lonMin = region.center.longitude - region.span.longitudeDelta / 2
        let lonMax = region.center.longitude + region.span.longitudeDelta / 2
        guard !points.isEmpty, latMin <= latMax, lonMin <= lonMax else { return [] }

        let loLat = max(Self.cell(latMin), minLatCell), hiLat = min(Self.cell(latMax), maxLatCell)
        let loLon = max(Self.cell(lonMin), minLonCell), hiLon = min(Self.cell(lonMax), maxLonCell)
        guard loLat <= hiLat, loLon <= hiLon else { return [] }

        var candidates: [Int] = []
        let spanCells = (hiLat - loLat + 1) * (hiLon - loLon + 1)
        if spanCells > cells.count {
            // Zoomed far out: walking populated cells beats walking the (mostly empty) rectangle.
            for (key, indices) in cells {
                let (latCell, lonCell) = Self.unpack(key)
                if latCell >= loLat, latCell <= hiLat, lonCell >= loLon, lonCell <= hiLon {
                    candidates.append(contentsOf: indices)
                }
            }
        } else {
            for latCell in loLat...hiLat {
                for lonCell in loLon...hiLon {
                    if let indices = cells[Self.key(latCell, lonCell)] { candidates.append(contentsOf: indices) }
                }
            }
        }
        candidates.sort()

        var result: [CameraPoint] = []
        result.reserveCapacity(candidates.count)
        for index in candidates {
            let point = points[index]
            if filter == .flockOnly, !point.isFlock { continue }
            if point.latitude >= latMin, point.latitude <= latMax,
               point.longitude >= lonMin, point.longitude <= lonMax {
                result.append(point)
            }
        }
        return result
    }

    // MARK: Nearest

    /// Nearest point to a coordinate, by `GeoDistance`. Expanding ring search with an exact stop rule;
    /// falls back to a linear pass when the rings would outgrow the populated cells.
    func nearest(
        toLatitude latitude: Double,
        longitude: Double,
        filter: CameraFilter = .all
    ) -> (point: CameraPoint, meters: Double)? {
        guard !points.isEmpty else { return nil }

        var best: (point: CameraPoint, meters: Double)?
        func consider(_ index: Int) {
            let point = points[index]
            if filter == .flockOnly, !point.isFlock { return }
            let meters = GeoDistance.meters(
                fromLatitude: latitude, longitude: longitude,
                toLatitude: point.latitude, longitude: point.longitude
            )
            if best == nil || meters < best!.meters { best = (point, meters) }
        }

        let queryLat = Self.cell(latitude)
        let queryLon = Self.cell(longitude)
        let widest = max(
            abs(queryLat - minLatCell), abs(queryLat - maxLatCell),
            abs(queryLon - minLonCell), abs(queryLon - maxLonCell)
        )
        // Conservative metres per ring: shortest cell edge anywhere the data lives.
        let worstLat = max(abs(Double(minLatCell)), abs(Double(maxLatCell))) * Self.cellDegrees
        let queryAbsLat = abs(latitude)
        let cosLat = max(cos(max(worstLat, queryAbsLat) * .pi / 180), 0.01)
        let ringMeters = Self.cellDegrees * 110_000 * min(1, cosLat)

        var ring = 0
        while ring <= widest {
            // Perimeter of this ring exceeds the populated cells: a linear pass is cheaper.
            if ring > 0, 8 * ring > cells.count {
                for index in points.indices { consider(index) }
                return best
            }
            Self.forEachCell(inRing: ring, aroundLat: queryLat, lon: queryLon) { latCell, lonCell in
                if let indices = cells[Self.key(latCell, lonCell)] {
                    for index in indices { consider(index) }
                }
            }
            // Anything unseen lies in ring >= ring + 1, so it is at least `ring` cells away.
            if let best, best.meters <= Double(ring) * ringMeters { return best }
            ring += 1
        }
        return best
    }

    func nearest(to coordinate: CLLocationCoordinate2D, filter: CameraFilter = .all) -> (point: CameraPoint, meters: Double)? {
        nearest(toLatitude: coordinate.latitude, longitude: coordinate.longitude, filter: filter)
    }

    // MARK: Grid helpers

    private static func cell(_ degrees: Double) -> Int {
        Int((degrees / cellDegrees).rounded(.down))
    }

    private static func key(_ latCell: Int, _ lonCell: Int) -> Int {
        (latCell &+ 100_000) << 20 | ((lonCell &+ 100_000) & 0xFFFFF)
    }

    private static func unpack(_ key: Int) -> (Int, Int) {
        ((key >> 20) - 100_000, (key & 0xFFFFF) - 100_000)
    }

    private static func forEachCell(
        inRing ring: Int,
        aroundLat lat: Int,
        lon: Int,
        _ body: (Int, Int) -> Void
    ) {
        if ring == 0 { body(lat, lon); return }
        for dLon in -ring...ring {
            body(lat - ring, lon + dLon)
            body(lat + ring, lon + dLon)
        }
        if ring >= 1 {
            for dLat in (-ring + 1)...(ring - 1) {
                body(lat + dLat, lon - ring)
                body(lat + dLat, lon + ring)
            }
        }
    }
}

extension ALPRCamera {
    /// Plain-value projection for the spatial index. `isFlock` decodes tags, so build this once per
    /// cache change, never per frame.
    var point: CameraPoint {
        CameraPoint(
            id: id,
            latitude: latitude,
            longitude: longitude,
            isFlock: isFlock,
            directionDegrees: GeoHelpers.directionDegrees(from: direction),
            manufacturer: displayManufacturer
        )
    }
}
