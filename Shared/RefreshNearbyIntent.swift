import AppIntents
import Foundation

/// Interactive-widget refresh: completing the intent makes WidgetKit rebuild the
/// timeline, which re-reads the latest App Group snapshot.
struct RefreshNearbyIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Nearby ALPRs"
    static let description = IntentDescription("Reloads the nearby ALPR count from the latest snapshot.")
    /// Widget-internal; keep it out of the Shortcuts app's action catalog.
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        .result()
    }
}
