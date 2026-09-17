import Foundation

/// Locked first-paint honesty for MAP chrome, PIN ZONE, and map/PIN share surfaces.
/// Phone GPS near mapped OSM pins — not plate reads, not a vendor feed, not affiliation.
enum MapHonestyCopy {
    static let affiliation = "Not affiliated with Flock Safety"
    static let provenance = "OSM / DeFlock community"
    static let incomplete = "Incomplete map"

    /// Quiet MAP chip + share footer. No coverage percentage.
    static let chipLine = "\(affiliation) · \(provenance) · \(incomplete)."

    static let accessibilityLabel =
        "Not affiliated with Flock Safety. OpenStreetMap and DeFlock community data. Incomplete map."
}
