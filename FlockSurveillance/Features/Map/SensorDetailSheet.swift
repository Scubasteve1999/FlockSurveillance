import SwiftUI

struct SensorDetailSheet: View {
    let sensor: PublicSensor

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(sensor.disclaimer)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.background)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.trafficSensorMarker)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text(sensor.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.foreground)

                    if !sensor.highway.isEmpty {
                        Text(sensor.highway)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground)
                    }

                    labeled("City", sensor.city)
                    labeled("Source", sensor.source)
                    labeled("Kind", "Municipal traffic CCTV")

                    if let url = sensor.resolvedImageURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            case .failure:
                                Text("Still image unavailable right now.")
                                    .foregroundStyle(AppTheme.mutedForeground)
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            @unknown default:
                                EmptyView()
                            }
                        }
                        Text("Traveler still image from WisDOT when available. Not an ALPR feed.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground)
                    } else {
                        Text("No public still linked for this camera in the inventory snapshot.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .navigationTitle("Sensor Atlas")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(AppTheme.mutedForeground)
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.foreground)
        }
    }
}
