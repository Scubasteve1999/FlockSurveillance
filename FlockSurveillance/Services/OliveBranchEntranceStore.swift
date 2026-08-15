import CoreLocation
import Foundation
import MapKit

@MainActor
@Observable
final class OliveBranchEntranceStore {
    private(set) var bundle: OliveBranchEntranceBundle?
    private(set) var loadError: String?
    private(set) var isLoaded = false

    func loadIfNeeded(
        resourceName: String = "OliveBranchEntranceBundle",
        from resourceBundle: Bundle = .main
    ) {
        guard !isLoaded else { return }
        do {
            bundle = try Self.loadBundle(from: resourceBundle, resourceName: resourceName)
            isLoaded = true
            loadError = nil
        } catch {
            bundle = nil
            isLoaded = false
            loadError = error.localizedDescription
        }
    }

    /// Test helper.
    func applyLoadedBundle(_ bundle: OliveBranchEntranceBundle) {
        self.bundle = bundle
        isLoaded = true
        loadError = nil
    }

    var attribution: String? { bundle?.attribution }

    var roadRows: [OliveBranchEntranceSite] { bundle?.sites ?? [] }

    var pins: [OliveBranchEntrancePin] { bundle?.pins ?? [] }

    var uniqueSites: [OliveBranchUniqueSite] {
        Self.makeUniqueSites(from: roadRows)
    }

    var gapSites: [OliveBranchUniqueSite] {
        uniqueSites.filter(\.isGap)
    }

    var leftoverPins: [OliveBranchEntrancePin] {
        pins.filter(\.isLeftover)
    }

    var entrancePins: [OliveBranchEntrancePin] {
        pins.filter { $0.locationClass == .cityLimitEntrance }
    }

    var forced24RoadRows: [OliveBranchEntranceSite] {
        roadRows.filter(\.includeInForced24)
    }

    var forced24UniqueSites: [OliveBranchUniqueSite] {
        uniqueSites.filter(\.includeInForced24)
    }

    var summary: OliveBranchEntranceSummary? {
        guard let bundle else { return nil }
        return Self.makeSummary(bundle)
    }

    func pin(id: String) -> OliveBranchEntrancePin? {
        pins.first { $0.id == id }
    }

    /// Unique crossings in the viewport, nearest to center first.
    func uniqueSites(in region: MKCoordinateRegion, limit: Int = 30) -> [OliveBranchUniqueSite] {
        guard limit > 0 else { return [] }
        let halfLat = region.span.latitudeDelta / 2
        let halfLon = region.span.longitudeDelta / 2
        let minLat = region.center.latitude - halfLat
        let maxLat = region.center.latitude + halfLat
        let minLon = region.center.longitude - halfLon
        let maxLon = region.center.longitude + halfLon
        let center = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        return uniqueSites
            .filter {
                $0.coordinate.latitude >= minLat && $0.coordinate.latitude <= maxLat
                    && $0.coordinate.longitude >= minLon && $0.coordinate.longitude <= maxLon
            }
            .sorted {
                let d0 = center.distance(from: CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude))
                let d1 = center.distance(from: CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude))
                return d0 < d1
            }
            .prefix(limit)
            .map { $0 }
    }

    nonisolated static func loadBundle(
        from resourceBundle: Bundle,
        resourceName: String
    ) throws -> OliveBranchEntranceBundle {
        guard let url = resourceBundle.url(forResource: resourceName, withExtension: "json") else {
            throw OliveBranchEntranceStoreError.missingResource
        }
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(OliveBranchEntranceBundle.self, from: data)
        try validate(decoded)
        return decoded
    }

    nonisolated static func makeUniqueSites(from rows: [OliveBranchEntranceSite]) -> [OliveBranchUniqueSite] {
        var order: [String] = []
        var groups: [String: [OliveBranchEntranceSite]] = [:]
        for row in rows {
            if groups[row.uniqueSiteId] == nil {
                order.append(row.uniqueSiteId)
            }
            groups[row.uniqueSiteId, default: []].append(row)
        }
        return order.compactMap { key in
            guard let members = groups[key] else { return nil }
            return OliveBranchUniqueSite(uniqueSiteId: key, rows: members)
        }
    }

    nonisolated static func makeSummary(_ bundle: OliveBranchEntranceBundle) -> OliveBranchEntranceSummary {
        let unique = makeUniqueSites(from: bundle.sites)
        let matchCount = unique.filter { $0.quality == .match }.count
        let nearMissCount = unique.filter { $0.quality == .nearMiss }.count
        let gapCount = unique.filter { $0.quality == .noPin }.count
        let entrancePins = bundle.pins.filter { $0.locationClass == .cityLimitEntrance }
        return OliveBranchEntranceSummary(
            roadRowCount: bundle.sites.count,
            uniqueSiteCount: unique.count,
            matchCount: matchCount,
            nearMissCount: nearMissCount,
            gapCount: gapCount,
            sitesWithPinWithin250: matchCount + nearMissCount,
            pinCount: bundle.pins.count,
            entrancePinCount: entrancePins.count,
            leftoverPinCount: bundle.pins.count - entrancePins.count
        )
    }

    /// Rejects empty tables, duplicate IDs, and Dist/Quality that break the published windows.
    nonisolated static func validate(_ bundle: OliveBranchEntranceBundle) throws {
        guard !bundle.sites.isEmpty else {
            throw OliveBranchEntranceStoreError.invalidBundle("Entrance bundle has no sites.")
        }
        guard !bundle.pins.isEmpty else {
            throw OliveBranchEntranceStoreError.invalidBundle("Entrance bundle has no pins.")
        }

        var seenPinIDs = Set<String>()
        for pin in bundle.pins {
            let id = pin.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, !id.contains(" ") else {
                throw OliveBranchEntranceStoreError.invalidBundle("Invalid pin id: \(pin.id)")
            }
            guard seenPinIDs.insert(id).inserted else {
                throw OliveBranchEntranceStoreError.invalidBundle("Duplicate pin id: \(id)")
            }
        }

        var seenSiteIDs = Set<String>()
        for site in bundle.sites {
            let id = site.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, !id.contains(" ") else {
                throw OliveBranchEntranceStoreError.invalidBundle("Invalid site id: \(site.id)")
            }
            guard seenSiteIDs.insert(id).inserted else {
                throw OliveBranchEntranceStoreError.invalidBundle("Duplicate site id: \(id)")
            }
            let uniqueId = site.uniqueSiteId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !uniqueId.isEmpty else {
                throw OliveBranchEntranceStoreError.invalidBundle("Blank uniqueSiteId for \(id)")
            }
            let road = site.road.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !road.isEmpty else {
                throw OliveBranchEntranceStoreError.invalidBundle("Blank road for site \(id)")
            }
            let classified = EntranceMatchQuality.classify(distanceMeters: site.distanceMeters)
            guard classified == site.quality else {
                throw OliveBranchEntranceStoreError.invalidBundle(
                    "Quality \(site.quality.rawValue) does not match published distance for \(id)."
                )
            }
            let node = site.nearestOsmNode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            switch site.quality {
            case .match, .nearMiss:
                guard !node.isEmpty else {
                    throw OliveBranchEntranceStoreError.invalidBundle(
                        "Site \(id) is \(site.quality.rawValue) but has no nearest OSM node."
                    )
                }
                guard seenPinIDs.contains(node) else {
                    throw OliveBranchEntranceStoreError.invalidBundle(
                        "Site \(id) nearestOsmNode \(node) is not in pins."
                    )
                }
            case .noPin:
                if !node.isEmpty, !seenPinIDs.contains(node) {
                    throw OliveBranchEntranceStoreError.invalidBundle(
                        "Site \(id) nearestOsmNode \(node) is not in pins."
                    )
                }
            }
        }

        let siteIDs = Set(bundle.sites.map(\.id))
        let uniqueIDs = Set(bundle.sites.map(\.uniqueSiteId))
        for pin in bundle.pins {
            let id = pin.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard siteIDs.contains(pin.bestEntranceId) || uniqueIDs.contains(pin.bestEntranceId) else {
                throw OliveBranchEntranceStoreError.invalidBundle(
                    "Pin \(id) bestEntranceId \(pin.bestEntranceId) is not a site."
                )
            }
            let classified = EntranceMatchQuality.classify(distanceMeters: pin.distanceMeters)
            switch pin.locationClass {
            case .cityLimitEntrance:
                guard classified != .noPin else {
                    throw OliveBranchEntranceStoreError.invalidBundle(
                        "Entrance pin \(id) is farther than 250 m from its crossing."
                    )
                }
            case .inside:
                guard classified == .noPin else {
                    throw OliveBranchEntranceStoreError.invalidBundle(
                        "Leftover pin \(id) is within 250 m of a curated crossing."
                    )
                }
            }
        }
    }
}

enum OliveBranchEntranceStoreError: LocalizedError {
    case missingResource
    case invalidBundle(String)

    var errorDescription: String? {
        switch self {
        case .missingResource:
            return "Olive Branch entrance data is missing from the app bundle."
        case .invalidBundle(let reason):
            return reason
        }
    }
}
