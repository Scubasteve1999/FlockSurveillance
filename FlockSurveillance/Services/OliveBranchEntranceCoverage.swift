import CoreLocation
import Foundation

/// Home-market footprint for the Olive Branch entrance reconstruction layer.
enum OliveBranchEntranceCoverage {
    /// Padded OSM relation 1832800 box so the west/south limit crossings still count.
    static let region = CoverageBox(
        name: "Olive Branch",
        minLatitude: 34.88,
        minLongitude: -89.96,
        maxLatitude: 35.03,
        maxLongitude: -89.72
    )

    struct CoverageBox: Sendable, Equatable {
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

    static func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        region.contains(coordinate)
    }
}
