import MapKit
import SwiftUI

struct DriveModeView: View {
    @Environment(DriveSession.self) private var driveSession
    @Environment(LocationManager.self) private var locationManager
    @Environment(ProximityRadar.self) private var radar
    @Environment(\.dismiss) private var dismiss

    @State private var mapPosition: MapCameraPosition = .userLocation(fallback: .automatic)

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
        .onDisappear {
            if driveSession.isActive {
                driveSession.stop()
            }
        }
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
                Text(next.isFlock ? "Next Flock ALPR" : "Next ALPR")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
                Text(driveSession.metersToNext.map(ProximityRadar.formatDistance) ?? "—")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppTheme.foreground)
                Text(next.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .lineLimit(1)
            } else {
                Text("Corridor clear")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.foreground)
                Text("No remaining mapped ALPRs on this drive.")
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
