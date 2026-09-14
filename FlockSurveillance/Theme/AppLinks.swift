import Foundation

enum AppLinks {
    static let deFlockProject = URL(string: "https://deflock.org/")!

    /// Live GitHub Pages support site (Settings primary site link).
    static let supportURL = URL(string: "https://scubasteve1999.github.io/mapped-camera-pins-site/")!

    /// Live GitHub Pages privacy policy.
    static let privacyPolicyURL = URL(string: "https://scubasteve1999.github.io/mapped-camera-pins-site/privacy.html")!

    /// Settings primary site link — the live support page.
    static let website = supportURL

    /// Live Flock Surveillance listing.
    static let appStore: URL? = URL(string: "https://apps.apple.com/us/app/flock-surveillance-alpr-map/id6789356933")

    /// Share-card / route share footer: host + path, not a bare github.io.
    static var shareFooterHost: String {
        let host = supportURL.host ?? ""
        let path = supportURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.isEmpty { return host }
        return "\(host)/\(path)"
    }
}
