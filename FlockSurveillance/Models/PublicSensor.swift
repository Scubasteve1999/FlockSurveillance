import CoreLocation
import Foundation

/// Public non-ALPR sensor (e.g. municipal traffic CCTV). Never used for geofence alerts.
struct PublicSensor: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let name: String
    let highway: String
    let latitude: Double
    let longitude: Double
    let source: String
    let city: String
    let imageURL: String?
    let kind: String
    let disclaimer: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var resolvedImageURL: URL? {
        guard let raw = imageURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            return URL(string: raw)
        }
        return URL(string: "https://\(raw)")
    }
}

struct SensorAtlasBundle: Codable, Sendable {
    let version: Int
    let updated: String
    let attribution: String
    let sensors: [PublicSensor]
}
