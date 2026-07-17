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
    @State private var pulse = false

    private var driveLevel: SurveillanceLevel {
        SurveillanceLevel.compute(
            visibleCount: driveSession.camerasRemaining,
            nearestMeters: driveSession.metersToNext,
            inWatchedZone: (driveSession.metersToNext ?? .infinity) <= AlertsEngine.regionRadius
        )
    }

    private var inHotApproach: Bool {
        (driveSession.metersToNext ?? .infinity) <= 100
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $mapPosition) {
                UserAnnotation()
                if let route = driveSession.route {
                    MapPolyline(route.polyline)
                        .stroke(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.primary],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 5
                        )
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

            if inHotApproach {
                WatchedZoneEdgeAlert(level: driveLevel)
            }

            VStack(spacing: 12) {
                driveHUD
                Spacer()
                Button {
                    driveSession.stop()
                    ReviewPrompter.recordHighSignalEvent(requestReview: requestReview)
                    dismiss()
                } label: {
                    Text("END DRIVE")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(AppTheme.background)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.primary, AppTheme.critical],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: AppTheme.primary.opacity(0.45), radius: 12, y: 0)
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
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                pulse = true
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
        .onChange(of: driveLevel) { previous, current in
            OverwatchAudio.stingIfEnteringCritical(previous: previous, current: current)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(driveLevel.color)
                    .frame(width: 7, height: 7)
                    .opacity(pulse ? 0.25 : 1)
                    .shadow(color: driveLevel.color.opacity(0.8), radius: 4)
                Text("OVERWATCH · DRIVE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(driveLevel.color)
                Spacer()
                StatusBadge(text: driveLevel.chip, color: driveLevel.color)
                StatusBadge(
                    text: driveSession.exposureLabel.uppercased(),
                    color: AppTheme.densityColor(count: driveSession.hits.count)
                )
            }

            if let next = driveSession.nextHit {
                Text(next.isFlock ? "NEXT FLOCK PIN" : "NEXT MAPPED PIN")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.mutedForeground)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("LOCK")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.mutedForeground)
                    Text(driveSession.metersToNext.map(ProximityRadar.formatDistance) ?? "—")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(inHotApproach ? AppTheme.critical : AppTheme.foreground)
                        .contentTransition(.numericText())
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

                if inHotApproach {
                    Text("HOT APPROACH — mapped pin only, not a plate read")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.critical.opacity(0.9))
                }
            } else {
                Text("CORRIDOR CLEAR")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.densityLow)
                Text("No remaining mapped cameras on this drive.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
            }

            // Remaining meter
            GeometryReader { geo in
                let total = max(driveSession.hits.count, 1)
                let remaining = driveSession.camerasRemaining
                let fill = CGFloat(remaining) / CGFloat(total)
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.border.opacity(0.5))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, driveLevel.color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, geo.size.width * fill))
                }
            }
            .frame(height: 5)

            HStack {
                Text("\(driveSession.camerasRemaining) GRID AHEAD")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.mutedForeground)
                Spacer()
                Text(driveLevel.title)
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(driveLevel.color)
            }
        }
        .padding(16)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                driveLevel.color.opacity(inHotApproach ? 0.2 : 0.08),
                                AppTheme.card.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(
                    inHotApproach ? driveLevel.color.opacity(pulse ? 0.4 : 0.95) : AppTheme.border,
                    lineWidth: inHotApproach ? 1.5 : 1
                )
        )
        .shadow(color: inHotApproach ? driveLevel.color.opacity(0.35) : .clear, radius: 14, y: 0)
        .padding(.horizontal, 16)
    }
}
