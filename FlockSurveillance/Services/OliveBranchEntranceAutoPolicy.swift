import CoreLocation
import Foundation

/// Pure rules for auto-enabling the Olive Branch entrance overlay in the home market.
enum OliveBranchEntranceAutoPolicy {
    /// Auto-on only near Olive Branch, and only if the user has not manually turned the layer off.
    static func shouldAutoEnable(
        layerAlreadyOn: Bool,
        suppressed: Bool,
        coordinate: CLLocationCoordinate2D?
    ) -> Bool {
        guard !layerAlreadyOn, !suppressed, let coordinate else { return false }
        return OliveBranchEntranceCoverage.contains(coordinate)
    }

    /// Manual off → suppress auto-enable until the user turns the layer back on.
    static func suppressedAfterManualOff(current _: Bool) -> Bool {
        true
    }

    /// Manual on → allow auto-enable again if they leave and return.
    static func suppressedAfterManualOn(current _: Bool) -> Bool {
        false
    }

    /// Stable key so lat *or* lon changes retrigger observers.
    static func locationKey(_ coordinate: CLLocationCoordinate2D?) -> String {
        guard let coordinate else { return "nil" }
        return String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)
    }
}
