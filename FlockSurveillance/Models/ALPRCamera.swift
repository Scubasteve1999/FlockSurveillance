import CoreLocation
import Foundation
import SwiftData

@Model
final class ALPRCamera {
    @Attribute(.unique) var id: String
    var latitude: Double
    var longitude: Double
    var manufacturer: String?
    var operatorName: String?
    var direction: String?
    var cameraName: String?
    var tagsJSON: String
    var fetchedAt: Date
    /// Soft-hidden after a confirmed removal report (device-local).
    var isHidden: Bool = false
    /// Soft-absent after a successful covering fetch no longer returned this OSM id.
    var isAbsentFromOSM: Bool = false

    init(
        id: String,
        latitude: Double,
        longitude: Double,
        manufacturer: String? = nil,
        operatorName: String? = nil,
        direction: String? = nil,
        cameraName: String? = nil,
        tagsJSON: String = "{}",
        fetchedAt: Date = .now,
        isHidden: Bool = false,
        isAbsentFromOSM: Bool = false
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.manufacturer = manufacturer
        self.operatorName = operatorName
        self.direction = direction
        self.cameraName = cameraName
        self.tagsJSON = tagsJSON
        self.fetchedAt = fetchedAt
        self.isHidden = isHidden
        self.isAbsentFromOSM = isAbsentFromOSM
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    var isFlock: Bool {
        ALPRIdentity.isFlock(
            manufacturer: manufacturer,
            operatorName: operatorName,
            cameraName: cameraName,
            tagsJSON: tagsJSON
        )
    }

    var displayManufacturer: String {
        if let manufacturer, !manufacturer.isEmpty { return manufacturer }
        return isFlock ? "Flock Safety" : "Unknown"
    }

    var displayTitle: String {
        if let cameraName, !cameraName.isEmpty { return cameraName }
        return displayManufacturer
    }
}

/// Shared Flock / brand heuristics for DTO + SwiftData model.
enum ALPRIdentity {
    static func isFlock(
        manufacturer: String?,
        operatorName: String?,
        cameraName: String?,
        tagsJSON: String? = nil
    ) -> Bool {
        let fields = [manufacturer, operatorName, cameraName].compactMap { $0 }
        if fields.contains(where: { $0.lowercased().contains("flock") }) {
            return true
        }
        guard let tagsJSON,
              let data = tagsJSON.data(using: .utf8),
              let tags = try? JSONDecoder().decode([String: String].self, from: data)
        else { return false }
        let brandKeys = ["manufacturer", "brand", "operator", "name", "ref"]
        return brandKeys.contains { key in
            (tags[key] ?? "").lowercased().contains("flock")
        }
    }
}

enum CameraFilter: String, CaseIterable, Identifiable {
    case all = "All ALPRs"
    case flockOnly = "Flock only"

    var id: String { rawValue }
}

struct CameraCluster: Identifiable, Hashable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let cameras: [ALPRCamera]
    let isFlockDominant: Bool

    var count: Int { cameras.count }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CameraCluster, rhs: CameraCluster) -> Bool {
        lhs.id == rhs.id
    }
}
