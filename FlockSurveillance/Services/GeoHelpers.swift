import CoreLocation
import Foundation
import MapKit

enum GeoHelpers {
    /// Roughly a metro-sized Overpass bbox — larger requests frequently timeout or return empty.
    static let maxQuerySpanDegrees: Double = 0.45
    /// Above this, we stop tiling the full viewport and ask the user to zoom in.
    static let maxTileableSpanDegrees: Double = 2.4
    static let maxTilesPerFetch = 9

    static func cameras(
        in region: MKCoordinateRegion,
        from cameras: [ALPRCamera],
        filter: CameraFilter = .all
    ) -> [ALPRCamera] {
        let latMin = region.center.latitude - region.span.latitudeDelta / 2
        let latMax = region.center.latitude + region.span.latitudeDelta / 2
        let lonMin = region.center.longitude - region.span.longitudeDelta / 2
        let lonMax = region.center.longitude + region.span.longitudeDelta / 2

        let base: [ALPRCamera]
        switch filter {
        case .all: base = cameras
        case .flockOnly: base = cameras.filter(\.isFlock)
        }

        return base.filter {
            $0.latitude >= latMin && $0.latitude <= latMax &&
            $0.longitude >= lonMin && $0.longitude <= lonMax
        }
    }

    static func clusters(
        for filter: CameraFilter,
        in region: MKCoordinateRegion,
        from cameras: [ALPRCamera]
    ) -> [CameraCluster] {
        let inView = Self.cameras(in: region, from: cameras, filter: filter)
        let span = max(region.span.latitudeDelta, region.span.longitudeDelta)
        // Larger cells when zoomed out so markers spread across cities instead of one mega-pin.
        let cellSize = max(span / 12, 0.0008)
        var buckets: [String: [ALPRCamera]] = [:]

        for camera in inView {
            let latBucket = Int((camera.latitude / cellSize).rounded(.down))
            let lonBucket = Int((camera.longitude / cellSize).rounded(.down))
            let key = "\(latBucket):\(lonBucket)"
            buckets[key, default: []].append(camera)
        }

        return buckets.compactMap { key, group in
            guard !group.isEmpty else { return nil }
            let lat = group.map(\.latitude).reduce(0, +) / Double(group.count)
            let lon = group.map(\.longitude).reduce(0, +) / Double(group.count)
            let flockCount = group.filter(\.isFlock).count
            return CameraCluster(
                id: key,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                cameras: group,
                isFlockDominant: flockCount >= group.count - flockCount
            )
        }
    }

    static func relativeFreshness(from date: Date?, now: Date = .now) -> String? {
        guard let date else { return nil }
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "Updated just now" }
        if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "Updated \(minutes)m ago"
        }
        if seconds < 86_400 {
            let hours = Int(seconds / 3600)
            return "Updated \(hours)h ago"
        }
        let days = Int(seconds / 86_400)
        return "Updated \(days)d ago"
    }

    static func mapRect(covering coordinates: [CLLocationCoordinate2D], paddingFactor: Double = 1.25) -> MKMapRect? {
        guard !coordinates.isEmpty else { return nil }
        var rect = MKMapRect.null
        for coordinate in coordinates {
            let point = MKMapPoint(coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1)
            rect = rect.union(pointRect)
        }
        let padX = rect.size.width * (paddingFactor - 1) / 2
        let padY = rect.size.height * (paddingFactor - 1) / 2
        return rect.insetBy(dx: -max(padX, 200), dy: -max(padY, 200))
    }

    static func dominantSpan(_ region: MKCoordinateRegion) -> Double {
        max(region.span.latitudeDelta, region.span.longitudeDelta)
    }

    static func isRegionTooLargeForFullFetch(_ region: MKCoordinateRegion) -> Bool {
        dominantSpan(region) > maxTileableSpanDegrees
    }

    /// Split a viewport into Overpass-safe tiles (≤ maxQuerySpanDegrees), capped at maxTilesPerFetch.
    static func queryTiles(for region: MKCoordinateRegion) -> [MKCoordinateRegion] {
        let latSpan = max(region.span.latitudeDelta, 0.01)
        let lonSpan = max(region.span.longitudeDelta, 0.01)

        if latSpan <= maxQuerySpanDegrees, lonSpan <= maxQuerySpanDegrees {
            return [region]
        }

        if dominantSpan(region) > maxTileableSpanDegrees {
            // Continental / country zooms: only sample the viewport center metro tile.
            return [
                MKCoordinateRegion(
                    center: region.center,
                    span: MKCoordinateSpan(
                        latitudeDelta: maxQuerySpanDegrees,
                        longitudeDelta: maxQuerySpanDegrees
                    )
                )
            ]
        }

        let latTiles = min(3, max(1, Int(ceil(latSpan / maxQuerySpanDegrees))))
        let lonTiles = min(3, max(1, Int(ceil(lonSpan / maxQuerySpanDegrees))))
        let tileLat = latSpan / Double(latTiles)
        let tileLon = lonSpan / Double(lonTiles)
        let originLat = region.center.latitude - latSpan / 2
        let originLon = region.center.longitude - lonSpan / 2

        var tiles: [MKCoordinateRegion] = []
        for row in 0..<latTiles {
            for col in 0..<lonTiles {
                let center = CLLocationCoordinate2D(
                    latitude: originLat + (Double(row) + 0.5) * tileLat,
                    longitude: originLon + (Double(col) + 0.5) * tileLon
                )
                tiles.append(
                    MKCoordinateRegion(
                        center: center,
                        span: MKCoordinateSpan(latitudeDelta: tileLat, longitudeDelta: tileLon)
                    )
                )
                if tiles.count >= maxTilesPerFetch { return tiles }
            }
        }
        return tiles
    }

    /// Major US metros to warm the local cache so zoomed-out maps aren't a single-city island.
    static let seedMetros: [(name: String, coordinate: CLLocationCoordinate2D)] = [
        ("Los Angeles", CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)),
        ("New York", CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)),
        ("Chicago", CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298)),
        ("Houston", CLLocationCoordinate2D(latitude: 29.7604, longitude: -95.3698)),
        ("Phoenix", CLLocationCoordinate2D(latitude: 33.4484, longitude: -112.0740)),
        ("Philadelphia", CLLocationCoordinate2D(latitude: 39.9526, longitude: -75.1652)),
        ("Dallas", CLLocationCoordinate2D(latitude: 32.7767, longitude: -96.7970)),
        ("San Francisco", CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)),
        ("Seattle", CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321)),
        ("Denver", CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)),
        ("Washington DC", CLLocationCoordinate2D(latitude: 38.9072, longitude: -77.0369)),
        ("Boston", CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589)),
        ("Atlanta", CLLocationCoordinate2D(latitude: 33.7490, longitude: -84.3880)),
        ("Miami", CLLocationCoordinate2D(latitude: 25.7617, longitude: -80.1918)),
        ("Detroit", CLLocationCoordinate2D(latitude: 42.3314, longitude: -83.0458)),
        ("Minneapolis", CLLocationCoordinate2D(latitude: 44.9778, longitude: -93.2650)),
        ("Las Vegas", CLLocationCoordinate2D(latitude: 36.1699, longitude: -115.1398)),
        ("Portland", CLLocationCoordinate2D(latitude: 45.5152, longitude: -122.6784)),
        ("Charlotte", CLLocationCoordinate2D(latitude: 35.2271, longitude: -80.8431)),
        ("Nashville", CLLocationCoordinate2D(latitude: 36.1627, longitude: -86.7816)),
        ("Austin", CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431)),
        ("San Diego", CLLocationCoordinate2D(latitude: 32.7157, longitude: -117.1611)),
        ("Orlando", CLLocationCoordinate2D(latitude: 28.5383, longitude: -81.3792)),
        ("Kansas City", CLLocationCoordinate2D(latitude: 39.0997, longitude: -94.5786))
    ]

    static func seedRegion(for coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.28, longitudeDelta: 0.28)
        )
    }
}
