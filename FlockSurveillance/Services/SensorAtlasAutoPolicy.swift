import CoreLocation
import Foundation

/// Pure rules for Sensor Atlas in-metro auto-enable / per-metro suppress.
enum SensorAtlasAutoPolicy {
    /// Whether Traffic cams should auto-turn on for this location.
    static func shouldAutoEnable(
        layerAlreadyOn: Bool,
        suppressedMetroNames: Set<String>,
        coordinate: CLLocationCoordinate2D?
    ) -> SensorAtlasCoverage.Metro? {
        guard !layerAlreadyOn, let coordinate else { return nil }
        guard let metro = SensorAtlasCoverage.metro(containing: coordinate) else { return nil }
        guard !suppressedMetroNames.contains(metro.name) else { return nil }
        return metro
    }

    /// Manual off while inside a metro → suppress only that metro.
    static func suppressedAfterManualOff(
        current: Set<String>,
        coordinate: CLLocationCoordinate2D?
    ) -> Set<String> {
        guard let coordinate,
              let metro = SensorAtlasCoverage.metro(containing: coordinate)
        else { return current }
        var next = current
        next.insert(metro.name)
        return next
    }

    /// Manual on → clear all metro suppressions so other cities can auto-on again.
    static func suppressedAfterManualOn(current: Set<String>) -> Set<String> {
        []
    }

    /// Stable key so lat *or* lon changes retrigger observers.
    static func locationKey(_ coordinate: CLLocationCoordinate2D?) -> String {
        guard let coordinate else { return "nil" }
        return String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)
    }
}
