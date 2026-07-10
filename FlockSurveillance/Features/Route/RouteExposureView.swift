import MapKit
import SwiftUI

struct RouteExposureView: View {
    @Environment(CameraRepository.self) private var repository
    @Environment(LocationManager.self) private var locationManager

    @State private var originQuery = ""
    @State private var destinationQuery = ""
    @State private var originCoordinate: CLLocationCoordinate2D?
    @State private var destinationCoordinate: CLLocationCoordinate2D?
    @State private var originSuggestions: [MKLocalSearchCompletion] = []
    @State private var destinationSuggestions: [MKLocalSearchCompletion] = []
    @State private var completer = PlaceCompleter()
    @State private var isRouting = false
    @State private var errorMessage: String?
    @State private var result: RouteExposureResult?
    @State private var shareText: String?
    @State private var activeField: ActiveField = .destination
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var safariPresentation: SafariPresentation?

    private enum ActiveField {
        case origin, destination
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        brandBlock
                        searchCard
                        if let result {
                            exposureCard(result)
                            routeMap(result)
                            cameraList(result)
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
                    ProgressView("Mapping exposure…")
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .sheet(item: Binding(
                get: { shareText.map { SharePayload(text: $0) } },
                set: { shareText = $0?.text }
            )) { payload in
                ActivityView(items: [payload.text])
            }
            .safariSheet(item: $safariPresentation)
            .onAppear {
                if let location = locationManager.location {
                    completer.bias(to: location.coordinate)
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

    private var brandBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FLOCK SURVEILLANCE")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(AppTheme.primary)
            Text("Route Exposure")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppTheme.foreground)
            Text("Count community-mapped ALPRs along a drive. For lower-exposure route planning, use DeFlock Maps.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
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
            VStack(alignment: .leading, spacing: 12) {
                Text("No route yet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.foreground)
                Text("Pick an origin and destination. We’ll count community-mapped ALPRs within about 75 meters of the driving path.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
                deFlockMapsButton
            }
        }
    }

    private var deFlockMapsButton: some View {
        Button {
            safariPresentation = SafariPresentation(url: AppLinks.deFlockMaps)
        } label: {
            Label("Plan a lower-exposure route on DeFlock Maps", systemImage: "safari")
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .foregroundStyle(AppTheme.accent)
                .background(AppTheme.cardTop)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Plan a lower-exposure route on DeFlock Maps")
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
                    metric("Corridor", "\(Int(result.corridorMeters)) m")
                }

                Button {
                    shareText = shareReport(result)
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

                deFlockMapsButton
            }
        }
    }

    private func routeMap(_ result: RouteExposureResult) -> some View {
        Map(position: $mapPosition) {
            MapPolyline(result.route.polyline)
                .stroke(AppTheme.accent, lineWidth: 4)
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
    }

    private func cameraList(_ result: RouteExposureResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Along the route")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.foreground)

            if result.cameras.isEmpty {
                Text("No mapped ALPRs within the corridor.")
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
            let route = try await RouteExposureService.directions(from: origin, to: destination)
            let region = regionFor(route: route)
            await repository.fetch(for: region)
            let candidates = repository.cameras(in: region)
            let exposure = RouteExposureService.exposure(route: route, cameras: candidates)
            withAnimation(.easeInOut(duration: 0.25)) {
                result = exposure
            }
            fitMap(to: exposure)
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

    private func regionFor(route: MKRoute) -> MKCoordinateRegion {
        let rect = route.polyline.boundingMapRect
        var region = MKCoordinateRegion(rect)
        region.span.latitudeDelta *= 1.3
        region.span.longitudeDelta *= 1.3
        return region
    }

    private func shareReport(_ result: RouteExposureResult) -> String {
        let from = originQuery.isEmpty ? "Origin" : originQuery
        let to = destinationQuery.isEmpty ? "Destination" : destinationQuery
        return """
        Flock Surveillance — Drive Report
        From: \(from)
        To: \(to)
        Cameras along route: \(result.cameraCount) (\(result.flockCount) Flock)
        Exposure: \(result.exposureScore)
        Distance: \(String(format: "%.1f", result.route.distance / 1609.34)) mi
        Data: OpenStreetMap community-mapped ALPRs
        flocksurveillance.com
        """
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let text: String
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
