import CoreLocation
import Foundation
import MapKit

struct OverpassBounds: Decodable, Sendable {
    let minlat: Double
    let minlon: Double
    let maxlat: Double
    let maxlon: Double

    var center: (lat: Double, lon: Double) {
        ((minlat + maxlat) / 2, (minlon + maxlon) / 2)
    }
}

struct OverpassCenter: Decodable, Sendable {
    let lat: Double
    let lon: Double
}

struct OverpassElement: Decodable, Sendable {
    let type: String
    let id: Int64
    let lat: Double?
    let lon: Double?
    let center: OverpassCenter?
    let bounds: OverpassBounds?
    let tags: [String: String]?
}

struct OverpassResponse: Decodable, Sendable {
    let elements: [OverpassElement]
}

/// Sendable transfer object so Overpass results can cross actor boundaries safely.
struct ALPRCameraDTO: Sendable, Equatable {
    let id: String
    let latitude: Double
    let longitude: Double
    let manufacturer: String?
    let operatorName: String?
    let direction: String?
    let cameraName: String?
    let tagsJSON: String
    let fetchedAt: Date

    var isFlock: Bool {
        (manufacturer ?? "").lowercased().contains("flock")
    }

    @MainActor
    func makeModel() -> ALPRCamera {
        ALPRCamera(
            id: id,
            latitude: latitude,
            longitude: longitude,
            manufacturer: manufacturer,
            operatorName: operatorName,
            direction: direction,
            cameraName: cameraName,
            tagsJSON: tagsJSON,
            fetchedAt: fetchedAt
        )
    }
}

enum OverpassError: LocalizedError {
    case invalidURL
    case httpStatus(Int)
    case decoding
    case emptyRegion

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Could not reach the OpenStreetMap Overpass API."
        case .httpStatus(let code): return "Overpass returned HTTP \(code)."
        case .decoding: return "Could not parse camera data."
        case .emptyRegion: return "Map region is too small to query."
        }
    }
}

enum OverpassParser {
    static func cameras(from data: Data, fetchedAt: Date = .now) throws -> [ALPRCameraDTO] {
        let decoded: OverpassResponse
        do {
            decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)
        } catch {
            throw OverpassError.decoding
        }

        var seen = Set<String>()
        var cameras: [ALPRCameraDTO] = []

        for element in decoded.elements {
            guard let coordinate = coordinate(for: element) else { continue }
            let id = "osm-\(element.type)-\(element.id)"
            if seen.contains(id) { continue }
            seen.insert(id)

            let tags = element.tags ?? [:]
            let tagsData = (try? JSONEncoder().encode(tags)) ?? Data("{}".utf8)
            let tagsJSON = String(data: tagsData, encoding: .utf8) ?? "{}"

            cameras.append(
                ALPRCameraDTO(
                    id: id,
                    latitude: coordinate.lat,
                    longitude: coordinate.lon,
                    manufacturer: tags["manufacturer"] ?? tags["brand"],
                    operatorName: tags["operator"],
                    direction: tags["camera:direction"] ?? tags["direction"],
                    cameraName: tags["name"] ?? tags["ref"],
                    tagsJSON: tagsJSON,
                    fetchedAt: fetchedAt
                )
            )
        }
        return cameras
    }

    static func coordinate(for element: OverpassElement) -> (lat: Double, lon: Double)? {
        if let lat = element.lat, let lon = element.lon {
            return (lat, lon)
        }
        if let center = element.center {
            return (center.lat, center.lon)
        }
        if let bounds = element.bounds {
            return bounds.center
        }
        return nil
    }

    static func osmURL(forCameraID id: String) -> URL? {
        let parts = id.split(separator: "-")
        guard parts.count >= 3, parts[0] == "osm" else {
            if parts.count == 2, parts[0] == "osm", let nodeID = parts.last {
                return URL(string: "https://www.openstreetmap.org/node/\(nodeID)")
            }
            return nil
        }
        let type = String(parts[1])
        let numeric = parts.dropFirst(2).joined(separator: "-")
        return URL(string: "https://www.openstreetmap.org/\(type)/\(numeric)")
    }
}

actor OverpassClient {
    static let shared = OverpassClient()

    private let session: URLSession
    /// Public Overpass mirrors. Prefer hosts that answer quickly on IPv4 when
    /// community endpoints refuse IPv6 (common on some Wi‑Fi / carrier paths).
    private let endpoints = [
        "https://overpass.osm.ch/api/interpreter",
        "https://overpass.openstreetmap.fr/api/interpreter",
        "https://overpass-api.de/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter"
    ]

    private var lastFetchAt: Date?
    private let minimumInterval: TimeInterval = 1.2

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 18
            configuration.timeoutIntervalForResource = 28
            configuration.waitsForConnectivity = true
            configuration.httpAdditionalHeaders = [
                "Accept": "application/json",
                "User-Agent": "FlockSurveillance/1.1 (civic transparency; contact: flocksurveillance.com)"
            ]
            self.session = URLSession(configuration: configuration)
        }
    }

    func fetchCameras(in region: MKCoordinateRegion) async throws -> [ALPRCameraDTO] {
        let south = region.center.latitude - region.span.latitudeDelta / 2
        let north = region.center.latitude + region.span.latitudeDelta / 2
        let west = region.center.longitude - region.span.longitudeDelta / 2
        let east = region.center.longitude + region.span.longitudeDelta / 2

        guard north > south, east > west else { throw OverpassError.emptyRegion }

        if let lastFetchAt {
            let elapsed = Date().timeIntervalSince(lastFetchAt)
            if elapsed < minimumInterval {
                try await Task.sleep(nanoseconds: UInt64((minimumInterval - elapsed) * 1_000_000_000))
            }
        }

        let query = """
        [out:json][timeout:25];
        (
          node["man_made"="surveillance"]["surveillance:type"="ALPR"](\(south),\(west),\(north),\(east));
          node["surveillance:type"="ALPR"](\(south),\(west),\(north),\(east));
          way["man_made"="surveillance"]["surveillance:type"="ALPR"](\(south),\(west),\(north),\(east));
          way["surveillance:type"="ALPR"](\(south),\(west),\(north),\(east));
          relation["man_made"="surveillance"]["surveillance:type"="ALPR"](\(south),\(west),\(north),\(east));
          relation["surveillance:type"="ALPR"](\(south),\(west),\(north),\(east));
        );
        out center tags;
        """

        var lastError: Error = OverpassError.invalidURL
        for endpoint in endpoints {
            do {
                let cameras = try await perform(query: query, endpoint: endpoint)
                lastFetchAt = Date()
                return cameras
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private func perform(query: String, endpoint: String) async throws -> [ALPRCameraDTO] {
        guard let url = URL(string: endpoint) else { throw OverpassError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)".data(using: .utf8)
        request.timeoutInterval = 18

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw OverpassError.httpStatus(http.statusCode)
        }

        return try OverpassParser.cameras(from: data)
    }
}
