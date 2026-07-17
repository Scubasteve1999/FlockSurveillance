import ActivityKit
import Foundation

extension Activity: @retroactive @unchecked Sendable {}

@MainActor
final class DriveLiveActivityController {
    static let shared = DriveLiveActivityController()

    private var activity: Activity<DriveActivityAttributes>?

    private init() {}

    func start(session: DriveSession) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        await end()

        let state = contentState(from: session)
        let attributes = DriveActivityAttributes(routeSummary: "Overwatch Drive")
        do {
            activity = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
        } catch {
            activity = nil
        }
    }

    func update(session: DriveSession) async {
        guard let activity else { return }
        let state = contentState(from: session)
        await activity.update(.init(state: state, staleDate: nil))
    }

    func end() async {
        guard let activity else { return }
        let finalState = DriveActivityAttributes.ContentState(
            nextLabel: "Drive ended · corridor clear",
            distanceLabel: "—",
            remaining: 0,
            exposureLabel: sessionExposureFallback
        )
        self.activity = nil
        await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
    }

    private var sessionExposureFallback: String { "CLEAR" }

    private func contentState(from session: DriveSession) -> DriveActivityAttributes.ContentState {
        let next = session.nextHit.map { $0.isFlock ? "Next Flock pin" : "Next mapped pin" }
            ?? "Corridor clear"
        let distance = session.metersToNext.map(ProximityRadar.formatDistance) ?? "—"
        return DriveActivityAttributes.ContentState(
            nextLabel: next,
            distanceLabel: distance,
            remaining: session.camerasRemaining,
            exposureLabel: session.exposureLabel.uppercased()
        )
    }
}
