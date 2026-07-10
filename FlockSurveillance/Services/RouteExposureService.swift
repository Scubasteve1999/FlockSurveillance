import CoreLocation
import Foundation
import MapKit

struct RouteExposureResult: Identifiable {
    let id = UUID()
    let route: MKRoute
    let cameras: [(camera: ALPRCamera, metersFromStart: CLLocationDistance)]
    let corridorMeters: CLLocationDistance

    var cameraCount: Int { cameras.count }
    var flockCount: Int { cameras.filter { $0.camera.isFlock }.count }

    var exposureScore: String {
        switch cameraCount {
        case 0: return "Clear"
        case 1...3: return "Light"
        case 4...9: return "Elevated"
        default: return "Heavy"
        }
    }
}

struct RankedRouteExposure: Identifiable {
    let id = UUID()
    let result: RouteExposureResult
    let isRecommended: Bool

    var cameraCount: Int { result.cameraCount }
    var distance: CLLocationDistance { result.route.distance }
}

struct RouteExposureAnalysis {
    let options: [RankedRouteExposure]
    var recommended: RouteExposureResult? { options.first(where: \.isRecommended)?.result ?? options.first?.result }
}

enum RouteExposureService {
    static func directions(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        requestAlternates: Bool = true
    ) async throws -> [MKRoute] {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        request.requestsAlternateRoutes = requestAlternates

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        guard !response.routes.isEmpty else {
            throw NSError(domain: "RouteExposure", code: 1, userInfo: [NSLocalizedDescriptionKey: "No driving route found."])
        }
        return response.routes
    }

    static func exposure(
        route: MKRoute,
        cameras: [ALPRCamera],
        corridorMeters: CLLocationDistance = 75
    ) -> RouteExposureResult {
        let points = route.polyline.coordinates
        var hits: [(camera: ALPRCamera, metersFromStart: CLLocationDistance)] = []

        for camera in cameras {
            if let distanceAlong = distanceAlongPolyline(to: camera.coordinate, points: points, corridorMeters: corridorMeters) {
                hits.append((camera, distanceAlong))
            }
        }

        hits.sort { $0.metersFromStart < $1.metersFromStart }
        return RouteExposureResult(route: route, cameras: hits, corridorMeters: corridorMeters)
    }

    /// Scores MapKit routes by ALPR corridor hits, then distance. Lowest exposure wins.
    static func analyze(
        routes: [MKRoute],
        cameras: [ALPRCamera],
        corridorMeters: CLLocationDistance = 75,
        maxOptions: Int = 3
    ) -> RouteExposureAnalysis {
        let scored = routes.map { exposure(route: $0, cameras: cameras, corridorMeters: corridorMeters) }
        let ranked = rank(scored).prefix(maxOptions)
        let options = ranked.enumerated().map { index, result in
            RankedRouteExposure(result: result, isRecommended: index == 0)
        }
        return RouteExposureAnalysis(options: Array(options))
    }

    /// Pure ranking helper for tests: fewest cameras, then shorter distance.
    static func rank(_ results: [RouteExposureResult]) -> [RouteExposureResult] {
        results.sorted { lhs, rhs in
            if lhs.cameraCount != rhs.cameraCount {
                return lhs.cameraCount < rhs.cameraCount
            }
            return lhs.route.distance < rhs.route.distance
        }
    }

    /// Testable ranking on lightweight metrics (avoids constructing MKRoute in unit tests).
    static func rankByMetrics(_ metrics: [(cameraCount: Int, distance: CLLocationDistance)]) -> [Int] {
        metrics.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.cameraCount != rhs.element.cameraCount {
                    return lhs.element.cameraCount < rhs.element.cameraCount
                }
                return lhs.element.distance < rhs.element.distance
            }
            .map(\.offset)
    }

    /// Returns distance along the polyline when the coordinate is within `corridorMeters` of the path.
    static func distanceAlongPolyline(
        to coordinate: CLLocationCoordinate2D,
        points: [CLLocationCoordinate2D],
        corridorMeters: CLLocationDistance
    ) -> CLLocationDistance? {
        guard points.count >= 2 else { return nil }
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var traveled: CLLocationDistance = 0
        var bestDistance = CLLocationDistance.greatestFiniteMagnitude
        var bestAlong: CLLocationDistance = 0

        for index in 0..<(points.count - 1) {
            let a = points[index]
            let b = points[index + 1]
            let aLoc = CLLocation(latitude: a.latitude, longitude: a.longitude)
            let bLoc = CLLocation(latitude: b.latitude, longitude: b.longitude)
            let segmentLength = aLoc.distance(from: bLoc)
            let projection = project(point: target, onto: aLoc, b: bLoc)
            let distance = target.distance(from: projection.location)

            if distance < bestDistance {
                bestDistance = distance
                bestAlong = traveled + projection.distanceFromA
            }
            traveled += segmentLength
        }

        return bestDistance <= corridorMeters ? bestAlong : nil
    }

    private static func project(point: CLLocation, onto a: CLLocation, b: CLLocation) -> (location: CLLocation, distanceFromA: CLLocationDistance) {
        let ax = a.coordinate.longitude
        let ay = a.coordinate.latitude
        let bx = b.coordinate.longitude
        let by = b.coordinate.latitude
        let px = point.coordinate.longitude
        let py = point.coordinate.latitude

        let dx = bx - ax
        let dy = by - ay
        if dx == 0, dy == 0 {
            return (a, 0)
        }

        let t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
        let lat = ay + t * dy
        let lon = ax + t * dx
        let projected = CLLocation(latitude: lat, longitude: lon)
        return (projected, a.distance(from: projected))
    }
}

extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = Array(repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
