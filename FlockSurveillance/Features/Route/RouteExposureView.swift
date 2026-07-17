import ActivityKit
import MapKit
import SwiftUI

struct RouteExposureView: View {
    @Environment(CameraRepository.self) private var repository
    @Environment(LocationManager.self) private var locationManager
    @Environment(DriveSession.self) private var driveSession

    @State private var originQuery = ""
    @State private var destinationQuery = ""
    @State private var originCoordinate: CLLocationCoordinate2D?
    @State private var destinationCoordinate: CLLocationCoordinate2D?
    @State private var originSuggestions: [MKLocalSearchCompletion] = []
    @State private var destinationSuggestions: [MKLocalSearchCompletion] = []
    @State private var completer = PlaceCompleter()
    @State private var isRouting = false
    @State private var errorMessage: String?
    @State private var analysis: RouteExposureAnalysis?
    @State private var selectedOptionID: UUID?
    @State private var sharePayload: ShareActivityPayload?
    @State private var activeField: ActiveField = .destination
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var showDriveMode = false
    @State private var commuteHint: String?
    @State private var liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled

    private enum ActiveField {
        case origin, destination
    }

    private var selectedResult: RouteExposureResult? {
        guard let analysis else { return nil }
        if let selectedOptionID,
           let match = analysis.options.first(where: { $0.id == selectedOptionID }) {
            return match.result
        }
        return analysis.recommended
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        brandBlock
                        if driveSession.isActive, !showDriveMode {
                            activeDriveCard
                        }
                        commuteCard
                        searchCard
                        if let analysis, let selectedResult {
                            alternativesCard(analysis)
                            exposureCard(selectedResult)
                            routeMap(selectedResult, options: analysis.options)
                            cameraList(selectedResult)
                        } else {
                            emptyState
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarHidden(true)
            .overlay {
                if isRouting {
                    ProgressView("Finding the drive with fewer cameras…")
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .fullScreenCover(isPresented: $showDriveMode) {
                DriveModeView()
            }
            .sheet(item: $sharePayload) { payload in
                ActivityView(items: payload.items)
                    .id(payload.id)
            }
            .onAppear {
                liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
                if let location = locationManager.location {
                    completer.bias(to: location.coordinate)
                }
                handlePendingCommuteIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .flockSafestCommute)) { _ in
                handlePendingCommuteIfNeeded()
            }
            .onChange(of: isRouting) { _, routing in
                if !routing {
                    handlePendingCommuteIfNeeded()
                }
            }
            .onChange(of: originQuery) { _, value in
                activeField = .origin
                completer.query = value
            }
            .onChange(of: destinationQuery) { _, value in
                activeField = .destination
                completer.query = value
            }
            .onChange(of: completer.results) { _, results in
                switch activeField {
                case .origin: originSuggestions = results
                case .destination: destinationSuggestions = results
                }
            }
            .onChange(of: locationManager.location?.coordinate.latitude) { _, _ in
                if let location = locationManager.location {
                    completer.bias(to: location.coordinate)
                }
            }
        }
    }

    private var activeDriveCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OVERWATCH · DRIVE LIVE")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.primary)
                        Text(
                            driveSession.nextHit.map { hit in
                                let distance = driveSession.metersToNext.map(ProximityRadar.formatDistance) ?? "—"
                                return "LOCK \(distance) · \(hit.isFlock ? "Flock" : "mapped") pin"
                            } ?? "Corridor clear"
                        )
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.foreground)
                    }
                    Spacer()
                    Text("\(driveSession.camerasRemaining) AHEAD")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.accent)
                }

                HStack(spacing: 10) {
                    Button {
                        showDriveMode = true
                    } label: {
                        Label("Resume Overwatch", systemImage: "car.fill")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(AppTheme.background)
                            .background(AppTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        driveSession.stop()
                    } label: {
                        Text("END DRIVE")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(AppTheme.foreground)
                            .background(AppTheme.cardTop)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var brandBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OVERWATCH · ROUTE")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(AppTheme.primary)
            Text("Safest Drive")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(AppTheme.foreground)
            Text("One tap for Home ↔ Work, or search any trip. We pick the corridor with the fewest mapped ALPR pins.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
        }
    }

    private var commuteCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("COMMUTE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.mutedForeground)

                HStack(spacing: 10) {
                    Button {
                        Task { await runCommute(toHome: false) }
                    } label: {
                        Label("Home → Work", systemImage: "briefcase.fill")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(AppTheme.background)
                            .background(AppTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isRouting)

                    Button {
                        Task { await runCommute(toHome: true) }
                    } label: {
                        Label("Work → Home", systemImage: "house.fill")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(AppTheme.foreground)
                            .background(AppTheme.cardTop)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRouting)
                }

                if let commuteHint {
                    Text(commuteHint)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.primary)
                } else {
                    Text("Set Home and Work in Settings for one-tap safest drives.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.mutedForeground)
                }
            }
        }
    }

    private var searchCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                labeledField("From", text: $originQuery, placeholder: "Current location or address") {
                    activeField = .origin
                }
                if activeField == .origin, !originSuggestions.isEmpty {
                    suggestionList(originSuggestions) { completion in
                        Task { await selectOrigin(completion) }
                    }
                }

                labeledField("To", text: $destinationQuery, placeholder: "Destination") {
                    activeField = .destination
                }
                if activeField == .destination, !destinationSuggestions.isEmpty {
                    suggestionList(destinationSuggestions) { completion in
                        Task { await selectDestination(completion) }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.primary)
                }

                HStack(spacing: 10) {
                    Button {
                        useCurrentLocationAsOrigin()
                    } label: {
                        Label("Use my location", systemImage: "location.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.accent)

                    Spacer()

                    Button {
                        Task { await runExposure() }
                    } label: {
                        Text("Analyze")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.background)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(AppTheme.primary)
                            .clipShape(Capsule())
                    }
                    .disabled(isRouting)
                }
            }
        }
    }

    private var emptyState: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("No drive yet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.foreground)
                Text("Tap Home → Work or pick any addresses. We’ll score alternate drives by cameras near each path and recommend the one with the fewest.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
            }
        }
    }

    private func alternativesCard(_ analysis: RouteExposureAnalysis) -> some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("ROUTE OPTIONS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.mutedForeground)
                Text(analysis.options.count > 1
                     ? "Tap a route to compare. Recommended has the fewest cameras."
                     : "MapKit returned one drive for this pair.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)

                ForEach(Array(analysis.options.enumerated()), id: \.element.id) { index, option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedOptionID = option.id
                            fitMap(to: option.result)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(option.isRecommended ? "Recommended" : "Option \(index + 1)")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(AppTheme.foreground)
                                    if option.isRecommended {
                                        StatusBadge(text: "Best", color: AppTheme.accent)
                                    }
                                }
                                Text("\(option.cameraCount) cameras · \(String(format: "%.1f mi", option.distance / 1609.34))")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppTheme.mutedForeground)
                            }
                            Spacer()
                            StatusBadge(
                                text: option.result.exposureScore,
                                color: AppTheme.densityColor(count: option.cameraCount)
                            )
                        }
                        .padding(12)
                        .background(
                            (selectedOptionID == option.id || (selectedOptionID == nil && option.isRecommended))
                                ? AppTheme.primary.opacity(0.12)
                                : AppTheme.cardTop
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    (selectedOptionID == option.id || (selectedOptionID == nil && option.isRecommended))
                                        ? AppTheme.accent.opacity(0.55)
                                        : AppTheme.border,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func exposureCard(_ result: RouteExposureResult) -> some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DRIVE REPORT")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.mutedForeground)
                        Text("\(result.cameraCount) cameras")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(AppTheme.foreground)
                    }
                    Spacer()
                    StatusBadge(
                        text: result.exposureScore,
                        color: AppTheme.densityColor(count: result.cameraCount)
                    )
                }

                HStack(spacing: 16) {
                    metric("Flock", "\(result.flockCount)")
                    metric("Distance", String(format: "%.1f mi", result.route.distance / 1609.34))
                    metric("Watchedness", result.exposureScore)
                }

                Button {
                    if driveSession.isActive {
                        showDriveMode = true
                    } else {
                        driveSession.start(from: result)
                        showDriveMode = true
                    }
                } label: {
                    Label(
                        driveSession.isActive ? "Resume Overwatch" : "Start Overwatch Drive",
                        systemImage: "car.fill"
                    )
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(AppTheme.background)
                        .background(AppTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Text(
                    liveActivitiesEnabled
                        ? "Live Activity will show on your Lock Screen while you drive."
                        : "Enable Live Activities in Settings to see the drive countdown on your Lock Screen."
                )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)

                Button {
                    shareDriveReport(result)
                } label: {
                    Label("Share drive report", systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(AppTheme.foreground)
                        .background(AppTheme.cardTop)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func routeMap(_ result: RouteExposureResult, options: [RankedRouteExposure]) -> some View {
        Map(position: $mapPosition) {
            ForEach(options) { option in
                let isSelected = option.result.id == result.id
                MapPolyline(option.result.route.polyline)
                    .stroke(
                        isSelected ? AppTheme.accent : AppTheme.mutedForeground.opacity(0.45),
                        lineWidth: isSelected ? 4 : 2
                    )
            }
            ForEach(result.cameras, id: \.camera.id) { item in
                Annotation("", coordinate: item.camera.coordinate) {
                    CameraAnnotationView(count: 1, isFlock: item.camera.isFlock)
                }
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .onAppear {
            fitMap(to: result)
        }
        .onChange(of: result.id) { _, _ in
            fitMap(to: result)
        }
    }

    private func cameraList(_ result: RouteExposureResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Along the route")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.foreground)

            if result.cameras.isEmpty {
                Text("No mapped cameras near this drive.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
            } else {
                ForEach(result.cameras, id: \.camera.id) { item in
                    SectionCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.camera.displayTitle)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppTheme.foreground)
                                Text(item.camera.displayManufacturer)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppTheme.mutedForeground)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Along route")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.6)
                                    .foregroundStyle(AppTheme.mutedForeground)
                                Text(ProximityRadar.formatDistance(item.metersFromStart))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }
                }
            }
        }
    }

    private func labeledField(_ title: String, text: Binding<String>, placeholder: String, onFocus: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(AppTheme.mutedForeground)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(AppTheme.background.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(AppTheme.foreground)
                .onTapGesture(perform: onFocus)
        }
    }

    private func suggestionList(_ items: [MKLocalSearchCompletion], onSelect: @escaping (MKLocalSearchCompletion) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.prefix(5).enumerated()), id: \.offset) { _, item in
                Button {
                    onSelect(item)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.foreground)
                        Text(item.subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(AppTheme.mutedForeground)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.foreground)
        }
    }

    private func useCurrentLocationAsOrigin() {
        locationManager.start()
        guard let coordinate = locationManager.location?.coordinate else {
            errorMessage = "Location unavailable. Enable location access or type an address."
            return
        }
        originCoordinate = coordinate
        originQuery = "Current location"
        originSuggestions = []
        errorMessage = nil
    }

    private func selectOrigin(_ completion: MKLocalSearchCompletion) async {
        originQuery = completion.title
        originSuggestions = []
        originCoordinate = await geocode(completion)
    }

    private func selectDestination(_ completion: MKLocalSearchCompletion) async {
        destinationQuery = completion.title
        destinationSuggestions = []
        destinationCoordinate = await geocode(completion)
    }

    private func geocode(_ completion: MKLocalSearchCompletion) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems.first?.placemark.coordinate
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func runExposure() async {
        errorMessage = nil
        var origin = originCoordinate
        if origin == nil, originQuery.lowercased().contains("current") {
            origin = locationManager.location?.coordinate
        }
        if origin == nil, !originQuery.isEmpty {
            origin = await geocodeAddress(originQuery)
        }
        var destination = destinationCoordinate
        if destination == nil, !destinationQuery.isEmpty {
            destination = await geocodeAddress(destinationQuery)
        }

        guard let origin, let destination else {
            errorMessage = "Choose a valid origin and destination."
            return
        }

        isRouting = true
        defer { isRouting = false }

        do {
            let routes = try await RouteExposureService.directions(from: origin, to: destination)
            // Fetch each route corridor separately so long alternate unions aren't collapsed
            // to a single center Overpass tile.
            let candidates = await repository.fetchCamerasAlong(routes: routes)
            let scored = RouteExposureService.analyze(routes: routes, cameras: candidates)
            withAnimation(.easeInOut(duration: 0.25)) {
                analysis = scored
                selectedOptionID = scored.options.first(where: \.isRecommended)?.id ?? scored.options.first?.id
            }
            if let recommended = scored.recommended {
                fitMap(to: recommended)
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fitMap(to result: RouteExposureResult) {
        var coordinates = result.route.polyline.coordinates
        coordinates.append(contentsOf: result.cameras.map(\.camera.coordinate))
        if let rect = GeoHelpers.mapRect(covering: coordinates) {
            mapPosition = .rect(rect)
        }
    }

    private func geocodeAddress(_ query: String) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request)
        return try? await search.start().mapItems.first?.placemark.coordinate
    }

    private func handlePendingCommuteIfNeeded() {
        // Leave pending while an analysis is in flight (onChange of isRouting retries).
        guard !isRouting else { return }
        guard let toHome = PendingIntentActions.commuteToHome else { return }

        guard WidgetBridge.homeCoordinate() != nil else {
            PendingIntentActions.commuteToHome = nil
            commuteHint = "Set Home in Settings first."
            return
        }
        guard WidgetBridge.workCoordinate() != nil else {
            PendingIntentActions.commuteToHome = nil
            commuteHint = "Set Work in Settings first."
            return
        }

        // Claim synchronously so onAppear + notification can't double-start.
        PendingIntentActions.commuteToHome = nil
        Task { await runCommute(toHome: toHome) }
    }

    private func runCommute(toHome: Bool) async {
        guard !isRouting else { return }
        guard let home = WidgetBridge.homeCoordinate() else {
            commuteHint = "Set Home in Settings first."
            return
        }
        guard let work = WidgetBridge.workCoordinate() else {
            commuteHint = "Set Work in Settings first."
            return
        }
        commuteHint = nil
        if toHome {
            originCoordinate = work
            destinationCoordinate = home
            originQuery = "Work"
            destinationQuery = "Home"
        } else {
            originCoordinate = home
            destinationCoordinate = work
            originQuery = "Home"
            destinationQuery = "Work"
        }
        await runExposure()
    }

    private func shareDriveReport(_ result: RouteExposureResult) {
        Task { @MainActor in
            let from = originQuery.isEmpty ? "Origin" : originQuery
            let to = destinationQuery.isEmpty ? "Destination" : destinationQuery
            var items: [Any] = [shareReport(result)]
            if let image = ShareCardRenderer.driveReportImage(
                cameraCount: result.cameraCount,
                exposureLabel: result.exposureScore,
                distanceMiles: result.route.distance / 1609.34,
                originLabel: from,
                destinationLabel: to
            ) {
                items.insert(image, at: 0)
            }
            sharePayload = ShareActivityPayload(items: items)
        }
    }

    private func shareReport(_ result: RouteExposureResult) -> String {
        let from = originQuery.isEmpty ? "Origin" : originQuery
        let to = destinationQuery.isEmpty ? "Destination" : destinationQuery
        let optionCount = analysis?.options.count ?? 1
        return """
        Flock Surveillance — Safest Drive
        From: \(from)
        To: \(to)
        Cameras on route: \(result.cameraCount) (\(result.flockCount) Flock)
        Watchedness: \(result.exposureScore)
        Distance: \(String(format: "%.1f", result.route.distance / 1609.34)) mi
        Alternatives scored: \(optionCount)
        Fewer cameras. Same destination.
        flocksurveillance.com
        """
    }
}

private struct ShareActivityPayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
