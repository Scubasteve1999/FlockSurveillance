import CoreLocation
import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @Environment(LocationManager.self) private var locationManager
    @Environment(CameraRepository.self) private var repository
    @Environment(\.modelContext) private var modelContext

    /// Cold open → instrumented pages (score hard-cut lands on features).
    @State private var showColdOpen = true
    @State private var coldLine = 0
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
            if showColdOpen {
                coldOpen
                    .transition(.opacity)
                    .zIndex(2)
            } else {
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
                .transition(.opacity)
            }
        }
        .onAppear {
            // Warm cache during the cold open so Place Score is ready on cut.
            prepareTeaser()
            runColdOpenSequence()
        }
    }

    // MARK: - Cold open

    private var coldOpen: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Thin scanline grid
            GeometryReader { geo in
                Path { path in
                    let step: CGFloat = 48
                    for y in stride(from: 0, through: geo.size.height, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(AppTheme.primary.opacity(0.06), lineWidth: 1)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 18) {
                Spacer()

                if coldLine >= 1 {
                    Text("YOU ARE")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .tracking(6)
                        .foregroundStyle(AppTheme.mutedForeground)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if coldLine >= 2 {
                    Text("BEING MAPPED")
                        .font(.system(size: 34, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(AppTheme.primary)
                        .shadow(color: AppTheme.primary.opacity(0.55), radius: 16, y: 0)
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }

                if coldLine >= 3 {
                    Rectangle()
                        .fill(AppTheme.critical)
                        .frame(width: 120, height: 2)
                        .shadow(color: AppTheme.critical.opacity(0.8), radius: 6)
                        .transition(.scale)

                    Text("OPENSTREETMAP · PUBLIC RECORD · NOT A VENDOR FEED")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(AppTheme.accent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                }

                Spacer()

                if coldLine >= 3 {
                    Text("TAP TO SKIP")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.mutedForeground.opacity(0.7))
                        .padding(.bottom, 40)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 28)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            finishColdOpen()
        }
        .accessibilityLabel("You are being mapped. Tap to continue.")
    }

    private func runColdOpenSequence() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard showColdOpen else { return }
            withAnimation(.easeOut(duration: 0.35)) { coldLine = 1 }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)

            try? await Task.sleep(nanoseconds: 550_000_000)
            guard showColdOpen else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { coldLine = 2 }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.9)
            OverwatchAudio.armClick()

            try? await Task.sleep(nanoseconds: 700_000_000)
            guard showColdOpen else { return }
            withAnimation(.easeOut(duration: 0.3)) { coldLine = 3 }

            try? await Task.sleep(nanoseconds: 900_000_000)
            guard showColdOpen else { return }
            finishColdOpen()
        }
    }

    private func finishColdOpen() {
        guard showColdOpen else { return }
        // Hard cut — land on Place Score page (features), not soft fade into mission.
        page = 1
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        // No animation on the cut — intentional.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showColdOpen = false
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
                .shadow(color: AppTheme.primary.opacity(0.35), radius: 16, y: 0)

            Text("FLOCK SURVEILLANCE")
                .font(.system(size: 28, weight: .black))
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

            Text("HOW WATCHED?")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundStyle(AppTheme.accent)

            Text("How watched is your life?")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(AppTheme.foreground)
                .multilineTextAlignment(.center)

            Text(teaserIsSample
                 ? "Memphis metro preview — enable location next for your block."
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
                let level = SurveillanceLevel.compute(
                    visibleCount: teaserScore.cameraCount,
                    nearestMeters: nil,
                    inWatchedZone: teaserScore.cameraCount >= 5
                )
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        if teaserIsSample {
                            Text("MEMPHIS PREVIEW")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(AppTheme.accent)
                        }
                        Spacer()
                        StatusBadge(text: level.chip, color: level.color)
                    }

                    Text(teaserScore.headline)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.foreground)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(alignment: .center, spacing: 16) {
                        WatchednessDial(
                            grade: teaserScore.grade,
                            cameraCount: teaserScore.cameraCount,
                            size: 110,
                            animate: true
                        )
                        VStack(alignment: .leading, spacing: 6) {
                            Text(teaserScore.grade.uppercased())
                                .font(.system(size: 28, weight: .black))
                                .foregroundStyle(level.color)
                            Text(teaserScore.cameraCountLabel)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                            Text(level.title)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.mutedForeground)
                        }
                    }

                    Text("\(teaserScore.cameraCountLabel) within a mile · \(teaserScore.flockPercent)% Flock")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.mutedForeground)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.card.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                        .stroke(level.color.opacity(0.45), lineWidth: 1.5)
                )
                .shadow(color: level.color.opacity(0.2), radius: 16, y: 0)
            }

            Text("Share a war-room card. Arm Overwatch. Take the lower-cam drive home.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 24)
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
        ReportStore.shared.attach(modelContext: modelContext)
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
            // Memphis metro — denser local preview for DeSoto / Mid-South.
            ?? GeoHelpers.memphisCoordinate
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

            Text("ARM YOUR GEAR")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundStyle(AppTheme.accent)

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
                detail: "Centers the map on you and powers Overwatch proximity.",
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
                    Color(red: 0.04, green: 0.05, blue: 0.08),
                    Color(red: 0.10, green: 0.05, blue: 0.05),
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
                    OverwatchAudio.armClick()
                }
            } label: {
                Text(page < 2 ? "CONTINUE" : "ENTER THE MAP")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(AppTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.primary, AppTheme.critical.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: AppTheme.primary.opacity(0.4), radius: 12, y: 0)
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
