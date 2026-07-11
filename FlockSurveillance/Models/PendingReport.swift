import CoreLocation
import Foundation
import SwiftData

enum PendingReportStatus: String, Codable, CaseIterable {
    case pending
    case open
    case closed
    case landed
    case failed

    var displayLabel: String {
        switch self {
        case .pending: return "Submitting"
        case .open: return "Awaiting mappers"
        case .closed: return "Note closed"
        case .landed: return "On the map"
        case .failed: return "Failed"
        }
    }
}

@Model
final class PendingReport {
    @Attribute(.unique) var id: UUID
    var osmNoteID: Int?
    var kindRaw: String
    var latitude: Double
    var longitude: Double
    var existingCameraID: String?
    var direction: String?
    var mountType: String?
    var operatorGuess: String?
    var notes: String?
    var createdAt: Date
    var statusRaw: String
    var lastCheckedAt: Date?
    var landedCameraID: String?
    /// Camera IDs already within landing radius at submit time — ignored for "landed".
    var baselineCameraIDsJSON: String = "[]"
    /// User hid the optimistic pin without closing the OSM note.
    var hiddenFromMap: Bool = false

    init(
        id: UUID = UUID(),
        osmNoteID: Int? = nil,
        kind: OSMReportKind,
        latitude: Double,
        longitude: Double,
        existingCameraID: String? = nil,
        direction: String? = nil,
        mountType: String? = nil,
        operatorGuess: String? = nil,
        notes: String? = nil,
        createdAt: Date = .now,
        status: PendingReportStatus = .open,
        lastCheckedAt: Date? = nil,
        landedCameraID: String? = nil,
        baselineCameraIDs: [String] = [],
        hiddenFromMap: Bool = false
    ) {
        self.id = id
        self.osmNoteID = osmNoteID
        self.kindRaw = kind.rawValue
        self.latitude = latitude
        self.longitude = longitude
        self.existingCameraID = existingCameraID
        self.direction = direction
        self.mountType = mountType
        self.operatorGuess = operatorGuess
        self.notes = notes
        self.createdAt = createdAt
        self.statusRaw = status.rawValue
        self.lastCheckedAt = lastCheckedAt
        self.landedCameraID = landedCameraID
        if let data = try? JSONEncoder().encode(baselineCameraIDs),
           let json = String(data: data, encoding: .utf8) {
            self.baselineCameraIDsJSON = json
        } else {
            self.baselineCameraIDsJSON = "[]"
        }
        self.hiddenFromMap = hiddenFromMap
    }

    var kind: OSMReportKind {
        get { OSMReportKind(rawValue: kindRaw) ?? .newCamera }
        set { kindRaw = newValue.rawValue }
    }

    var status: PendingReportStatus {
        get { PendingReportStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    var osmNoteURL: URL? {
        guard let osmNoteID else { return nil }
        return URL(string: "https://www.openstreetmap.org/note/\(osmNoteID)")
    }

    var baselineCameraIDs: Set<String> {
        guard let data = baselineCameraIDsJSON.data(using: .utf8),
              let ids = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(ids)
    }

    var showsOnMap: Bool {
        switch status {
        case .open, .pending:
            return kind == .newCamera && !hiddenFromMap
        case .closed, .landed, .failed:
            return false
        }
    }

    var statusSubtitle: String {
        switch kind {
        case .newCamera:
            return status == .landed ? "Camera mapped nearby" : "Unmapped camera report"
        case .wrongInfo:
            return "Correction report"
        case .removed:
            return "Removal report"
        }
    }
}


// Identifiable for sheet(item:) / ForEach.
extension PendingReport: Identifiable {}
