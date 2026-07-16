import SwiftUI

/// First-open punch for Sensor Atlas: hero still, then the honest non-ALPR frame.
struct SensorDetailSheet: View {
    let sensor: PublicSensor
    var attribution: String?

    @State private var heroAppeared = false
    @State private var copyAppeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    copyBlock
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 28)
                        .opacity(copyAppeared ? 1 : 0)
                        .offset(y: copyAppeared ? 0 : 12)
                }
            }
            .background(AppTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SENSOR ATLAS")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.trafficSensorMarker)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                    heroAppeared = true
                }
                withAnimation(.easeOut(duration: 0.35).delay(0.12)) {
                    copyAppeared = true
                }
            }
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let url = sensor.resolvedImageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            heroFallback
                        case .empty:
                            ZStack {
                                heroFallback
                                ProgressView()
                                    .tint(AppTheme.trafficSensorMarker)
                            }
                        @unknown default:
                            heroFallback
                        }
                    }
                } else {
                    heroFallback
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 320)
            .clipped()
            .scaleEffect(heroAppeared ? 1 : 1.04)
            .opacity(heroAppeared ? 1 : 0.85)

            LinearGradient(
                colors: [.clear, AppTheme.background.opacity(0.92)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 160)
            .frame(maxHeight: .infinity, alignment: .bottom)

            VStack(alignment: .leading, spacing: 10) {
                Text("PUBLIC TRAFFIC CAM")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.background)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.trafficSensorMarker)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                Text("Not an ALPR.\nNot Flock Safety.")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .opacity(copyAppeared ? 1 : 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Public traffic camera, not an ALPR, not Flock Safety. \(sensor.displayName)")
    }

    private var heroFallback: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.cardTop,
                    AppTheme.background,
                    AppTheme.trafficSensorMarker.opacity(0.25),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "video.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(AppTheme.trafficSensorMarker.opacity(0.55))
        }
    }

    private var copyBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(sensor.displayName)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.foreground)

            if let highway = sensor.displayHighway {
                Text(highway)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
            }

            Text("Municipal traveler camera in \(sensor.city). Opening a still contacts WisDOT — the app does not collect the image. Proximity alerts never use these pins.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                StatusBadge(text: sensor.city, color: AppTheme.trafficSensorMarker)
                StatusBadge(text: "Not ALPR", color: AppTheme.accent)
            }

            if sensor.resolvedImageURL != nil {
                Text("Still from \(sensor.resolvedImageURL?.host ?? "WisDOT") · traveler info only")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
            } else {
                Text("No WisDOT still linked for this pin in the inventory snapshot.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
            }

            if let attribution, !attribution.isEmpty {
                Text(attribution)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground.opacity(0.85))
                    .padding(.top, 4)
            }
        }
    }
}
