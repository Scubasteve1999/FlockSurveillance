import MapKit
import StoreKit
import SwiftUI
import UIKit

struct MapRadarView: View {
    @Environment(CameraRepository.self) private var repository
    @Environment(LocationManager.self) private var locationManager
    @Environment(ProximityRadar.self) private var radar
    @Environment(\.requestReview) private var requestReview

    @AppStorage(AppPreferenceKey.showHeatDefault) private var showHeatStored = true
    @AppStorage(AppPreferenceKey.defaultFilter) private var defaultFilterRaw = CameraFilter.all.rawValue
    @AppStorage(AppPreferenceKey.watchModeEnabled) private var watchModeStored = false

    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.7490, longitude: -84.3880),
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
    )
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var filter: CameraFilter = AppPreferences.defaultFilter
    @State private var selectedCluster: CameraCluster?
    @State private var showHeat = AppPreferences.showHeatDefault
    @State private var pulsePhase = false
    @State private var placeScore: PlaceScore?
    @State private var placeScoreRadius: CLLocationDistance = 1609.34
    @State private var shareText: String?
    @State private var isPlacingReport = false
    @State private var reportTarget: ReportTarget?
    /// MapKit hangs if inserted at zero size (CAMetalLayer width=0). Wait for layout.
    @State private var mapReady = false

    private var locationDenied: Bool {
        let status = locationManager.authorizationStatus
        return status == .denied || status == .restricted
    }

    private var clusters: [CameraCluster] {
        guard let visibleRegion else { return [] }
        return repository.clusters(for: filter, in: visibleRegion)
    }

    private var camerasInView: [ALPRCamera] {
        // Never fall back to the full cache — that can be thousands of rows and
        // stalls the first Map paint (especially on iPad).
        guard let region = visibleRegion else { return [] }
        return repository.cameras(in: region, filter: filter)
    }

    private var nearest: (camera: ALPRCamera, meters: CLLocationDistance)? {
        guard let coordinate = locationManager.location?.coordinate else { return nil }
        return repository.nearest(to: coordinate, filter: filter)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                AppTheme.background.ignoresSafeArea()

                if mapReady, geo.size.width > 1, geo.size.height > 1 {
                    mapContent
                } else {
                    ProgressView()
                        .tint(AppTheme.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if isPlacingReport {
                    Image(systemName: "plus.viewfinder")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(AppTheme.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }

                VStack(spacing: 12) {
                    brandHeader
                    filterBar
                    if locationDenied {
                        LocationDeniedBanner()
                    }
                    Spacer()
                    if isPlacingReport {
                        reportPlacementBar
                            .padding(.horizontal, 16)
                    }
                    if let placeScore {
                        PlaceScoreCard(
                            score: placeScore,
                            selectedRadiusMeters: placeScoreRadius,
                            onSelectRadius: { meters in
                                placeScoreRadius = meters
                                computePlaceScore()
                            },
                            onShare: {
                                shareText = placeScore.shareText
                                ReviewPrompter.recordHighSignalEvent(requestReview: requestReview)
                            },
                            onClose: { self.placeScore = nil }
                        )
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    RadarHUD(
                        visibleCount: camerasInView.count,
                        nearestMeters: nearest?.meters,
                        nearestLabel: nearest.map { $0.camera.displayManufacturer },
                        densityLabel: AppTheme.densityLabel(count: camerasInView.count),
                        isLoading: repository.isLoading || repository.isSeeding,
                        errorMessage: repository.lastError,
                        coverageHint: repository.coverageHint,
                        freshnessLabel: repository.freshnessLabel,
                        watchModeEnabled: radar.watchModeEnabled,
                        onToggleWatch: toggleWatchMode
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .padding(.top, 8)
            }
            .onChange(of: geo.size) { _, size in
                guard !mapReady, size.width > 1, size.height > 1 else { return }
                // Yield so SwiftUI finishes the onboarding → tab transition first.
                Task { @MainActor in
                    await Task.yield()
                    mapReady = true
                }
            }
        }
        .onAppear {
            locationManager.start()
            showHeat = showHeatStored
            filter = CameraFilter(rawValue: defaultFilterRaw) ?? .all
            radar.watchModeEnabled = watchModeStored
            bootstrapRegion()
            startPulseIfNeeded()
            if PendingIntentActions.placeScoreRequested {
                PendingIntentActions.placeScoreRequested = false
                computePlaceScore()
            }
        }
        .onChange(of: nearest?.meters) { _, meters in
            radar.update(userLocation: locationManager.location, nearestMeters: meters)
        }
        .onChange(of: locationManager.location?.coordinate.latitude) { _, _ in
            if visibleRegion == nil {
                bootstrapRegion()
            }
        }
        .onChange(of: radar.watchModeEnabled) { _, enabled in
            watchModeStored = enabled
            startPulseIfNeeded()
        }
        .onChange(of: showHeat) { _, value in
            showHeatStored = value
        }
        .onChange(of: filter) { _, value in
            defaultFilterRaw = value.rawValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .flockPlaceScore)) { _ in
            PendingIntentActions.placeScoreRequested = false
            computePlaceScore()
        }
        .sheet(item: $selectedCluster) { cluster in
            CameraDetailSheet(cameras: cluster.cameras, userLocation: locationManager.location)
                .presentationBackground(AppTheme.background)
        }
        .sheet(item: Binding(
            get: { shareText.map { ShareTextPayload(text: $0) } },
            set: { shareText = $0?.text }
        )) { payload in
            ActivityShareView(items: [payload.text])
        }
        .sheet(item: $reportTarget) { target in
            ReportCameraSheet(coordinate: target.coordinate)
                .presentationBackground(AppTheme.background)
        }
    }

    private var mapContent: some View {
        Map(position: $position) {
            UserAnnotation()

            if radar.watchModeEnabled, let nearest, let user = locationManager.location?.coordinate {
                MapCircle(center: user, radius: max(nearest.meters, 25))
                    .foregroundStyle(AppTheme.primary.opacity(pulsePhase ? 0.18 : 0.08))
                MapCircle(center: user, radius: max(nearest.meters * 0.55, 18))
                    .foregroundStyle(AppTheme.accent.opacity(pulsePhase ? 0.16 : 0.06))
            }

            if showHeat {
                ForEach(clusters.prefix(80)) { cluster in
                    MapCircle(center: cluster.coordinate, radius: heatRadius(for: cluster.count))
                        .foregroundStyle(AppTheme.densityColor(count: cluster.count).opacity(0.14))
                }
            }

            ForEach(fovCameras) { camera in
                if let degrees = GeoHelpers.directionDegrees(from: camera.direction) {
                    MapPolygon(
                        coordinates: GeoHelpers.fovPolygon(
                            center: camera.coordinate,
                            bearingDegrees: degrees
                        )
                    )
                    .foregroundStyle(
                        (camera.isFlock ? AppTheme.flockMarker : AppTheme.otherMarker).opacity(0.22)
                    )
                }
            }

            ForEach(clusters.prefix(120)) { cluster in
                Annotation("", coordinate: cluster.coordinate, anchor: .center) {
                    Button {
                        selectedCluster = cluster
                    } label: {
                        CameraAnnotationView(count: cluster.count, isFlock: cluster.isFlockDominant)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleRegion = context.region
            repository.scheduleFetch(for: context.region)
        }
        .ignoresSafeArea()
    }

    private var reportPlacementBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Report a camera")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.foreground)
                Text("Pan so the crosshair is on the camera")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
            }
            Spacer()
            Button {
                if let center = visibleRegion?.center {
                    reportTarget = ReportTarget(coordinate: center)
                }
                withAnimation(.easeInOut(duration: 0.25)) {
                    isPlacingReport = false
                }
            } label: {
                Text("Here")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.background)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(AppTheme.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var fovCameras: [ALPRCamera] {
        camerasInView
            .filter { GeoHelpers.directionDegrees(from: $0.direction) != nil }
            .prefix(40)
            .map { $0 }
    }

    private var brandHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("FLOCK SURVEILLANCE")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.foreground)
                Text("How watched is your life right now?")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
            }
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isPlacingReport.toggle()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "flag.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isPlacingReport ? AppTheme.primary : AppTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.card.opacity(0.92))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
            }
            .accessibilityLabel("Report a camera")

            Button {
                computePlaceScore()
            } label: {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(placeScore == nil ? AppTheme.accent : AppTheme.primary)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.card.opacity(0.92))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
            }
            .accessibilityLabel("Place score")

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showHeat.toggle()
                }
            } label: {
                Image(systemName: showHeat ? "circle.hexagongrid.fill" : "circle.hexagongrid")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(showHeat ? AppTheme.accent : AppTheme.mutedForeground)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.card.opacity(0.92))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
            }
            .accessibilityLabel(showHeat ? "Hide coverage heat" : "Show coverage heat")

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    position = .userLocation(fallback: .automatic)
                }
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.card.opacity(0.92))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
            }
            .accessibilityLabel("Center on my location")
        }
        .padding(.horizontal, 16)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(CameraFilter.allCases) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        filter = item
                    }
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(filter == item ? AppTheme.background : AppTheme.foreground)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(filter == item ? AppTheme.primary : AppTheme.card.opacity(0.92))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.border, lineWidth: filter == item ? 0 : 1))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Toggle(isOn: Binding(
                get: { radar.hapticsEnabled },
                set: { radar.hapticsEnabled = $0 }
            )) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 13, weight: .semibold))
            }
            .toggleStyle(.button)
            .tint(radar.hapticsEnabled ? AppTheme.accent : AppTheme.mutedForeground)
            .padding(.trailing, 4)
            .accessibilityLabel("Proximity haptics")
        }
        .padding(.horizontal, 16)
    }

    private func toggleWatchMode() {
        withAnimation(.easeInOut(duration: 0.25)) {
            radar.watchModeEnabled.toggle()
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func startPulseIfNeeded() {
        guard radar.watchModeEnabled else { return }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pulsePhase = true
        }
    }

    private func bootstrapRegion() {
        if let location = locationManager.location {
            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )
            visibleRegion = region
            repository.scheduleFetch(for: region, delayNanoseconds: 100_000_000)
        } else if visibleRegion == nil {
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 33.7490, longitude: -84.3880),
                span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
            )
            visibleRegion = region
            position = .region(region)
            repository.scheduleFetch(for: region, delayNanoseconds: 100_000_000)
        }
    }

    private func heatRadius(for count: Int) -> CLLocationDistance {
        switch count {
        case 1: return 90
        case 2...4: return 140
        default: return 200
        }
    }

    private func computePlaceScore() {
        // Prefer current location, then viewport center, then Home, then Atlanta fallback.
        let scoreCoordinate = locationManager.location?.coordinate
            ?? visibleRegion?.center
            ?? WidgetBridge.homeCoordinate()
            ?? CLLocationCoordinate2D(latitude: 33.7490, longitude: -84.3880)
        withAnimation(.easeInOut(duration: 0.25)) {
            placeScore = repository.placeScore(near: scoreCoordinate, radiusMeters: placeScoreRadius)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

private struct ShareTextPayload: Identifiable {
    let id = UUID()
    let text: String
}

private struct ReportTarget: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

private struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
