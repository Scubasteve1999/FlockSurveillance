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

    init(
        id: String,
        latitude: Double,
        longitude: Double,
        manufacturer: String? = nil,
        operatorName: String? = nil,
        direction: String? = nil,
        cameraName: String? = nil,
        tagsJSON: String = "{}",
        fetchedAt: Date = .now
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
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    var isFlock: Bool {
        let m = (manufacturer ?? "").lowercased()
        return m.contains("flock")
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
