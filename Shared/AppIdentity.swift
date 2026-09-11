import Foundation

/// Bundle-adjacent identity shared by the app and the widget.
/// Display name and scheme are the new ASC app; Xcode target / module names stay FlockSurveillance.
enum AppIdentity {
    static let displayName = "Mapped Camera Pins"
    static let urlScheme = "mappedcamerapins"
    static let appGroupID = "group.com.stephenmoore.mappedcamerapins.shared"

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
