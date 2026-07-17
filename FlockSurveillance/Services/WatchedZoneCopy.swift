import Foundation

/// Punchy proximity copy for corridor alerts and HUD.
/// Stays honest: mapped pins + phone GPS only — never plate-read claims.
enum WatchedZoneCopy {
    static let enteringTitle = "WATCHED ZONE"
    static let stillInsideTitle = "STILL IN THE GRID"
    static let leftTitle = "CLEARED CORRIDOR"

    static func enteringBody(cameraTitle: String, radiusFeet: Int) -> String {
        "\(cameraTitle) within ~\(radiusFeet) ft — mapped OSM pin, not a plate-read alert."
    }

    static func anotherCameraBody(cameraTitle: String, passedCount: Int) -> String {
        "\(cameraTitle) ahead — mapped pin \(passedCount) on this stretch."
    }

    static func leftBody(passedCount: Int) -> String {
        passedCount == 1
            ? "You cleared 1 mapped ALPR pin on that stretch."
            : "You cleared \(passedCount) mapped ALPR pins on that stretch."
    }

    static let hudActiveLabel = "WATCHED ZONE"
    static let hudActiveSubtitle = "Phone GPS near mapped ALPR pins — not plate reads"
}
