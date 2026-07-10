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
    /// OSM element id (e.g. "node/123") when reporting an existing camera.
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

/// Submits anonymous OSM Notes so the mapping community can verify and tag cameras.
actor OSMReportService {
    static let shared = OSMReportService()

    enum ReportError: LocalizedError {
        case badResponse(Int)

        var errorDescription: String? {
            switch self {
            case .badResponse(let code):
                return "OpenStreetMap rejected the report (HTTP \(code)). Try again later."
            }
        }
    }

    private let endpoint = URL(string: "https://api.openstreetmap.org/api/0.6/notes.json")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func submit(_ report: OSMCameraReport) async throws {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.6f", report.coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.6f", report.coordinate.longitude)),
            URLQueryItem(name: "text", value: report.noteText)
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("FlockSurveillance-iOS/1.3", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ReportError.badResponse(code)
        }
    }
}
