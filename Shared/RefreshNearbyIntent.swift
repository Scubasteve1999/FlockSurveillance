import AppIntents
import Foundation
import WidgetKit

/// Interactive-widget refresh: recomputes the nearby ALPR count from the App
/// Group camera points + Home, then reloads timelines.
struct RefreshNearbyIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Nearby ALPRs"
    static let description = IntentDescription("Reloads the nearby ALPR count from the latest snapshot.")
    /// Widget-internal; keep it out of the Shortcuts app's action catalog.
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        WidgetSnapshotStore.recomputeNearbyFromHome()
        return .result()
    }
}
