import MapKit
import StoreKit
import SwiftUI

struct DriveModeView: View {
    @Environment(DriveSession.self) private var driveSession
    @Environment(LocationManager.self) private var locationManager
    @Environment(ProximityRadar.self) private var radar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    @State private var mapPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    /// Accumulated rotation so the arrow takes the short way across north
    /// (359° -> 1° must not spin the long way around).
    @State private var arrowAngle: Double = 0

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $mapPosition) {
                UserAnnotation()
                if let route = driveSession.route {
                    MapPolyline(route.polyline)
                        .stroke(AppTheme.accent, lineWidth: 5)
                }
                ForEach(driveSession.hits) { hit in
                    Annotation("", coordinate: hit.coordinate) {
                        CameraAnnotationView(
                            count: 1,
                            isFlock: hit.isFlock
                        )
                        .opacity(driveSession.passedIDs.contains(hit.id) ? 0.35 : 1)
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll, showsTraffic: true))
            .ignoresSafeArea()

            VStack(spacing: 12) {
                driveHUD
                Spacer()
                Button {
                    driveSession.stop()
                    ReviewPrompter.recordHighSignalEvent(requestReview: requestReview)
                    dismiss()
                } label: {
                    Text("End Drive")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(AppTheme.background)
                        .background(AppTheme.primary)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .padding(.top, 16)
        }
        .onAppear {
            locationManager.start()
            driveSession.update(userLocation: locationManager.location, hapticsEnabled: radar.hapticsEnabled)
            if let route = driveSession.route,
               let rect = GeoHelpers.mapRect(covering: route.polyline.coordinates) {
                mapPosition = .rect(rect)
            }
        }
        .onChange(of: locationManager.location?.coordinate.latitude) { _, _ in
            driveSession.update(userLocation: locationManager.location, hapticsEnabled: radar.hapticsEnabled)
            if let location = locationManager.location {
                mapPosition = .camera(
                    MapCamera(
                        centerCoordinate: location.coordinate,
                        distance: 900,
                        heading: location.course >= 0 ? location.course : 0,
                        pitch: 45
                    )
                )
            }
        }
        .onChange(of: currentRelativeBearing) { _, newBearing in
            guard let newBearing else { return }
            let current = arrowAngle.truncatingRemainder(dividingBy: 360)
            var delta = (newBearing - current).truncatingRemainder(dividingBy: 360)
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }
            withAnimation(.easeInOut(duration: 0.3)) {
                arrowAngle += delta
            }
        }
    }

    private var currentRelativeBearing: Double? {
        driveSession.nextHit.flatMap { relativeBearing(to: $0) }
    }

    /// Screen-relative bearing to the next hit: 0 = straight ahead of the phone's compass heading.
    private func relativeBearing(to hit: DriveHit) -> Double? {
        guard let userCoordinate = locationManager.location?.coordinate,
              let heading = locationManager.headingDegrees
        else { return nil }
        let absolute = GeoHelpers.bearing(from: userCoordinate, to: hit.coordinate)
        return (absolute - heading + 360).truncatingRemainder(dividingBy: 360)
    }

    private var driveHUD: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DRIVE MODE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.primary)
                Spacer()
                StatusBadge(text: driveSession.exposureLabel, color: AppTheme.densityColor(count: driveSession.hits.count))
            }

            if let next = driveSession.nextHit {
                Text(next.isFlock ? "Next Flock camera" : "Next camera")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
                HStack(spacing: 10) {
                    Text(driveSession.metersToNext.map(ProximityRadar.formatDistance) ?? "—")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppTheme.foreground)
                    if relativeBearing(to: next) != nil {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                            .rotationEffect(.degrees(arrowAngle))
                            .accessibilityLabel("Direction to next camera")
                    }
                }
                Text(next.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .lineLimit(1)
            } else {
                Text("Corridor clear")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.foreground)
                Text("No remaining mapped cameras on this drive.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
            }

            Text("\(driveSession.camerasRemaining) cameras remaining")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.mutedForeground)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}
