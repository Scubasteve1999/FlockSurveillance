import MapKit
import StoreKit
import SwiftUI
import UIKit

struct MapRadarView: View {
    @Environment(CameraRepository.self) private var repository
    @Environment(LocationManager.self) private var locationManager
    @Environment(ProximityRadar.self) private var radar
    @Environment(ReportStore.self) private var reportStore
    @Environment(\.requestReview) private var requestReview

    @AppStorage(AppPreferenceKey.showHeatDefault) private var showHeatStored = true
    @AppStorage(AppPreferenceKey.showSensorAtlas) private var showSensorAtlasStored = false
    @AppStorage(AppPreferenceKey.defaultFilter) private var defaultFilterRaw = CameraFilter.all.rawValue
    @AppStorage(AppPreferenceKey.watchModeEnabled) private var watchModeStored = false
    @AppStorage(AppPreferenceKey.hasAutoShownPlaceScore) private var hasAutoShownPlaceScore = false

    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.7490, longitude: -84.3880),
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
    )
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var filter: CameraFilter = AppPreferences.defaultFilter
    @State private var selectedCluster: CameraCluster?
    @State private var selectedSensor: PublicSensor?
    @State private var showHeat = AppPreferences.showHeatDefault
    @State private var showSensorAtlas = AppPreferences.showSensorAtlas
    @State private var sensorAtlasStore = SensorAtlasStore()
    @State private var pulsePhase = false
    @State private var placeScore: PlaceScore?
    @State private var placeScoreRadius: CLLocationDistance = 1609.34
    @State private var sharePayload: ShareActivityPayload?
    @State private var isPlacingReport = false
    @State private var reportTarget: ReportTarget?
    @State private var selectedPendingReport: PendingReport?
    @State private var cityRankings: [CityRanking] = []
    /// Recompute Place Score for this coordinate after the matching fetch settles.
    @State private var pendingScoreCoordinate: CLLocationCoordinate2D?
    /// When true, burn `hasAutoShownPlaceScore` only after pending score settles.
    @State private var pendingAutoShowBurn = false
    @State private var showARCameraSight = false
    @State private var showSharingNetwork = false

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

    /// Foreground proximity to a mapped ALPR pin and/or active corridor geofence state.
    private var inWatchedZone: Bool {
        let nearPin = (nearest?.meters ?? .infinity) <= AlertsEngine.regionRadius
        return nearPin || AlertsEngine.shared.isInsideWatchedZone
    }

    private var visibleSensors: [PublicSensor] {
        guard showSensorAtlas, let visibleRegion else { return [] }
        return sensorAtlasStore.sensors(in: visibleRegion)
    }

    private var coverageConfidence: CoverageConfidence {
        let hasViewportFetch: Bool = {
            guard let visible = visibleRegion,
                  let fetched = repository.lastFetchedRegion
            else { return false }
            return GeoHelpers.region(fetched, contains: visible.center)
        }()
        return CoverageConfidence.make(
            visibleCameras: camerasInView,
            isLoading: repository.isLoading,
            isSeeding: repository.isSeeding,
            isServingStale: repository.isServingStale,
            lastError: repository.lastError,
            lastSuccessfulFetchAt: repository.lastSuccessfulFetchAt,
            hasViewportFetch: hasViewportFetch
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                AppTheme.background.ignoresSafeArea()

                MapKitSizeGate(size: geo.size) { mapContent }

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
                    if !cityRankings.isEmpty, shouldShowRankings {
                        CityRankingsStrip(rankings: cityRankings) { city in
                            focusAndScore(coordinate: city.coordinate)
                        }
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if let placeScore {
                        PlaceScoreCard(
                            score: placeScore,
                            selectedRadiusMeters: placeScoreRadius,
                            onSelectRadius: { meters in
                                placeScoreRadius = meters
                                computePlaceScore()
                            },
                            onShare: { sharePlaceScore(placeScore) },
                            onClose: { self.placeScore = nil }
                        )
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    RadarHUD(
                        visibleCount: camerasInView.count,
                        nearestMeters: nearest?.meters,
                        nearestLabel: nearest.map { $0.camera.displayManufacturer },
                        inWatchedZone: inWatchedZone,
                        densityLabel: AppTheme.densityLabel(count: camerasInView.count),
                        confidence: coverageConfidence,
                        coverageHint: repository.coverageHint,
                        errorMessage: repository.lastError,
                        watchModeEnabled: radar.watchModeEnabled,
                        onToggleWatch: toggleWatchMode
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .padding(.top, 8)
            }
        }
        .onAppear {
            locationManager.start()
            showHeat = showHeatStored
            showSensorAtlas = showSensorAtlasStored
            filter = CameraFilter(rawValue: defaultFilterRaw) ?? .all
            radar.watchModeEnabled = watchModeStored
            sensorAtlasStore.loadIfNeeded()
            bootstrapRegion()
            startPulseIfNeeded()
            // Delay the auto Place Score until the map has had a beat to settle.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                maybeAutoShowPlaceScore()
            }
            cityRankings = GeoHelpers.cityRankings(from: repository.cameras)
            if PendingIntentActions.placeScoreRequested {
                PendingIntentActions.placeScoreRequested = false
                computePlaceScore()
            }
            applyPendingMapFocusIfNeeded()
            Task {
                await reportStore.verifyOpenReports(repository: repository)
            }
        }
        .onChange(of: repository.cameras.count) { _, _ in
            cityRankings = GeoHelpers.cityRankings(from: repository.cameras)
            maybeAutoShowPlaceScore()
            refreshPendingScoreIfNeeded()
        }
        .onChange(of: repository.isLoading) { _, loading in
            if !loading {
                refreshPendingScoreIfNeeded(allowClear: true)
            }
        }
        .onChange(of: repository.isSeeding) { _, seeding in
            if !seeding {
                maybeAutoShowPlaceScore()
                refreshPendingScoreIfNeeded(allowClear: true)
            }
        }
        .onChange(of: nearest?.meters) { _, meters in
            radar.update(userLocation: locationManager.location, nearestMeters: meters)
        }
        .onChange(of: locationManager.location?.coordinate.latitude) { _, _ in
            if visibleRegion == nil {
                bootstrapRegion()
            }
            maybeAutoShowPlaceScore()
        }
        .onChange(of: radar.watchModeEnabled) { _, enabled in
            watchModeStored = enabled
            startPulseIfNeeded()
        }
        .onChange(of: showHeat) { _, value in
            showHeatStored = value
        }
        .onChange(of: showSensorAtlas) { _, value in
            showSensorAtlasStored = value
            if value { sensorAtlasStore.loadIfNeeded() }
        }
        .onChange(of: filter) { _, value in
            defaultFilterRaw = value.rawValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .flockPlaceScore)) { _ in
            PendingIntentActions.placeScoreRequested = false
            computePlaceScore()
        }
        .onReceive(NotificationCenter.default.publisher(for: .flockMapFocus)) { _ in
            applyPendingMapFocusIfNeeded()
        }
        .sheet(item: $selectedCluster) { cluster in
            CameraDetailSheet(cameras: cluster.cameras, userLocation: locationManager.location)
                .presentationBackground(AppTheme.background)
        }
        .sheet(item: $selectedSensor) { sensor in
            SensorDetailSheet(sensor: sensor)
                .presentationBackground(AppTheme.background)
        }
        .sheet(item: $sharePayload) { payload in
            ActivityShareView(items: payload.items)
                .id(payload.id)
        }
        .sheet(item: $reportTarget) { target in
            ReportCameraSheet(coordinate: target.coordinate) { _ in
                // Pending pin appears via ReportStore.activeMapReports.
            }
            .presentationBackground(AppTheme.background)
        }
        .sheet(item: $selectedPendingReport) { report in
            PendingReportDetailSheet(
                report: report,
                onCheckAgain: {
                    Task {
                        await reportStore.verifyOpenReports(repository: repository, force: true)
                    }
                }
            )
            .presentationBackground(AppTheme.background)
        }
        .fullScreenCover(isPresented: $showARCameraSight) {
            ARCameraSightView()
        }
        .fullScreenCover(isPresented: $showSharingNetwork) {
            SharingNetworkView()
        }
    }

    private var shouldShowRankings: Bool {
        guard let region = visibleRegion else { return true }
        return GeoHelpers.dominantSpan(region) > 0.35 && placeScore == nil
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

            ForEach(reportStore.activeMapReports, id: \.id) { report in
                Annotation("", coordinate: report.coordinate, anchor: .center) {
                    Button {
                        selectedPendingReport = report
                    } label: {
                        PendingReportAnnotationView()
                    }
                    .buttonStyle(.plain)
                }
            }

            if showSensorAtlas {
                ForEach(visibleSensors) { sensor in
                    Annotation("", coordinate: sensor.coordinate, anchor: .center) {
                        Button {
                            selectedSensor = sensor
                        } label: {
                            SensorAnnotationView()
                        }
                        .buttonStyle(.plain)
                    }
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
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("FLOCK SURVEILLANCE")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.foreground)
                Text("How watched is your life right now?")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
            }
            Spacer(minLength: 8)
            HStack(spacing: 0) {
                headerRailButton(
                    systemName: "viewfinder",
                    tint: AppTheme.accent,
                    label: "AR Camera Sight"
                ) {
                    showARCameraSight = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                headerRailButton(
                    systemName: "point.3.connected.trianglepath.dotted",
                    tint: AppTheme.accent,
                    label: "Sharing network"
                ) {
                    showSharingNetwork = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                headerRailButton(
                    systemName: "flag.fill",
                    tint: isPlacingReport ? AppTheme.primary : AppTheme.accent,
                    label: "Report a camera"
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isPlacingReport.toggle()
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                headerRailButton(
                    systemName: "gauge.with.dots.needle.67percent",
                    tint: placeScore == nil ? AppTheme.accent : AppTheme.primary,
                    label: "Place score"
                ) {
                    computePlaceScore()
                }
                headerRailButton(
                    systemName: showHeat ? "circle.hexagongrid.fill" : "circle.hexagongrid",
                    tint: showHeat ? AppTheme.accent : AppTheme.mutedForeground,
                    label: showHeat ? "Hide coverage heat" : "Show coverage heat"
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showHeat.toggle()
                    }
                }
                headerRailButton(
                    systemName: showSensorAtlas ? "video.fill" : "video",
                    tint: showSensorAtlas ? AppTheme.trafficSensorMarker : AppTheme.mutedForeground,
                    label: showSensorAtlas ? "Hide Sensor Atlas traffic cameras" : "Show Sensor Atlas traffic cameras"
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showSensorAtlas.toggle()
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                headerRailButton(
                    systemName: "location.fill",
                    tint: AppTheme.accent,
                    label: "Center on my location"
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        position = .userLocation(fallback: .automatic)
                    }
                }
            }
            .padding(3)
            .background(AppTheme.card.opacity(0.92))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
        }
        .padding(.horizontal, 16)
    }

    private func headerRailButton(
        systemName: String,
        tint: Color,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSensorAtlas.toggle()
                }
            } label: {
                Text("Traffic cams")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(showSensorAtlas ? AppTheme.background : AppTheme.foreground)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(showSensorAtlas ? AppTheme.trafficSensorMarker : AppTheme.card.opacity(0.92))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.border, lineWidth: showSensorAtlas ? 0 : 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showSensorAtlas ? "Hide municipal traffic cameras" : "Show municipal traffic cameras")
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
        // Personal / map-center only — never invent Atlanta when nothing is known.
        guard let scoreCoordinate = locationManager.location?.coordinate
            ?? WidgetBridge.homeCoordinate()
            ?? visibleRegion?.center
        else { return }
        presentScore(at: scoreCoordinate, scheduleFetch: true)
    }

    private func maybeAutoShowPlaceScore() {
        guard !hasAutoShownPlaceScore else { return }
        // Personal coordinate only — don't burn the wow on Atlanta/viewport.
        guard let coordinate = locationManager.location?.coordinate ?? WidgetBridge.homeCoordinate()
        else { return }

        let score = repository.placeScore(near: coordinate, radiusMeters: placeScoreRadius)
        let settled = repository.hasSettledFetch(covering: coordinate)

        // Kick off once; later calls only refresh / burn when data is ready.
        if pendingScoreCoordinate == nil, placeScore == nil {
            presentScore(
                at: coordinate,
                scheduleFetch: true,
                burnAutoShowWhenSettled: true,
                publishOptimisticClear: false
            )
        } else if pendingAutoShowBurn, score.cameraCount > 0 {
            withAnimation(.easeInOut(duration: 0.2)) {
                placeScore = score
            }
        }

        // Burn only when we have nearby cameras, or a settled fetch for this spot
        // confirmed a real Clear (not "scheduled region" or failed Overpass).
        if GeoHelpers.shouldCommitPlaceScore(cameraCount: score.cameraCount, settled: settled) {
            hasAutoShownPlaceScore = true
            pendingAutoShowBurn = false
            withAnimation(.easeInOut(duration: 0.25)) {
                placeScore = score
            }
            if settled {
                pendingScoreCoordinate = nil
            }
        } else if placeScore?.cameraCount == 0 {
            // Hide optimistic false Clear while the covering fetch is still pending.
            placeScore = nil
        }
    }

    private func applyPendingMapFocusIfNeeded() {
        guard let coordinate = PendingIntentActions.mapFocusCoordinate else { return }
        PendingIntentActions.mapFocusCoordinate = nil
        presentScore(at: coordinate, scheduleFetch: true, moveCamera: true)
    }

    private func focusAndScore(coordinate: CLLocationCoordinate2D) {
        presentScore(at: coordinate, scheduleFetch: true, moveCamera: true)
    }

    private func presentScore(
        at coordinate: CLLocationCoordinate2D,
        scheduleFetch: Bool,
        moveCamera: Bool = false,
        burnAutoShowWhenSettled: Bool = false,
        publishOptimisticClear: Bool = true
    ) {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
        pendingScoreCoordinate = coordinate
        if burnAutoShowWhenSettled {
            pendingAutoShowBurn = true
        }
        if moveCamera {
            withAnimation(.easeInOut(duration: 0.35)) {
                position = .region(region)
                visibleRegion = region
            }
        }
        let score = repository.placeScore(near: coordinate, radiusMeters: placeScoreRadius)
        if publishOptimisticClear || score.cameraCount > 0 {
            withAnimation(.easeInOut(duration: 0.25)) {
                placeScore = score
            }
        }
        if scheduleFetch {
            repository.scheduleFetch(for: region, delayNanoseconds: 100_000_000)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func refreshPendingScoreIfNeeded(allowClear: Bool = false) {
        guard let coordinate = pendingScoreCoordinate else { return }
        let score = repository.placeScore(near: coordinate, radiusMeters: placeScoreRadius)
        let settled = repository.hasSettledFetch(covering: coordinate)

        if score.cameraCount > 0 {
            withAnimation(.easeInOut(duration: 0.2)) {
                placeScore = score
            }
            if pendingAutoShowBurn {
                hasAutoShownPlaceScore = true
                pendingAutoShowBurn = false
            }
        }

        // Clear only after a successful covering fetch completes.
        guard allowClear, settled else {
            if settled {
                pendingScoreCoordinate = nil
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            placeScore = score
        }
        pendingScoreCoordinate = nil
        if pendingAutoShowBurn {
            hasAutoShownPlaceScore = true
            pendingAutoShowBurn = false
        }
    }

    private func sharePlaceScore(_ score: PlaceScore) {
        Task { @MainActor in
            var items: [Any] = [score.shareText]
            if let image = ShareCardRenderer.placeScoreImage(score) {
                items.insert(image, at: 0)
            }
            if let link = score.mapDeepLink {
                items.append(link)
            }
            sharePayload = ShareActivityPayload(items: items)
            ReviewPrompter.recordHighSignalEvent(requestReview: requestReview)
        }
    }
}

private struct ShareActivityPayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct ReportTarget: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

private struct PendingReportAnnotationView: View {
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(AppTheme.accent.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                .background(Circle().fill(AppTheme.card.opacity(0.92)))
                .frame(width: 34, height: 34)
            Image(systemName: "flag.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.accent)
        }
        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
        .accessibilityLabel("Pending camera report")
    }
}

private struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
