import CoreLocation
import Foundation
import MapKit

/// Viewport trust readout for the radar instrument.
struct CoverageConfidence: Equatable {
    enum FetchState: Equatable {
        case loading
        case seeding
        case fetched
        case stale
        case error
    }

    let visibleCount: Int
    let facingPercent: Int
    let state: FetchState
    let freshnessShort: String?

    /// Compact instrument line, e.g. `Fetched · 42 · 18% facing · 3m`.
    var instrumentLine: String {
        var parts: [String] = [stateLabel, "\(visibleCount)"]
        parts.append("\(facingPercent)% facing")
        if let freshnessShort, !freshnessShort.isEmpty {
            parts.append(freshnessShort)
        }
        return parts.joined(separator: " · ")
    }

    private var stateLabel: String {
        switch state {
        case .loading: return "Loading"
        case .seeding: return "Seeding"
        case .fetched: return "Fetched"
        case .stale: return "Cached"
        case .error: return "Error"
        }
    }

    static func facingPercent(in cameras: [ALPRCamera]) -> Int {
        guard !cameras.isEmpty else { return 0 }
        let withFacing = cameras.filter { GeoHelpers.directionDegrees(from: $0.direction) != nil }.count
        return Int((Double(withFacing) / Double(cameras.count) * 100).rounded())
    }

    static func make(
        visibleCameras: [ALPRCamera],
        isLoading: Bool,
        isSeeding: Bool,
        isServingStale: Bool,
        lastError: String?,
        lastSuccessfulFetchAt: Date?,
        hasViewportFetch: Bool,
        now: Date = .now
    ) -> CoverageConfidence {
        let state: FetchState
        if isLoading {
            state = .loading
        } else if isSeeding {
            state = .seeding
        } else if lastError != nil, !isServingStale || visibleCameras.isEmpty {
            state = .error
        } else if isServingStale || !hasViewportFetch {
            // Cold cache / seed-only / failed-fetch fallback — not a fresh viewport fetch.
            state = .stale
        } else {
            state = .fetched
        }

        return CoverageConfidence(
            visibleCount: visibleCameras.count,
            facingPercent: facingPercent(in: visibleCameras),
            state: state,
            freshnessShort: shortFreshness(from: lastSuccessfulFetchAt, now: now)
        )
    }

    /// Refuse absent diffs when the remote set looks like a truncated mirror vs known density.
    /// Empty remotes (confirmed across Overpass mirrors) are trusted only for sparse tiles.
    static func shouldTrustAbsentDiff(remoteCount: Int, cachedInCoverage: Int) -> Bool {
        if remoteCount == 0 {
            return cachedInCoverage >= 1 && cachedInCoverage <= 3
        }
        if cachedInCoverage <= 3 { return true }
        return remoteCount * 2 >= cachedInCoverage
    }

    /// Cached cameras inside any of `regions` whose IDs were not in the successful remote set.
    /// Returns empty when the remote set looks incomplete vs cache (including dense empty tiles).
    static func idsToMarkAbsent(
        cached: [(id: String, coordinate: CLLocationCoordinate2D)],
        remoteIDs: Set<String>,
        regions: [MKCoordinateRegion]
    ) -> Set<String> {
        guard !regions.isEmpty else { return [] }
        let inCoverage = cached.filter { candidate in
            regions.contains { GeoHelpers.region($0, contains: candidate.coordinate) }
        }
        guard shouldTrustAbsentDiff(
            remoteCount: remoteIDs.count,
            cachedInCoverage: inCoverage.count
        ) else { return [] }
        return Set(
            inCoverage
                .filter { !remoteIDs.contains($0.id) }
                .map(\.id)
        )
    }

    static func idsToMarkAbsent(
        cached: [(id: String, coordinate: CLLocationCoordinate2D)],
        remoteIDs: Set<String>,
        region: MKCoordinateRegion
    ) -> Set<String> {
        idsToMarkAbsent(cached: cached, remoteIDs: remoteIDs, regions: [region])
    }

    private static func shortFreshness(from date: Date?, now: Date) -> String? {
        guard let date else { return nil }
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h" }
        return "\(Int(seconds / 86_400))d"
    }
}
