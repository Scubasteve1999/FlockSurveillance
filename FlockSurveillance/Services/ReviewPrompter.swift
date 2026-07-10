import Foundation
import StoreKit
import SwiftUI

/// Requests an App Store review after high-signal moments (finished drive,
/// shared Place Score), with a frequency guard so we never nag.
@MainActor
enum ReviewPrompter {
    private static let eventCountKey = "review.eventCount"
    private static let lastPromptKey = "review.lastPromptAt"

    private static let minEvents = 3
    private static let minDaysBetweenPrompts = 30.0

    static func recordHighSignalEvent(requestReview: RequestReviewAction) {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: eventCountKey) + 1
        defaults.set(count, forKey: eventCountKey)

        guard count >= minEvents else { return }

        if let last = defaults.object(forKey: lastPromptKey) as? TimeInterval {
            let daysSince = (Date().timeIntervalSince1970 - last) / 86_400
            guard daysSince >= minDaysBetweenPrompts else { return }
        }

        defaults.set(Date().timeIntervalSince1970, forKey: lastPromptKey)
        requestReview()
    }
}
