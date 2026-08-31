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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(AppPreferenceKey.showHeatDefault) private var showHeatStored = true
    @AppStorage(AppPreferenceKey.showSensorAtlas) private var showSensorAtlasStored = false
    @AppStorage(AppPreferenceKey.showOliveBranchEntrances) private var showOliveBranchEntrancesStored = false
    @AppStorage(AppPreferenceKey.defaultFilter) private var defaultFilterRaw = CameraFilter.all.rawValue
    @AppStorage(AppPreferenceKey.watchModeEnabled) private var watchModeStored = false
    @AppStorage(AppPreferenceKey.hasAutoShownPlaceScore) private var hasAutoShownPlaceScore = false

    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: GeoHelpers.memphisCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
    )
    @State private var lastSurveillanceLevel: SurveillanceLevel?
    @State private var showBootBanner = true
    @State private var lastInWatchedZone = false
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var filter: CameraFilter = AppPreferences.defaultFilter
    @State private var selectedCluster: CameraCluster?
    @State private var selectedSensor: PublicSensor?
    @State private var showHeat = AppPreferences.showHeatDefault
    @State private var showSensorAtlas = AppPreferences.showSensorAtlas
    @State private var sensorAtlasStore = SensorAtlasStore()
    @State private var showOliveBranchEntrances = AppPreferences.showOliveBranchEntrances
    @State private var entranceStore = OliveBranchEntranceStore()
    @State private var selectedEntranceSite: OliveBranchUniqueSite?
    /// Hold the shared engine so SwiftUI observes corridor enter/exit for the HUD.
    @State private var alertsEngine = AlertsEngine.shared
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
    /// Banner after auto-enabling Traffic cams in Madison / Milwaukee.
    @State private var sensorAtlasBanner: String?
    @State private var isAutoTogglingSensorAtlas = false
    /// Prevents re-entrant auto-enable before `onChange` clears the toggle flag.
    @State private var sensorAtlasAutoEnableInFlight = false
    @State private var sensorAtlasBannerDismissTask: Task<Void, Never>?
    @State private var entranceBanner: String?
    @State private var isAutoTogglingEntrances = false
    @State private var entranceAutoEnableInFlight = false
    @State private var entranceBannerDismissTask: Task<Void, Never>?
    /// City rankings strip is opt-in so Map first paint stays one status band + tools.
    @State private var showCityRankings = false

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
        return nearPin || alertsEngine.isInsideWatchedZone
    }

    private var visibleSensors: [PublicSensor] {
        guard showSensorAtlas, let visibleRegion else { return [] }
        return sensorAtlasStore.sensors(in: visibleRegion)
    }

    private var visibleEntranceSites: [OliveBranchUniqueSite] {
        guard showOliveBranchEntrances, let visibleRegion else { return [] }
        return entranceStore.uniqueSites(in: visibleRegion)
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

    private var surveillanceLevel: SurveillanceLevel {
        SurveillanceLevel.compute(
            visibleCount: camerasInView.count,
            nearestMeters: nearest?.meters,
            inWatchedZone: inWatchedZone
        )
    }

    /// Keep repository sparse/seed hints. After a successful fetch with 0 pins in view, name the next tap.
    private var mapCoverageHint: String? {
        if let hint = repository.coverageHint { return hint }
        guard camerasInView.isEmpty,
              !locationDenied,
              !repository.isLoading,
              repository.lastSuccessfulFetchAt != nil
        else { return nil }
        return "Zoom into a city, or tap Report on the tool rail."
    }

    var body: some View {
        GeometryReader { geo in
            mapStack(size: geo.size)
        }
        .onAppear(perform: handleAppear)
        .onDisappear(perform: handleDisappear)
        .onChange(of: repository.cameras.count) { _, _ in handleCamerasCountChange() }
        .onChange(of: repository.isLoading) { _, loading in handleLoadingChange(loading) }
        .onChange(of: repository.isSeeding) { _, seeding in handleSeedingChange(seeding) }
        .onChange(of: nearest?.meters) { _, meters in handleNearestMetersChange(meters) }
        .onChange(of: inWatchedZone) { _, _ in handleWatchedZoneChange() }
        .onChange(of: SensorAtlasAutoPolicy.locationKey(locationManager.location?.coordinate)) { _, _ in
            handleLocationKeyChange()
        }
        .onChange(of: radar.watchModeEnabled) { _, enabled in handleWatchModeChange(enabled) }
        .onChange(of: showHeat) { _, value in showHeatStored = value }
        .onChange(of: showSensorAtlas) { _, value in handleSensorAtlasToggle(value) }
        .onChange(of: showOliveBranchEntrances) { _, value in handleEntranceToggle(value) }
        .onChange(of: filter) { _, value in defaultFilterRaw = value.rawValue }
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
            SensorDetailSheet(sensor: sensor, attribution: sensorAtlasStore.attribution)
                .presentationBackground(AppTheme.background)
        }
        .sheet(item: $selectedEntranceSite) { site in
            EntranceSiteDetailSheet(
                site: site,
                nearestPin: site.nearestOsmNode.flatMap { entranceStore.pin(id: $0) }
            )
            .presentationBackground(AppTheme.background)
        }
        .sheet(item: $sharePayload) { payload in
            ActivityShareView(items: payload.items)
                .id(payload.id)
        }
        .sheet(item: $reportTarget) { target in
            ReportCameraSheet(coordinate: target.coordinate) { _ in }
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

    @ViewBuilder
    private func mapStack(size: CGSize) -> some View {
        ZStack(alignment: .top) {
            AppTheme.background.ignoresSafeArea()
            MapKitSizeGate(size: size) { mapContent }
            if inWatchedZone || surveillanceLevel >= .high {
                OverwatchScanlines(intensity: surveillanceLevel == .critical ? 0.18 : 0.1)
                    .transition(.opacity)
            }
            if inWatchedZone {
                WatchedZoneEdgeAlert(level: surveillanceLevel)
                    .transition(.opacity)
            }
            if isPlacingReport {
                Image(systemName: "plus.viewfinder")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(AppTheme.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
            mapChrome
        }
    }

    private var mapChrome: some View {
        VStack(spacing: 10) {
            if showBootBanner {
                OverwatchBootBanner(
                    visibleCount: camerasInView.count,
                    level: surveillanceLevel
                ) {
                    showBootBanner = false
                }
            }
            toolRail
            filterBar
            if showSensorAtlas, let atlasError = sensorAtlasStore.loadError {
                Text(atlasError)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let sensorAtlasBanner {
                SensorAtlasBanner(text: sensorAtlasBanner) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.sensorAtlasBanner = nil
                    }
                }
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            if showOliveBranchEntrances, let entranceError = entranceStore.loadError {
                Text(entranceError)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let entranceBanner {
                EntranceLayerBanner(text: entranceBanner) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.entranceBanner = nil
                    }
                }
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            if showOliveBranchEntrances, entranceStore.loadError == nil {
                Text("Reconstructed city-limit crossings — not official 2022 Utility sites. No pin ≠ skipped entrance.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if locationDenied {
                LocationDeniedBanner()
            }
            Spacer()
            if isPlacingReport {
                reportPlacementBar
                    .padding(.horizontal, 16)
            }
            if !cityRankings.isEmpty, showCityRankings, placeScore == nil {
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
                coverageHint: mapCoverageHint,
                errorMessage: repository.lastError,
                watchModeEnabled: radar.watchModeEnabled,
                onToggleWatch: toggleWatchMode
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
    }

    private func handleAppear() {
        locationManager.start()
        showHeat = showHeatStored
        showSensorAtlas = showSensorAtlasStored
        showOliveBranchEntrances = showOliveBranchEntrancesStored
        filter = CameraFilter(rawValue: defaultFilterRaw) ?? .all
        radar.watchModeEnabled = watchModeStored
        sensorAtlasStore.loadIfNeeded()
        entranceStore.loadIfNeeded()
        bootstrapRegion()
        startPulseIfNeeded()
        maybeAutoEnableSensorAtlas()
        maybeAutoEnableEntrances()
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
        lastInWatchedZone = inWatchedZone
        noteSurveillanceLevel()
    }

    private func handleDisappear() {
        sensorAtlasBannerDismissTask?.cancel()
        sensorAtlasBannerDismissTask = nil
        entranceBannerDismissTask?.cancel()
        entranceBannerDismissTask = nil
    }

    private func handleCamerasCountChange() {
        cityRankings = GeoHelpers.cityRankings(from: repository.cameras)
        maybeAutoShowPlaceScore()
        refreshPendingScoreIfNeeded()
        noteSurveillanceLevel()
    }

    private func handleLoadingChange(_ loading: Bool) {
        if !loading {
            refreshPendingScoreIfNeeded(allowClear: true)
        }
    }

    private func handleSeedingChange(_ seeding: Bool) {
        if !seeding {
            maybeAutoShowPlaceScore()
            refreshPendingScoreIfNeeded(allowClear: true)
        }
    }

    private func handleNearestMetersChange(_ meters: CLLocationDistance?) {
        radar.update(userLocation: locationManager.location, nearestMeters: meters)
        noteSurveillanceLevel()
    }

    private func handleWatchedZoneChange() {
        let inside = inWatchedZone
        if inside, !lastInWatchedZone {
            OverwatchAudio.zoneEnter()
        } else if !inside, lastInWatchedZone {
            OverwatchAudio.zoneExit()
        }
        lastInWatchedZone = inside
        noteSurveillanceLevel()
        startPulseIfNeeded()
    }

    private func handleLocationKeyChange() {
        if visibleRegion == nil {
            bootstrapRegion()
        }
        maybeAutoShowPlaceScore()
        maybeAutoEnableSensorAtlas()
        maybeAutoEnableEntrances()
    }

    private func handleWatchModeChange(_ enabled: Bool) {
        watchModeStored = enabled
        if enabled { OverwatchAudio.armClick() }
        startPulseIfNeeded()
    }

    private func handleSensorAtlasToggle(_ value: Bool) {
        showSensorAtlasStored = value
        if value {
            sensorAtlasStore.loadIfNeeded()
            if !isAutoTogglingSensorAtlas {
                AppPreferences.sensorAtlasSuppressedMetros =
                    SensorAtlasAutoPolicy.suppressedAfterManualOn(
                        current: AppPreferences.sensorAtlasSuppressedMetros
                    )
            }
        } else if !isAutoTogglingSensorAtlas {
            AppPreferences.sensorAtlasSuppressedMetros =
                SensorAtlasAutoPolicy.suppressedAfterManualOff(
                    current: AppPreferences.sensorAtlasSuppressedMetros,
                    coordinate: locationManager.location?.coordinate
                )
            sensorAtlasBanner = nil
            sensorAtlasBannerDismissTask?.cancel()
            sensorAtlasBannerDismissTask = nil
        }
        isAutoTogglingSensorAtlas = false
        sensorAtlasAutoEnableInFlight = false
    }

    private func handleEntranceToggle(_ value: Bool) {
        showOliveBranchEntrancesStored = value
        if value {
            entranceStore.loadIfNeeded()
            if !isAutoTogglingEntrances {
                AppPreferences.oliveBranchEntrancesAutoSuppressed =
                    OliveBranchEntranceAutoPolicy.suppressedAfterManualOn(
                        current: AppPreferences.oliveBranchEntrancesAutoSuppressed
                    )
            }
        } else if !isAutoTogglingEntrances {
            AppPreferences.oliveBranchEntrancesAutoSuppressed =
                OliveBranchEntranceAutoPolicy.suppressedAfterManualOff(
                    current: AppPreferences.oliveBranchEntrancesAutoSuppressed
                )
            entranceBanner = nil
            entranceBannerDismissTask?.cancel()
            entranceBannerDismissTask = nil
        }
        isAutoTogglingEntrances = false
        entranceAutoEnableInFlight = false
    }

    private func noteSurveillanceLevel() {
        let next = surveillanceLevel
        OverwatchAudio.stingIfEnteringCritical(previous: lastSurveillanceLevel, current: next)
        lastSurveillanceLevel = next
    }

    private var mapContent: some View {
        Map(position: $position) {
            UserAnnotation()

            if radar.watchModeEnabled || inWatchedZone,
               let nearest,
               let user = locationManager.location?.coordinate {
                let hot = inWatchedZone
                MapCircle(center: user, radius: max(nearest.meters, 25))
                    .foregroundStyle(
                        (hot ? AppTheme.critical : AppTheme.primary)
                            .opacity(pulsePhase ? (hot ? 0.28 : 0.18) : (hot ? 0.12 : 0.08))
                    )
                MapCircle(center: user, radius: max(nearest.meters * 0.55, 18))
                    .foregroundStyle(
                        AppTheme.accent.opacity(pulsePhase ? (hot ? 0.22 : 0.16) : 0.06)
                    )
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

            if showOliveBranchEntrances {
                ForEach(visibleEntranceSites) { site in
                    Annotation("", coordinate: site.coordinate, anchor: .center) {
                        Button {
                            selectedEntranceSite = site
                        } label: {
                            EntranceSiteAnnotationView(site: site)
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
                guard let center = visibleRegion?.center else { return }
                reportTarget = ReportTarget(coordinate: center)
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
            .disabled(visibleRegion == nil)
            .opacity(visibleRegion == nil ? 0.45 : 1)
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

    /// Compact tool rail only — RadarHUD carries status; no second brand band.
    private var toolRail: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
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
                    label: showHeat ? "Hide mapped-pin density" : "Show mapped-pin density"
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showHeat.toggle()
                    }
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
            ScrollView(.horizontal, showsIndicators: false) {
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
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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

                    if !cityRankings.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCityRankings.toggle()
                                if showCityRankings { placeScore = nil }
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text("METROS")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundStyle(showCityRankings ? AppTheme.background : AppTheme.foreground)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(showCityRankings ? AppTheme.accent : AppTheme.card.opacity(0.92))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(AppTheme.border, lineWidth: showCityRankings ? 0 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(showCityRankings ? "Hide city rankings" : "Show city rankings")
                    }
                }
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showOliveBranchEntrances.toggle()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Text("GATES")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(showOliveBranchEntrances ? AppTheme.background : AppTheme.foreground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(showOliveBranchEntrances ? AppTheme.entranceLayerMarker : AppTheme.card.opacity(0.92))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.border, lineWidth: showOliveBranchEntrances ? 0 : 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                showOliveBranchEntrances
                    ? "Hide reconstructed Olive Branch entranceways"
                    : "Show reconstructed Olive Branch entranceways"
            )
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
        guard radar.watchModeEnabled || inWatchedZone else {
            pulsePhase = false
            return
        }
        pulsePhase = false
        if reduceMotion {
            pulsePhase = true
            return
        }
        withAnimation(.easeInOut(duration: inWatchedZone ? 0.85 : 1.2).repeatForever(autoreverses: true)) {
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
                center: GeoHelpers.memphisCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
            )
            visibleRegion = region
            position = .region(region)
            repository.scheduleFetch(for: region, delayNanoseconds: 100_000_000)
        }
    }

    /// In Madison / Milwaukee, turn Traffic cams on by default — unless that metro was opted out.
    private func maybeAutoEnableSensorAtlas() {
        guard !sensorAtlasAutoEnableInFlight else { return }
        guard let metro = SensorAtlasAutoPolicy.shouldAutoEnable(
            layerAlreadyOn: showSensorAtlas,
            suppressedMetroNames: AppPreferences.sensorAtlasSuppressedMetros,
            coordinate: locationManager.location?.coordinate
        ) else { return }

        sensorAtlasAutoEnableInFlight = true
        sensorAtlasStore.loadIfNeeded()
        isAutoTogglingSensorAtlas = true
        withAnimation(.easeInOut(duration: 0.25)) {
            showSensorAtlas = true
            sensorAtlasBanner = "\(metro.name) traffic cams on — public WisDOT CCTV, not ALPR. Tap a gold pin."
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        sensorAtlasBannerDismissTask?.cancel()
        let metroName = metro.name
        sensorAtlasBannerDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                if sensorAtlasBanner?.contains(metroName) == true {
                    sensorAtlasBanner = nil
                }
            }
        }
    }

    /// Near Olive Branch, turn the reconstructed entrance overlay on — unless the user opted out.
    private func maybeAutoEnableEntrances() {
        guard !entranceAutoEnableInFlight else { return }
        guard OliveBranchEntranceAutoPolicy.shouldAutoEnable(
            layerAlreadyOn: showOliveBranchEntrances,
            suppressed: AppPreferences.oliveBranchEntrancesAutoSuppressed,
            coordinate: locationManager.location?.coordinate
        ) else { return }

        entranceAutoEnableInFlight = true
        entranceStore.loadIfNeeded()
        isAutoTogglingEntrances = true
        withAnimation(.easeInOut(duration: 0.25)) {
            showOliveBranchEntrances = true
            entranceBanner = "Olive Branch entranceways on — reconstructed crossings, not official Utility sites. Gaps have no mapped pin."
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        entranceBannerDismissTask?.cancel()
        entranceBannerDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                entranceBanner = nil
            }
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

        let score = repository.placeScore(
            near: coordinate,
            radiusMeters: placeScoreRadius,
            isPersonal: isPersonalScoreCoordinate(coordinate)
        )
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
        let score = repository.placeScore(
            near: coordinate,
            radiusMeters: placeScoreRadius,
            isPersonal: isPersonalScoreCoordinate(coordinate)
        )
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

    private func isPersonalScoreCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let pin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let gps = locationManager.location, gps.distance(from: pin) < 200 {
            return true
        }
        if let home = WidgetBridge.homeCoordinate() {
            let origin = CLLocation(latitude: home.latitude, longitude: home.longitude)
            if origin.distance(from: pin) < 200 { return true }
        }
        return false
    }

    private func refreshPendingScoreIfNeeded(allowClear: Bool = false) {
        guard let coordinate = pendingScoreCoordinate else { return }
        let score = repository.placeScore(
            near: coordinate,
            radiusMeters: placeScoreRadius,
            isPersonal: isPersonalScoreCoordinate(coordinate)
        )
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

private struct EntranceLayerBanner: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.background)
                .padding(8)
                .background(AppTheme.entranceLayerMarker, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.foreground)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.mutedForeground)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .background(AppTheme.card.opacity(0.96), in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.entranceLayerMarker.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct SensorAtlasBanner: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "video.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.background)
                .padding(8)
                .background(AppTheme.trafficSensorMarker, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.foreground)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.mutedForeground)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .background(AppTheme.card.opacity(0.96), in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.trafficSensorMarker.opacity(0.45), lineWidth: 1)
        )
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
