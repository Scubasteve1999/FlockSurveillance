import ActivityKit
import Foundation

@MainActor
final class DriveLiveActivityController {
    static let shared = DriveLiveActivityController()

    private var activity: Activity<DriveActivityAttributes>?

    private init() {}

    func start(session: DriveSession) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()

        let state = contentState(from: session)
        let attributes = DriveActivityAttributes(routeSummary: "ALPR Drive Mode")
        do {
            activity = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
        } catch {
            activity = nil
        }
    }

    func update(session: DriveSession) {
        guard let activity else { return }
        let state = contentState(from: session)
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    func end() {
        guard let activity else { return }
        let finalState = DriveActivityAttributes.ContentState(
            nextLabel: "Drive ended",
            distanceLabel: "—",
            remaining: 0,
            exposureLabel: sessionExposureFallback
        )
        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
        self.activity = nil
    }

    private var sessionExposureFallback: String { "Clear" }

    private func contentState(from session: DriveSession) -> DriveActivityAttributes.ContentState {
        let next = session.nextHit.map { $0.isFlock ? "Flock ALPR" : $0.manufacturer } ?? "No more ALPRs"
        let distance = session.metersToNext.map(ProximityRadar.formatDistance) ?? "—"
        return DriveActivityAttributes.ContentState(
            nextLabel: next,
            distanceLabel: distance,
            remaining: session.camerasRemaining,
            exposureLabel: session.exposureLabel
        )
    }
}
