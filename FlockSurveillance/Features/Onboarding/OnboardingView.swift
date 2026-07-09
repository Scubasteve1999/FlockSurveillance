import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @Environment(LocationManager.self) private var locationManager

    var body: some View {
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
                Path { path in
                    let step: CGFloat = 36
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
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 18) {
                    Text("FLOCK SURVEILLANCE")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(AppTheme.foreground)
                        .multilineTextAlignment(.center)

                    Text("How watched is your life right now?")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                        .multilineTextAlignment(.center)

                    Text("A civic map of community-documented ALPR cameras — proximity radar, route exposure, and clear context. Built on OpenStreetMap, not vendor APIs.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.mutedForeground)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 28)

                Spacer()

                VStack(spacing: 12) {
                    DataSourcePill()

                    Button {
                        locationManager.requestPermissionIfNeeded()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasSeenOnboarding = true
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Text("Enable location & enter")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasSeenOnboarding = true
                        }
                    } label: {
                        Text("Continue without location")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedForeground)
                    }
                    .buttonStyle(.plain)

                    Text("Not affiliated with Flock Safety")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.mutedForeground)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
    }
}
