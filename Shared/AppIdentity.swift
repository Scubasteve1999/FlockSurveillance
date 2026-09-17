import Foundation

/// Bundle-adjacent identity shared by the app and the widget.
/// Display name, URL scheme, and app group match the Flock Surveillance listing.
/// Xcode target / module names stay FlockSurveillance.
enum AppIdentity {
    static let displayName = "Flock Surveillance"
    /// Mono chrome / share header. Same product as the App Store listing — not a second brand.
    static let chromeMono = "FLOCK SURVEILLANCE"
    static let urlScheme = "flocksurveillance"
    static let appGroupID = "group.com.flocksurveillance.shared"

    /// Page / HUD eyebrow: product first, surface second. Overwatch is a mode, not a title.
    static func chromeEyebrow(_ tab: String) -> String {
        "\(chromeMono) · \(tab)"
    }

    static var mapURL: URL {
        URL(string: "\(urlScheme)://map")!
    }

    static var routeURL: URL {
        URL(string: "\(urlScheme)://route")!
    }

    static func mapURL(lat: Double, lon: Double, fractionDigits: Int = 3) -> URL {
        let format = "%.\(fractionDigits)f"
        return URL(string: String(
            format: "\(urlScheme)://map?lat=\(format)&lon=\(format)",
            lat,
            lon
        ))!
    }

    static func routeURL(commute: String) -> URL {
        URL(string: "\(urlScheme)://route?commute=\(commute)")!
    }
}
