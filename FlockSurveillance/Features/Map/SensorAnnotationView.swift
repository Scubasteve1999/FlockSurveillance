import SwiftUI

struct SensorAnnotationView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(AppTheme.trafficSensorMarker.opacity(0.25))
                .frame(width: 34, height: 34)
            Image(systemName: "video.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.background)
                .padding(7)
                .background(AppTheme.trafficSensorMarker, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                )
        }
        .shadow(color: AppTheme.trafficSensorMarker.opacity(0.4), radius: 5, y: 2)
        .accessibilityLabel("Municipal traffic camera, not ALPR")
    }
}
