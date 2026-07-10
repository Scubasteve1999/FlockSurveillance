import CoreLocation
import SwiftData
import SwiftUI
import UIKit

/// Runs before the app finishes launching, which SwiftUI's `.onAppear` does not
/// guarantee — critical for background relaunches (region-monitoring wake-ups
/// deliver their event only if a CLLocationManager delegate exists at launch)
/// and for notification taps on cold start (UNUserNotificationCenter requires
/// its delegate to be set before launch completes).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        NotificationTapHandler.shared.install()
        AlertsEngine.shared.activateIfEnabled()
        return true
    }
}

@main
struct FlockSurveillanceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var repository = CameraRepository()
    @State private var locationManager = LocationManager()
    @State private var radar = ProximityRadar()
    @State private var driveSession = DriveSession.shared
    @State private var selectedTab = 0
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    private let modelContainer: ModelContainer = {
        do {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            let storeURL = support.appendingPathComponent("FlockSurveillance.store")
            let configuration = ModelConfiguration(url: storeURL)
            return try ModelContainer(for: ALPRCamera.self, configurations: configuration)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if hasSeenOnboarding {
                    RootTabView(selectedTab: $selectedTab)
                        // Keep MapKit out of any inherited transition animation.
                        .transaction { $0.animation = nil }
                } else {
                    OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                }
            }
            .environment(repository)
            .environment(locationManager)
            .environment(radar)
            .environment(driveSession)
            .preferredColorScheme(.dark)
            .onAppear {
                // Attach after first frame so Enter the map isn't competing with
                // a full SwiftData load + candidate ranking on the main thread.
                if hasSeenOnboarding {
                    repository.attach(modelContext: modelContainer.mainContext)
                    locationManager.start()
                }
            }
            .onChange(of: hasSeenOnboarding) { _, seen in
                guard seen else { return }
                Task { @MainActor in
                    await Task.yield()
                    repository.attach(modelContext: modelContainer.mainContext)
                    locationManager.start()
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: .flockDeepLink)) { note in
                if let url = note.userInfo?["url"] as? URL {
                    handleDeepLink(url)
                }
            }
        }
        .modelContainer(modelContainer)
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "flocksurveillance" else { return }
        hasSeenOnboarding = true
        let host = url.host?.lowercased()
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        switch host {
        case "map", nil:
            selectedTab = 0
            if let lat = items.first(where: { $0.name == "lat" })?.value.flatMap(Double.init),
               let lon = items.first(where: { $0.name == "lon" || $0.name == "lng" })?.value.flatMap(Double.init) {
                PendingIntentActions.mapFocusCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                NotificationCenter.default.post(name: .flockMapFocus, object: nil)
            }
        case "route", "deflock":
            // Privacy routing lives on the Route tab (native MapKit, not DeFlock web).
            selectedTab = 1
            if let commute = items.first(where: { $0.name == "commute" })?.value,
               commute == "home" || commute == "work" {
                PendingIntentActions.commuteToHome = commute == "home"
                NotificationCenter.default.post(name: .flockSafestCommute, object: nil)
            }
        case "settings":
            selectedTab = 3
        default:
            selectedTab = 0
        }
    }
}
