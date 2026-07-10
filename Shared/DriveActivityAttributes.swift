import ActivityKit
import Foundation

struct DriveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var nextLabel: String
        var distanceLabel: String
        var remaining: Int
        var exposureLabel: String
    }

    var routeSummary: String
}
