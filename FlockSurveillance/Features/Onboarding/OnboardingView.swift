import CoreLocation
import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @Environment(LocationManager.self) private var locationManager
    @Environment(CameraRepository.self) private var repository
    @Environment(\.modelContext) private var modelContext

    @State private var page = 0
    @State private var didRequestLocation = false
    @State private var didEnableAlerts = false
    @State private var teaserScore: PlaceScore?
    @State private var teaserIsSample = false
    @State private var isLoadingTeaser = true
    /// Hold the shared engine so SwiftUI observes authorizationStatus changes.
    @State private var alertsEngine = AlertsEngine.shared

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    missionPage.tag(0)
                    featuresPage.tag(1)
                    permissionsPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots
                    .padding(.bottom, 10)

                footer
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
            }
        }
    }

    // MARK: - Pages

    private var missionPage: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "camera.metering.spot")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(AppTheme.primary)
                .padding(24)
                .background(AppTheme.card.opacity(0.9))
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))

            Text("FLOCK SURVEILLANCE")
                .font(.system(size: 32, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(AppTheme.foreground)
                .multilineTextAlignment(.center)

            Text("See the cameras watching you.")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
                .multilineTextAlignment(.center)

            Text("Thousands of license plate readers track cars across the country. This is the community map of where they are — powered by OpenStreetMap volunteers, not vendor APIs.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private var featuresPage: some View {
        VStack(spacing: 18) {
            Spacer()

            Text("How watched is your life?")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.foreground)
                .multilineTextAlignment(.center)

            Text(teaserIsSample
                 ? "Sample grade for Atlanta — enable location next for your block."
                 : "A personal grade for where you are — no jargon, no signup.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            if isLoadingTeaser {
                ProgressView()
                    .tint(AppTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if let teaserScore {
                VStack(alignment: .leading, spacing: 12) {
                    if teaserIsSample {
                        Text("ATLANTA PREVIEW")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.accent)
                    }

                    Text(teaserScore.headline)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.foreground)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(alignment: .firstTextBaseline) {
                        Text(teaserScore.grade)
                            .font(.system(size: 36, weight: .black))
                            .foregroundStyle(AppTheme.primary)
                        Spacer()
                        Text(teaserScore.cameraCountLabel)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    }

                    Text("\(teaserScore.cameraCountLabel) within a mile · \(teaserScore.flockPercent)% Flock")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.mutedForeground)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.card.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
            }

            Text("Share a card. Tap once for the safest drive home. See which metros are most mapped.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear { prepareTeaser() }
        .onChange(of: locationManager.location?.coordinate.latitude) { _, _ in
            refreshTeaserScore()
        }
        .onChange(of: repository.cameras.count) { _, _ in
            refreshTeaserScore()
        }
        .onChange(of: repository.isLoading) { _, loading in
            if !loading { refreshTeaserScore() }
        }
        .onChange(of: repository.isSeeding) { _, seeding in
            if !seeding { refreshTeaserScore() }
        }
    }

    private func prepareTeaser() {
        // Attach early so the teaser can read the local cache. Idempotent —
        // Enter the map won't re-load. Seeding in the background is fine here
        // because MapKit isn't on screen yet.
        repository.attach(modelContext: modelContext)
        locationManager.start()
        isLoadingTeaser = true
        teaserScore = nil
        let coordinate = teaserCoordinate()
        repository.scheduleFetch(
            for: GeoHelpers.seedRegion(for: coordinate),
            delayNanoseconds: 50_000_000
        )
        refreshTeaserScore()
    }

    private func teaserCoordinate() -> CLLocationCoordinate2D {
        locationManager.location?.coordinate
            ?? WidgetBridge.homeCoordinate()
            ?? CLLocationCoordinate2D(latitude: 33.7490, longitude: -84.3880)
    }

    private func refreshTeaserScore() {
        let hasPersonalLocation = locationManager.location != nil || WidgetBridge.homeCoordinate() != nil
        let coordinate = teaserCoordinate()
        teaserIsSample = !hasPersonalLocation
        let score = repository.placeScore(near: coordinate, radiusMeters: 1609.34)
        let settled = repository.hasSettledFetch(covering: coordinate)

        // Don't publish a Clear grade until we have nearby cameras or a settled
        // successful fetch for this coordinate (avoids false "your block looks clear").
        if GeoHelpers.shouldCommitPlaceScore(cameraCount: score.cameraCount, settled: settled) {
            teaserScore = score
            isLoadingTeaser = false
        } else {
            isLoadingTeaser = true
            teaserScore = nil
        }
    }

    private var permissionsPage: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Make it yours")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.foreground)

            Text("Both are optional. Everything stays on your device — no accounts, no tracking, no data collection.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            permissionCard(
                icon: "location.fill",
                title: "Location",
                detail: "Centers the map on you and powers proximity radar.",
                actionLabel: didRequestLocation ? "Requested" : "Enable location",
                isDone: didRequestLocation
            ) {
                locationManager.requestPermissionIfNeeded()
                didRequestLocation = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }

            permissionCard(
                icon: "bell.badge.fill",
                title: "Camera alerts",
                detail: "Notifies you near mapped cameras, even in the background.",
                actionLabel: alertsActionLabel,
                isDone: alertsFullyEnabled
            ) {
                Task {
                    if alertsEngine.needsAlwaysAuthorization {
                        alertsEngine.requestAlwaysAccess()
                    } else {
                        await alertsEngine.setEnabled(true)
                    }
                }
                didEnableAlerts = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }

            if didEnableAlerts && !alertsFullyEnabled {
                Text("Alerts need “Always” location. Allow it when prompted, or finish setup in Settings.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.primary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        // Observe auth so labels update when Always is granted.
        .onChange(of: alertsEngine.authorizationStatus) { _, _ in }
    }

    private var alertsFullyEnabled: Bool {
        let _ = alertsEngine.authorizationStatus
        return AppPreferences.alertsEnabled && alertsEngine.hasAlwaysAuthorization
    }

    private var alertsActionLabel: String {
        if alertsFullyEnabled { return "Enabled" }
        if didEnableAlerts || AppPreferences.alertsEnabled { return "Needs Always access" }
        return "Enable alerts"
    }

    // MARK: - Chrome

    private var backdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.12),
                    Color(red: 0.12, green: 0.08, blue: 0.07),
                    AppTheme.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                // Sparse grid — a dense Path on iPad Pro was expensive during
                // the onboarding → map handoff.
                Path { path in
                    let step: CGFloat = 72
                    for x in stride(from: 0, through: geo.size.width, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    for y in stride(from: 0, through: geo.size.height, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(AppTheme.border.opacity(0.35), lineWidth: 0.5)
                .drawingGroup()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index == page ? AppTheme.primary : AppTheme.border)
                    .frame(width: index == page ? 22 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: page)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            DataSourcePill()

            Button {
                if page < 2 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        page += 1
                    }
                } else {
                    // Do NOT wrap this in withAnimation — animating MapKit into the
                    // hierarchy freezes the UI on iPad (and often iPhone).
                    hasSeenOnboarding = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } label: {
                Text(page < 2 ? "Continue" : "Enter the map")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if page < 2 {
                Button {
                    // Same as Enter the map — never animate MapKit into the hierarchy.
                    hasSeenOnboarding = true
                } label: {
                    Text("Skip")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedForeground)
                }
                .buttonStyle(.plain)
            }

            Text("Not affiliated with Flock Safety")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
        }
    }

    // MARK: - Components

    private func permissionCard(
        icon: String,
        title: String,
        detail: String,
        actionLabel: String,
        isDone: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.foreground)
                Spacer()
            }

            Text(detail)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                HStack(spacing: 6) {
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                    }
                    Text(actionLabel)
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(isDone ? AppTheme.densityLow : AppTheme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isDone ? AppTheme.densityLow.opacity(0.15) : AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isDone ? AppTheme.densityLow.opacity(0.4) : .clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isDone)
        }
        .padding(16)
        .background(AppTheme.card.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}
