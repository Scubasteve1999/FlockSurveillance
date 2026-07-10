import CarPlay
import UIKit

/// Driving-task CarPlay scene: mirrors the Drive Mode HUD (next ALPR, distance,
/// remaining count) on the car screen.
///
/// Requires the `com.apple.developer.carplay-driving-task` entitlement, which
/// Apple grants per-app — see the commented block in project.yml. Until it's
/// granted, this scene never connects and the code is inert.
///
/// Do NOT declare `UIApplicationSceneManifest` / CarPlay scene roles in Info.plist
/// until the entitlement is approved. Declaring
/// `CPTemplateApplicationSceneSessionRoleApplication` with
/// `UIApplicationSupportsMultipleScenes` and no window-scene configuration
/// freezes iPad scene transitions (including onboarding).
@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var refreshTimer: Timer?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        interfaceController.setRootTemplate(makeTemplate(), animated: false, completion: nil)
        startRefreshing()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        refreshTimer?.invalidate()
        refreshTimer = nil
        self.interfaceController = nil
    }

    private func startRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            Task { @MainActor in
                self.refresh()
            }
        }
    }

    private func refresh() {
        guard let interfaceController else { return }
        interfaceController.setRootTemplate(makeTemplate(), animated: false, completion: nil)
    }

    private func makeTemplate() -> CPInformationTemplate {
        let session = DriveSession.shared

        let items: [CPInformationItem]
        if session.isActive {
            let nextLabel: String
            if let next = session.nextHit {
                nextLabel = next.isFlock ? "Flock ALPR" : next.manufacturer
            } else {
                nextLabel = "Corridor clear"
            }
            let distance = session.metersToNext.map(ProximityRadar.formatDistance) ?? "—"
            items = [
                CPInformationItem(title: "Next ALPR", detail: nextLabel),
                CPInformationItem(title: "Distance", detail: distance),
                CPInformationItem(title: "Remaining", detail: "\(session.camerasRemaining) cameras"),
                CPInformationItem(title: "Exposure", detail: session.exposureLabel)
            ]
        } else {
            items = [
                CPInformationItem(
                    title: "No active drive",
                    detail: "Analyze a route on your iPhone, then Start Drive."
                )
            ]
        }

        return CPInformationTemplate(
            title: "ALPR Drive Mode",
            layout: .leading,
            items: items,
            actions: []
        )
    }
}
