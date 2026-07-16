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

    /// Hosts permitted for traveler still fetches (Sensor Atlas detail only).
    static let allowedImageHosts: Set<String> = [
        "content.dot.wi.gov",
        "www.dot.wi.gov",
    ]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? id : trimmed
    }

    var displayHighway: String? {
        let trimmed = highway.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Resolved still URL if HTTPS + allowlisted host; otherwise nil (no fetch).
    var resolvedImageURL: URL? {
        guard let raw = imageURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if raw.lowercased().contains("pull.web") {
            return nil
        }
        // Reject explicit cleartext; schemeless hosts are upgraded to https.
        if raw.lowercased().hasPrefix("http://") {
            return nil
        }
        let absolute = raw.hasPrefix("https://") ? raw : "https://\(raw)"
        guard let url = URL(string: absolute),
              url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased()
        else {
            return nil
        }
        guard Self.allowedImageHosts.contains(host) else {
            return nil
        }
        return url
    }
}

struct SensorAtlasBundle: Codable, Sendable {
    let version: Int
    let updated: String
    let attribution: String
    let sensors: [PublicSensor]
}
