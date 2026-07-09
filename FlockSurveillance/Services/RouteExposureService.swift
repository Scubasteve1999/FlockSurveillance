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

enum RouteExposureService {
    static func directions(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> MKRoute {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        guard let route = response.routes.first else {
            throw NSError(domain: "RouteExposure", code: 1, userInfo: [NSLocalizedDescriptionKey: "No driving route found."])
        }
        return route
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
