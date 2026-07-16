import CoreLocation
import Foundation
import MapKit

@MainActor
@Observable
final class SensorAtlasStore {
    private(set) var bundle: SensorAtlasBundle?
    private(set) var loadError: String?
    private(set) var isLoaded = false

    func loadIfNeeded(
        resourceName: String = "SensorAtlasBundle",
        from resourceBundle: Bundle = .main
    ) {
        guard !isLoaded else { return }
        do {
            bundle = try Self.loadBundle(from: resourceBundle, resourceName: resourceName)
            isLoaded = true
            loadError = nil
        } catch {
            bundle = nil
            isLoaded = false
            loadError = error.localizedDescription
        }
    }

    /// Test helper.
    func applyLoadedBundle(_ bundle: SensorAtlasBundle) {
        self.bundle = bundle
        isLoaded = true
        loadError = nil
    }

    var attribution: String? { bundle?.attribution }

    /// Sensors in the viewport, nearest to center first, capped to limit map annotations.
    func sensors(in region: MKCoordinateRegion, limit: Int = 60) -> [PublicSensor] {
        guard let sensors = bundle?.sensors, limit > 0 else { return [] }
        let halfLat = region.span.latitudeDelta / 2
        let halfLon = region.span.longitudeDelta / 2
        let minLat = region.center.latitude - halfLat
        let maxLat = region.center.latitude + halfLat
        let minLon = region.center.longitude - halfLon
        let maxLon = region.center.longitude + halfLon
        let center = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        return sensors
            .filter {
                $0.latitude >= minLat && $0.latitude <= maxLat
                    && $0.longitude >= minLon && $0.longitude <= maxLon
            }
            .sorted {
                let d0 = center.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
                let d1 = center.distance(from: CLLocation(latitude: $1.latitude, longitude: $1.longitude))
                return d0 < d1
            }
            .prefix(limit)
            .map { $0 }
    }

    nonisolated static func loadBundle(
        from resourceBundle: Bundle,
        resourceName: String
    ) throws -> SensorAtlasBundle {
        guard let url = resourceBundle.url(forResource: resourceName, withExtension: "json") else {
            throw SensorAtlasStoreError.missingResource
        }
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(SensorAtlasBundle.self, from: data)
        try validate(decoded)
        return decoded
    }

    /// Rejects ship-blocking inventory defects (blank names, live-pull URLs, bad hosts).
    nonisolated static func validate(_ bundle: SensorAtlasBundle) throws {
        guard !bundle.sensors.isEmpty else {
            throw SensorAtlasStoreError.invalidBundle("Sensor Atlas bundle has no sensors.")
        }
        var seen = Set<String>()
        for sensor in bundle.sensors {
            let id = sensor.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, !id.contains(" ") else {
                throw SensorAtlasStoreError.invalidBundle("Invalid sensor id: \(sensor.id)")
            }
            guard seen.insert(id).inserted else {
                throw SensorAtlasStoreError.invalidBundle("Duplicate sensor id: \(id)")
            }
            let name = sensor.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                throw SensorAtlasStoreError.invalidBundle("Blank name for sensor \(id)")
            }
            if let raw = sensor.imageURL?.lowercased(), raw.contains("pull.web") {
                throw SensorAtlasStoreError.invalidBundle("Live-pull URL not allowed for \(id)")
            }
            if sensor.imageURL != nil, sensor.resolvedImageURL == nil {
                throw SensorAtlasStoreError.invalidBundle("Image host not allowlisted for \(id)")
            }
        }
    }
}

enum SensorAtlasStoreError: LocalizedError {
    case missingResource
    case invalidBundle(String)

    var errorDescription: String? {
        switch self {
        case .missingResource:
            return "Sensor Atlas data is missing from the app bundle."
        case .invalidBundle(let reason):
            return reason
        }
    }
}
