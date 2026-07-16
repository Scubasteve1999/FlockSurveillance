import Foundation

/// Honest proximity copy for corridor alerts and HUD. Never implies a plate read.
enum WatchedZoneCopy {
    static let enteringTitle = "Near mapped ALPR cameras"
    static let stillInsideTitle = "Still near mapped cameras"
    static let leftTitle = "Left mapped camera corridor"

    static func enteringBody(cameraTitle: String, radiusFeet: Int) -> String {
        "\(cameraTitle) is within ~\(radiusFeet) ft — mapped OpenStreetMap pin, not a plate-read alert."
    }

    static func anotherCameraBody(cameraTitle: String, passedCount: Int) -> String {
        "\(cameraTitle) ahead — mapped camera \(passedCount) on this stretch."
    }

    static func leftBody(passedCount: Int) -> String {
        passedCount == 1
            ? "You passed near 1 mapped ALPR pin on that stretch."
            : "You passed near \(passedCount) mapped ALPR pins on that stretch."
    }

    static let hudActiveLabel = "NEAR MAPPED PINS"
    static let hudActiveSubtitle = "GPS near community-mapped ALPRs — not a scan alert"
}
