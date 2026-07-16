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

    func sensors(in region: MKCoordinateRegion, limit: Int = 80) -> [PublicSensor] {
        guard let sensors = bundle?.sensors, limit > 0 else { return [] }
        let halfLat = region.span.latitudeDelta / 2
        let halfLon = region.span.longitudeDelta / 2
        let minLat = region.center.latitude - halfLat
        let maxLat = region.center.latitude + halfLat
        let minLon = region.center.longitude - halfLon
        let maxLon = region.center.longitude + halfLon
        return sensors
            .filter {
                $0.latitude >= minLat && $0.latitude <= maxLat
                    && $0.longitude >= minLon && $0.longitude <= maxLon
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
        return try JSONDecoder().decode(SensorAtlasBundle.self, from: data)
    }
}

enum SensorAtlasStoreError: LocalizedError {
    case missingResource

    var errorDescription: String? {
        switch self {
        case .missingResource:
            return "Sensor Atlas data is missing from the app bundle."
        }
    }
}
