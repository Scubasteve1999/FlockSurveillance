import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @Environment(LocationManager.self) private var locationManager

    @State private var page = 0
    @State private var didRequestLocation = false
    @State private var didEnableAlerts = false
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
        VStack(spacing: 14) {
            Spacer()

            Text("Built to keep you aware")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.foreground)
                .multilineTextAlignment(.center)
                .padding(.bottom, 6)

            featureCard(
                icon: "map.fill",
                title: "Live camera map",
                detail: "ALPR pins, coverage heat, and field-of-view cones wherever you look."
            )
            featureCard(
                icon: "car.fill",
                title: "Low-exposure drives",
                detail: "Compare routes by camera count, then Drive Mode counts them down live."
            )
            featureCard(
                icon: "bell.badge.fill",
                title: "Background alerts",
                detail: "Get a heads-up near a mapped ALPR — even with the app closed."
            )
            featureCard(
                icon: "gauge.with.dots.needle.67percent",
                title: "Place Score",
                detail: "Grade any neighborhood's surveillance density in one tap."
            )

            Spacer()
        }
        .padding(.horizontal, 24)
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
                title: "ALPR alerts",
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
                    withAnimation(.easeInOut(duration: 0.3)) {
                        hasSeenOnboarding = true
                    }
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

    private func featureCard(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 42, height: 42)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.foreground)
                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(AppTheme.card.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

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
