import CoreLocation
import Foundation

enum OSMReportKind: String, CaseIterable, Identifiable {
    case newCamera = "New camera"
    case wrongInfo = "Incorrect info"
    case removed = "Camera removed"

    var id: String { rawValue }
}

struct OSMCameraReport {
    let kind: OSMReportKind
    let coordinate: CLLocationCoordinate2D
    /// OSM element id (e.g. "node/123" or app id "osm-node-123") when reporting an existing camera.
    let existingCameraID: String?
    let direction: String?
    let mountType: String?
    let operatorGuess: String?
    let notes: String?

    /// Structured note body so OSM mappers can act on it quickly.
    var noteText: String {
        var lines: [String] = []
        switch kind {
        case .newCamera:
            lines.append("Possible unmapped ALPR camera (surveillance:type=ALPR).")
        case .wrongInfo:
            lines.append("Reported issue with mapped ALPR camera\(existingCameraID.map { " (\($0))" } ?? "").")
        case .removed:
            lines.append("Mapped ALPR camera appears to be removed\(existingCameraID.map { " (\($0))" } ?? "").")
        }
        if let direction, !direction.isEmpty {
            lines.append("Facing: \(direction)")
        }
        if let mountType, !mountType.isEmpty {
            lines.append("Mount: \(mountType)")
        }
        if let operatorGuess, !operatorGuess.isEmpty {
            lines.append("Likely operator/manufacturer: \(operatorGuess)")
        }
        if let notes, !notes.isEmpty {
            lines.append("Details: \(notes)")
        }
        lines.append("Submitted via Flock Surveillance app.")
        return lines.joined(separator: "\n")
    }
}

struct OSMNoteSnapshot: Equatable, Sendable {
    let id: Int
    let status: String
    let comments: [String]

    var isClosed: Bool {
        status.lowercased() == "closed"
    }
}

enum OSMNoteParser {
    /// OSM Notes API returns GeoJSON Feature with id + properties.status.
    static func parseNote(from data: Data) throws -> OSMNoteSnapshot {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            ?? { throw OSMReportService.ReportError.decoding }()

        // POST /notes.json often returns a Feature; GET may wrap similarly.
        let feature: [String: Any]
        if let type = json["type"] as? String, type == "Feature" {
            feature = json
        } else if let features = json["features"] as? [[String: Any]], let first = features.first {
            feature = first
        } else if json["id"] != nil {
            feature = json
        } else {
            throw OSMReportService.ReportError.decoding
        }

        let id: Int
        if let value = feature["id"] as? Int {
            id = value
        } else if let value = feature["id"] as? Int64 {
            id = Int(value)
        } else if let value = feature["id"] as? Double {
            id = Int(value)
        } else if let props = feature["properties"] as? [String: Any], let value = props["id"] as? Int {
            id = value
        } else {
            throw OSMReportService.ReportError.decoding
        }

        let props = feature["properties"] as? [String: Any] ?? [:]
        let status = (props["status"] as? String) ?? "open"
        var comments: [String] = []
        if let rawComments = props["comments"] as? [[String: Any]] {
            comments = rawComments.compactMap { $0["text"] as? String }
        }
        return OSMNoteSnapshot(id: id, status: status, comments: comments)
    }
}

/// Submits anonymous OSM Notes so the mapping community can verify and tag cameras.
actor OSMReportService {
    static let shared = OSMReportService()

    enum ReportError: LocalizedError {
        case badResponse(Int)
        case decoding

        var errorDescription: String? {
            switch self {
            case .badResponse(let code):
                return "OpenStreetMap rejected the report (HTTP \(code)). Try again later."
            case .decoding:
                return "Could not read the OpenStreetMap note response."
            }
        }
    }

    private let notesEndpoint = URL(string: "https://api.openstreetmap.org/api/0.6/notes.json")!
    private let session: URLSession
    private let userAgent = "FlockSurveillance-iOS/1.5 (civic transparency; contact: flocksurveillance.com)"

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Creates a note and returns its OSM id when the response can be parsed.
    @discardableResult
    func submit(_ report: OSMCameraReport) async throws -> Int {
        var components = URLComponents(url: notesEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.6f", report.coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.6f", report.coordinate.longitude)),
            URLQueryItem(name: "text", value: report.noteText)
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ReportError.badResponse(code)
        }
        return try OSMNoteParser.parseNote(from: data).id
    }

    func fetchNote(id: Int) async throws -> OSMNoteSnapshot {
        guard let url = URL(string: "https://api.openstreetmap.org/api/0.6/notes/\(id).json") else {
            throw ReportError.decoding
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ReportError.badResponse(code)
        }
        return try OSMNoteParser.parseNote(from: data)
    }
}
