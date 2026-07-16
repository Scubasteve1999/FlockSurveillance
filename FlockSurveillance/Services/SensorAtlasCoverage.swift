import CoreLocation
import Foundation

/// Metro footprints where Sensor Atlas has a dense bundled inventory.
enum SensorAtlasCoverage {
    struct Metro: Sendable, Equatable {
        let name: String
        let minLatitude: Double
        let minLongitude: Double
        let maxLatitude: Double
        let maxLongitude: Double

        func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
            coordinate.latitude >= minLatitude
                && coordinate.latitude <= maxLatitude
                && coordinate.longitude >= minLongitude
                && coordinate.longitude <= maxLongitude
        }
    }

    /// Matches the Madison / Milwaukee boxes used to build `SensorAtlasBundle.json`.
    static let metros: [Metro] = [
        Metro(
            name: "Madison",
            minLatitude: 43.0,
            minLongitude: -89.55,
            maxLatitude: 43.18,
            maxLongitude: -89.25
        ),
        Metro(
            name: "Milwaukee",
            minLatitude: 42.90,
            minLongitude: -88.10,
            maxLatitude: 43.20,
            maxLongitude: -87.85
        ),
    ]

    static func metro(containing coordinate: CLLocationCoordinate2D) -> Metro? {
        metros.first { $0.contains(coordinate) }
    }

    static func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        metro(containing: coordinate) != nil
    }
}
