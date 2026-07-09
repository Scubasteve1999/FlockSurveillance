import CoreLocation
import Foundation
import MapKit

enum GeoHelpers {
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
        let cellSize = max(span / 18, 0.0008)
        var buckets: [String: [ALPRCamera]] = [:]

        for camera in inView {
            let latBucket = Int(camera.latitude / cellSize)
            let lonBucket = Int(camera.longitude / cellSize)
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
}
