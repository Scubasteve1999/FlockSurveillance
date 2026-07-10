import SwiftData
import SwiftUI

@main
struct FlockSurveillanceApp: App {
    @State private var repository = CameraRepository()
    @State private var locationManager = LocationManager()
    @State private var radar = ProximityRadar()
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
                } else {
                    OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                }
            }
            .environment(repository)
            .environment(locationManager)
            .environment(radar)
            .preferredColorScheme(.dark)
            .onAppear {
                repository.attach(modelContext: modelContainer.mainContext)
                locationManager.start()
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
        }
        .modelContainer(modelContainer)
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "flocksurveillance" else { return }
        hasSeenOnboarding = true
        switch url.host?.lowercased() {
        case "map", nil:
            selectedTab = 0
        case "route":
            selectedTab = 1
        case "settings":
            selectedTab = 3
        case "deflock":
            selectedTab = 0
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: AppLinks.openDeFlockMapsNotification, object: nil)
            }
        default:
            selectedTab = 0
        }
    }
}
