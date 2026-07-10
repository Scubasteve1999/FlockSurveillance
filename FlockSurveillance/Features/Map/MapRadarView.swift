import MapKit
import SwiftUI

struct MapRadarView: View {
    @Environment(CameraRepository.self) private var repository
    @Environment(LocationManager.self) private var locationManager
    @Environment(ProximityRadar.self) private var radar

    @AppStorage(AppPreferenceKey.showHeatDefault) private var showHeatStored = true
    @AppStorage(AppPreferenceKey.defaultFilter) private var defaultFilterRaw = CameraFilter.all.rawValue
    @AppStorage(AppPreferenceKey.watchModeEnabled) private var watchModeStored = false

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var filter: CameraFilter = AppPreferences.defaultFilter
    @State private var selectedCluster: CameraCluster?
    @State private var showHeat = AppPreferences.showHeatDefault
    @State private var pulsePhase = false
    @State private var safariPresentation: SafariPresentation?

    private var locationDenied: Bool {
        let status = locationManager.authorizationStatus
        return status == .denied || status == .restricted
    }

    private var clusters: [CameraCluster] {
        guard let visibleRegion else { return [] }
        return repository.clusters(for: filter, in: visibleRegion)
    }

    private var camerasInView: [ALPRCamera] {
        guard let region = visibleRegion else { return repository.filtered(filter) }
        return repository.cameras(in: region, filter: filter)
    }

    private var nearest: (camera: ALPRCamera, meters: CLLocationDistance)? {
        guard let coordinate = locationManager.location?.coordinate else { return nil }
        return repository.nearest(to: coordinate, filter: filter)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position) {
                UserAnnotation()

                if radar.watchModeEnabled, let nearest, let user = locationManager.location?.coordinate {
                    MapCircle(center: user, radius: max(nearest.meters, 25))
                        .foregroundStyle(AppTheme.primary.opacity(pulsePhase ? 0.18 : 0.08))
                    MapCircle(center: user, radius: max(nearest.meters * 0.55, 18))
                        .foregroundStyle(AppTheme.accent.opacity(pulsePhase ? 0.16 : 0.06))
                }

                if showHeat {
                    ForEach(clusters) { cluster in
                        MapCircle(center: cluster.coordinate, radius: heatRadius(for: cluster.count))
                            .foregroundStyle(AppTheme.densityColor(count: cluster.count).opacity(0.14))
                    }
                }

                ForEach(clusters) { cluster in
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
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll, showsTraffic: false))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
                repository.scheduleFetch(for: context.region)
            }
            .ignoresSafeArea()

            VStack(spacing: 12) {
                brandHeader
                filterBar
                if locationDenied {
                    LocationDeniedBanner()
                }
                Spacer()
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
                    onToggleWatch: toggleWatchMode,
                    onOpenDeFlockMaps: { safariPresentation = SafariPresentation(url: AppLinks.deFlockMaps) }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .padding(.top, 8)
        }
        .onAppear {
            locationManager.start()
            showHeat = showHeatStored
            filter = CameraFilter(rawValue: defaultFilterRaw) ?? .all
            radar.watchModeEnabled = watchModeStored
            bootstrapRegion()
            startPulseIfNeeded()
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
        .sheet(item: $selectedCluster) { cluster in
            CameraDetailSheet(cameras: cluster.cameras, userLocation: locationManager.location)
                .presentationBackground(AppTheme.background)
        }
        .safariSheet(item: $safariPresentation)
        .onReceive(NotificationCenter.default.publisher(for: AppLinks.openDeFlockMapsNotification)) { _ in
            safariPresentation = SafariPresentation(url: AppLinks.deFlockMaps)
        }
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
                safariPresentation = SafariPresentation(url: AppLinks.deFlockMaps)
            } label: {
                Image(systemName: "safari")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.card.opacity(0.92))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
            }
            .accessibilityLabel("Open DeFlock Maps")

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
}
