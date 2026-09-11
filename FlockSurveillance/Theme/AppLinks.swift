import Foundation

enum AppLinks {
    static let deFlockProject = URL(string: "https://deflock.org/")!

    /// Support / privacy / share-card host. Empty until a domain is chosen — do not invent one.
    static let websiteHost: String? = nil

    static var website: URL? {
        guard let host = websiteHost, !host.isEmpty else { return nil }
        return URL(string: "https://\(host)")
    }

    /// New ASC listing URL — unset until Stephen creates the app.
    static let appStore: URL? = nil

    static var shareFooterHost: String? {
        guard let host = websiteHost, !host.isEmpty else { return nil }
        return host
    }
}
