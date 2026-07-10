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
    /// - Parameter collapseContinental: When true (map pan/zoom), huge regions sample only the center tile.
    ///   When false (route analysis), keep tiling so long drives aren't under-fetched.
    static func queryTiles(
        for region: MKCoordinateRegion,
        collapseContinental: Bool = true,
        maxTiles: Int = maxTilesPerFetch
    ) -> [MKCoordinateRegion] {
        let latSpan = max(region.span.latitudeDelta, 0.01)
        let lonSpan = max(region.span.longitudeDelta, 0.01)

        if latSpan <= maxQuerySpanDegrees, lonSpan <= maxQuerySpanDegrees {
            return [region]
        }

        if collapseContinental, dominantSpan(region) > maxTileableSpanDegrees {
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

        let maxAxisTiles = collapseContinental ? 3 : 6
        let latTiles = min(maxAxisTiles, max(1, Int(ceil(latSpan / maxQuerySpanDegrees))))
        let lonTiles = min(maxAxisTiles, max(1, Int(ceil(lonSpan / maxQuerySpanDegrees))))
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
                if tiles.count >= maxTiles { return tiles }
            }
        }
        return tiles
    }

    static func region(for route: MKRoute, padding: Double = 1.25) -> MKCoordinateRegion {
        var region = MKCoordinateRegion(route.polyline.boundingMapRect)
        region.span.latitudeDelta = max(region.span.latitudeDelta * padding, 0.02)
        region.span.longitudeDelta = max(region.span.longitudeDelta * padding, 0.02)
        return region
    }

    /// Bearing degrees (0–360) from OSM direction tags, if parseable.
    static func directionDegrees(from raw: String?) -> Double? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if let value = Double(raw) {
            return (value.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        }
        let cardinals: [String: Double] = [
            "n": 0, "nne": 22.5, "ne": 45, "ene": 67.5,
            "e": 90, "ese": 112.5, "se": 135, "sse": 157.5,
            "s": 180, "ssw": 202.5, "sw": 225, "wsw": 247.5,
            "w": 270, "wnw": 292.5, "nw": 315, "nnw": 337.5
        ]
        return cardinals[raw.lowercased()]
    }

    /// Wedge polygon for a camera FOV cone (bearing center, half-angle, radius meters).
    static func fovPolygon(
        center: CLLocationCoordinate2D,
        bearingDegrees: Double,
        halfAngleDegrees: Double = 35,
        radiusMeters: CLLocationDistance = 90,
        samples: Int = 12
    ) -> [CLLocationCoordinate2D] {
        var coords = [center]
        let start = bearingDegrees - halfAngleDegrees
        let end = bearingDegrees + halfAngleDegrees
        for index in 0...samples {
            let t = Double(index) / Double(samples)
            let bearing = start + (end - start) * t
            coords.append(destination(from: center, distanceMeters: radiusMeters, bearingDegrees: bearing))
        }
        coords.append(center)
        return coords
    }

    /// Initial great-circle bearing in degrees (0–360, 0 = north) from one point to another.
    static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let degrees = atan2(y, x) * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    static func destination(
        from coordinate: CLLocationCoordinate2D,
        distanceMeters: CLLocationDistance,
        bearingDegrees: Double
    ) -> CLLocationCoordinate2D {
        let earthRadius = 6_371_000.0
        let angular = distanceMeters / earthRadius
        let bearing = bearingDegrees * .pi / 180
        let lat1 = coordinate.latitude * .pi / 180
        let lon1 = coordinate.longitude * .pi / 180
        let lat2 = asin(sin(lat1) * cos(angular) + cos(lat1) * sin(angular) * cos(bearing))
        let lon2 = lon1 + atan2(
            sin(bearing) * sin(angular) * cos(lat1),
            cos(angular) - sin(lat1) * sin(lat2)
        )
        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }

    static func placeScore(
        cameras: [ALPRCamera],
        near coordinate: CLLocationCoordinate2D,
        radiusMeters: CLLocationDistance
    ) -> PlaceScore {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let nearby = cameras.filter { $0.location.distance(from: origin) <= radiusMeters }
        let flock = nearby.filter(\.isFlock).count
        let radiusMiles = radiusMeters / 1609.34
        let areaSqMi = max(radiusMiles * radiusMiles * Double.pi, 0.01)
        let perSqMi = Double(nearby.count) / areaSqMi
        let grade: String
        switch nearby.count {
        case 0: grade = "Clear"
        case 1...4: grade = "Light"
        case 5...14: grade = "Watched"
        case 15...29: grade = "Heavy"
        default: grade = "Saturated"
        }
        let flockPercent: Int
        if nearby.isEmpty {
            flockPercent = 0
        } else {
            flockPercent = Int((Double(flock) / Double(nearby.count) * 100).rounded())
        }
        return PlaceScore(
            coordinate: coordinate,
            radiusMeters: radiusMeters,
            cameraCount: nearby.count,
            flockCount: flock,
            flockPercent: flockPercent,
            densityPerSquareMile: perSqMi,
            grade: grade
        )
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

    /// Rank seed metros by how many cached cameras fall in each metro tile.
    static func cityRankings(from cameras: [ALPRCamera], limit: Int = 5) -> [CityRanking] {
        let ranked = seedMetros.compactMap { metro -> CityRanking? in
            let region = seedRegion(for: metro.coordinate)
            let count = Self.cameras(in: region, from: cameras).count
            guard count > 0 else { return nil }
            return CityRanking(name: metro.name, coordinate: metro.coordinate, cameraCount: count)
        }
        .sorted { $0.cameraCount > $1.cameraCount }
        return Array(ranked.prefix(limit))
    }
}

struct CityRanking: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let coordinate: CLLocationCoordinate2D
    let cameraCount: Int

    var subtitle: String {
        cameraCount == 1 ? "1 mapped camera" : "\(cameraCount) mapped cameras"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(cameraCount)
    }

    static func == (lhs: CityRanking, rhs: CityRanking) -> Bool {
        lhs.name == rhs.name && lhs.cameraCount == rhs.cameraCount
    }
}

struct PlaceScore: Identifiable, Equatable, Hashable {
    var id: String {
        String(format: "%.4f:%.4f:%.0f:%d", coordinate.latitude, coordinate.longitude, radiusMeters, cameraCount)
    }

    let coordinate: CLLocationCoordinate2D
    let radiusMeters: CLLocationDistance
    let cameraCount: Int
    let flockCount: Int
    let flockPercent: Int
    let densityPerSquareMile: Double
    let grade: String

    var radiusMilesLabel: String {
        let miles = radiusMeters / 1609.34
        if miles < 1.05 { return "1 mi" }
        return String(format: "%.0f mi", miles)
    }

    /// Mainstream headline: "Your block is Watched"
    var headline: String {
        switch grade {
        case "Clear": return "Your block looks clear"
        case "Light": return "Your block is lightly watched"
        case "Watched": return "Your block is watched"
        case "Heavy": return "Your block is heavily watched"
        default: return "Your block is saturated with cameras"
        }
    }

    var cameraCountLabel: String {
        cameraCount == 1 ? "1 camera" : "\(cameraCount) cameras"
    }

    var shareText: String {
        """
        Flock Surveillance
        \(headline)
        \(cameraCountLabel) within \(radiusMilesLabel) (\(flockCount) Flock · \(flockPercent)%)
        Density: \(String(format: "%.1f", densityPerSquareMile)) per sq mi
        How watched is your life right now?
        Approximate map link opens the same block.
        flocksurveillance.com
        """
    }

    var mapDeepLink: URL? {
        // ~100 m precision — enough to open the same block without sharing exact GPS.
        URL(string: String(
            format: "flocksurveillance://map?lat=%.3f&lon=%.3f",
            coordinate.latitude,
            coordinate.longitude
        ))
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PlaceScore, rhs: PlaceScore) -> Bool {
        lhs.id == rhs.id
    }
}
