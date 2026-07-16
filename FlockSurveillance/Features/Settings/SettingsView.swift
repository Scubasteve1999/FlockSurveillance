import MapKit
import SwiftUI

struct SettingsView: View {
    @Environment(CameraRepository.self) private var repository
    @Environment(LocationManager.self) private var locationManager
    @Environment(ProximityRadar.self) private var radar
    @Environment(ReportStore.self) private var reportStore

    @AppStorage(AppPreferenceKey.showHeatDefault) private var showHeatDefault = true
    @AppStorage(AppPreferenceKey.defaultFilter) private var defaultFilterRaw = CameraFilter.all.rawValue
    @AppStorage(AppPreferenceKey.alertsEnabled) private var alertsEnabled = false
    @AppStorage(AppPreferenceKey.alertsFlockOnly) private var alertsFlockOnly = false
    @AppStorage(AppPreferenceKey.quietHoursEnabled) private var quietHoursEnabled = false
    @AppStorage(AppPreferenceKey.quietStartHour) private var quietStartHour = 22
    @AppStorage(AppPreferenceKey.quietEndHour) private var quietEndHour = 7

    /// Hold the shared engine so SwiftUI observes authorizationStatus changes.
    @State private var alertsEngine = AlertsEngine.shared
    @State private var homeQuery = ""
    @State private var homeSuggestions: [MKLocalSearchCompletion] = []
    @State private var workQuery = ""
    @State private var workSuggestions: [MKLocalSearchCompletion] = []
    @State private var addressField: AddressField = .home
    @State private var completer = PlaceCompleter()
    @State private var homeStatus: String?
    @State private var workStatus: String?
    @State private var didClearCache = false
    @State private var selectedContribution: PendingReport?

    private enum AddressField {
        case home, work
    }

    private var homeCoordinate: CLLocationCoordinate2D? {
        WidgetBridge.homeCoordinate()
    }

    private var workCoordinate: CLLocationCoordinate2D? {
        WidgetBridge.workCoordinate()
    }

    private var alertsHaveAlways: Bool {
        alertsEngine.hasAlwaysAuthorization
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("FLOCK SURVEILLANCE")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(AppTheme.primary)
                            Text("Settings")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(AppTheme.foreground)
                            Text("Tune radar, Home & Work for commute, and local cache.")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppTheme.mutedForeground)
                        }

                        SectionCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("PREFERENCES")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.8)
                                    .foregroundStyle(AppTheme.mutedForeground)

                                Toggle(isOn: Binding(
                                    get: { radar.hapticsEnabled },
                                    set: { radar.hapticsEnabled = $0 }
                                )) {
                                    labelRow("Proximity haptics", "Pulse as you approach ALPRs")
                                }
                                .tint(AppTheme.accent)

                                Toggle(isOn: $showHeatDefault) {
                                    labelRow("Coverage heat by default", "Show density circles on the map")
                                }
                                .tint(AppTheme.accent)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Default filter")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(AppTheme.foreground)
                                    Picker("Default filter", selection: $defaultFilterRaw) {
                                        ForEach(CameraFilter.allCases) { filter in
                                            Text(filter.rawValue).tag(filter.rawValue)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                        }

                        SectionCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("ALERTS")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.8)
                                    .foregroundStyle(AppTheme.mutedForeground)

                                Toggle(isOn: Binding(
                                    get: { alertsEnabled },
                                    set: { enabled in
                                        alertsEnabled = enabled
                                        Task { await alertsEngine.setEnabled(enabled) }
                                    }
                                )) {
                                    labelRow(
                                        "ALPR proximity alerts",
                                        "Notify when your phone is near mapped OSM pins — not plate-read alerts"
                                    )
                                }
                                .tint(AppTheme.accent)

                                if alertsEnabled {
                                    // Observe auth so the Always hint updates live.
                                    let _ = alertsEngine.authorizationStatus
                                    if !alertsHaveAlways {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Allow “Always” location access so alerts work in the background. Without it, alerts won’t fire with the app closed.")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(AppTheme.primary)
                                            Button {
                                                alertsEngine.requestAlwaysAccess()
                                            } label: {
                                                Text("Grant Always access")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(AppTheme.background)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(AppTheme.primary)
                                                    .clipShape(Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }

                                    Toggle(isOn: Binding(
                                        get: { alertsFlockOnly },
                                        set: { value in
                                            alertsFlockOnly = value
                                            reseedAlerts()
                                        }
                                    )) {
                                        labelRow("Flock cameras only", "Skip other ALPR manufacturers")
                                    }
                                    .tint(AppTheme.accent)

                                    Toggle(isOn: $quietHoursEnabled) {
                                        labelRow("Quiet hours", "Mute alerts during a nightly window")
                                    }
                                    .tint(AppTheme.accent)

                                    if quietHoursEnabled {
                                        HStack(spacing: 12) {
                                            quietHourPicker("From", selection: $quietStartHour)
                                            quietHourPicker("Until", selection: $quietEndHour)
                                        }
                                    }
                                }
                            }
                        }

                        SectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("HOME FOR WIDGET")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.8)
                                    .foregroundStyle(AppTheme.mutedForeground)

                                if let home = homeCoordinate {
                                    Text(String(format: "Current Home: %.4f, %.4f", home.latitude, home.longitude))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppTheme.accent)
                                } else {
                                    Text("No Home set yet.")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppTheme.mutedForeground)
                                }

                                Button {
                                    setHomeToCurrentLocation()
                                } label: {
                                    Label("Use current location", systemImage: "location.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .foregroundStyle(AppTheme.background)
                                        .background(AppTheme.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)

                                TextField("Search an address for Home", text: $homeQuery)
                                    .textInputAutocapitalization(.words)
                                    .padding(12)
                                    .background(AppTheme.background.opacity(0.55))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .foregroundStyle(AppTheme.foreground)
                                    .onTapGesture { addressField = .home }

                                if addressField == .home, !homeSuggestions.isEmpty {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(Array(homeSuggestions.prefix(5).enumerated()), id: \.offset) { _, item in
                                            Button {
                                                Task { await selectHome(item) }
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

                                if let homeStatus {
                                    Text(homeStatus)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                        }

                        SectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("WORK FOR COMMUTE")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.8)
                                    .foregroundStyle(AppTheme.mutedForeground)

                                if let work = workCoordinate {
                                    Text(String(format: "Current Work: %.4f, %.4f", work.latitude, work.longitude))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppTheme.accent)
                                } else {
                                    Text("No Work set yet.")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppTheme.mutedForeground)
                                }

                                Button {
                                    setWorkToCurrentLocation()
                                } label: {
                                    Label("Use current location", systemImage: "location.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .foregroundStyle(AppTheme.background)
                                        .background(AppTheme.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)

                                TextField("Search an address for Work", text: $workQuery)
                                    .textInputAutocapitalization(.words)
                                    .padding(12)
                                    .background(AppTheme.background.opacity(0.55))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .foregroundStyle(AppTheme.foreground)
                                    .onTapGesture { addressField = .work }

                                if addressField == .work, !workSuggestions.isEmpty {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(Array(workSuggestions.prefix(5).enumerated()), id: \.offset) { _, item in
                                            Button {
                                                Task { await selectWork(item) }
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

                                if let workStatus {
                                    Text(workStatus)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                        }

                        SectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("YOUR CONTRIBUTIONS")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.8)
                                    .foregroundStyle(AppTheme.mutedForeground)

                                Text("Anonymous OSM notes you submitted from this device. We watch open notes and refresh nearby when a camera lands.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.mutedForeground)

                                HStack(spacing: 16) {
                                    contributionStat("Open", reportStore.openCount)
                                    contributionStat("Landed", reportStore.landedCount)
                                    contributionStat("Total", reportStore.reports.count)
                                }

                                if reportStore.reports.isEmpty {
                                    Text("No reports yet — tap the flag on the map to add coverage.")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppTheme.mutedForeground)
                                } else {
                                    ForEach(reportStore.reports.prefix(12), id: \.id) { report in
                                        Button {
                                            selectedContribution = report
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(report.kind.rawValue)
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundStyle(AppTheme.foreground)
                                                    Text(report.status.displayLabel)
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundStyle(AppTheme.accent)
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(AppTheme.mutedForeground)
                                            }
                                            .padding(.vertical, 6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                Button {
                                    Task {
                                        await reportStore.verifyOpenReports(repository: repository, force: true)
                                    }
                                } label: {
                                    Label("Check open reports now", systemImage: "arrow.clockwise")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(AppTheme.accent)
                                }
                                .buttonStyle(.plain)
                                .disabled(reportStore.openCount == 0)
                            }
                        }

                        SectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("DATA")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.8)
                                    .foregroundStyle(AppTheme.mutedForeground)

                                Text("\(repository.cameras.count) cameras cached locally")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(AppTheme.foreground)

                                Button(role: .destructive) {
                                    repository.clearCache()
                                    didClearCache = true
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                } label: {
                                    Label("Clear camera cache", systemImage: "trash")
                                        .font(.system(size: 14, weight: .semibold))
                                }

                                if didClearCache {
                                    Text("Cache cleared.")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppTheme.mutedForeground)
                                }
                            }
                        }

                        SectionCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("ABOUT")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.8)
                                    .foregroundStyle(AppTheme.mutedForeground)
                                Text("Community-mapped ALPR locations from OpenStreetMap and the DeFlock mapping community. Not affiliated with Flock Safety.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.mutedForeground)
                                Link("DeFlock project", destination: AppLinks.deFlockProject)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppTheme.accent)
                                Link("flocksurveillance.com", destination: AppLinks.website)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarHidden(true)
            .onChange(of: homeQuery) { _, value in
                addressField = .home
                completer.query = value
            }
            .onChange(of: workQuery) { _, value in
                addressField = .work
                completer.query = value
            }
            .onChange(of: completer.results) { _, results in
                switch addressField {
                case .home: homeSuggestions = results
                case .work: workSuggestions = results
                }
            }
            .onAppear {
                if let location = locationManager.location {
                    completer.bias(to: location.coordinate)
                }
            }
            .sheet(item: $selectedContribution) { report in
                PendingReportDetailSheet(
                    report: report,
                    onCheckAgain: {
                        Task {
                            await reportStore.verifyOpenReports(repository: repository, force: true)
                        }
                    },
                    onFocusMap: {
                        let lat = String(format: "%.5f", report.latitude)
                        let lon = String(format: "%.5f", report.longitude)
                        if let url = URL(string: "flocksurveillance://map?lat=\(lat)&lon=\(lon)") {
                            NotificationCenter.default.post(
                                name: .flockDeepLink,
                                object: nil,
                                userInfo: ["url": url]
                            )
                        }
                    }
                )
                .presentationBackground(AppTheme.background)
            }
        }
    }

    private func contributionStat(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.foreground)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quietHourPicker(_ label: String, selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(AppTheme.mutedForeground)
            Picker(label, selection: selection) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(hourLabel(hour)).tag(hour)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hourLabel(_ hour: Int) -> String {
        let normalized = hour % 12 == 0 ? 12 : hour % 12
        return "\(normalized) \(hour < 12 ? "AM" : "PM")"
    }

    private func reseedAlerts() {
        AlertsEngine.shared.reseedFromLastKnownLocation()
    }

    private func labelRow(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.foreground)
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
        }
    }

    private func setHomeToCurrentLocation() {
        locationManager.start()
        guard let coordinate = locationManager.location?.coordinate else {
            homeStatus = "Location unavailable. Enable location access first."
            return
        }
        applyHome(coordinate, message: "Home set to current location.")
    }

    private func selectHome(_ completion: MKLocalSearchCompletion) async {
        homeQuery = completion.title
        homeSuggestions = []
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            guard let coordinate = response.mapItems.first?.placemark.coordinate else {
                homeStatus = "Could not resolve that address."
                return
            }
            applyHome(coordinate, message: "Home set to \(completion.title).")
        } catch {
            homeStatus = error.localizedDescription
        }
    }

    private func applyHome(_ coordinate: CLLocationCoordinate2D, message: String) {
        WidgetBridge.setHomeCoordinate(coordinate)
        repository.refreshWidgetSnapshot()
        homeStatus = message
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func setWorkToCurrentLocation() {
        locationManager.start()
        guard let coordinate = locationManager.location?.coordinate else {
            workStatus = "Location unavailable. Enable location access first."
            return
        }
        applyWork(coordinate, message: "Work set to current location.")
    }

    private func selectWork(_ completion: MKLocalSearchCompletion) async {
        workQuery = completion.title
        workSuggestions = []
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            guard let coordinate = response.mapItems.first?.placemark.coordinate else {
                workStatus = "Could not resolve that address."
                return
            }
            applyWork(coordinate, message: "Work set to \(completion.title).")
        } catch {
            workStatus = error.localizedDescription
        }
    }

    private func applyWork(_ coordinate: CLLocationCoordinate2D, message: String) {
        WidgetBridge.setWorkCoordinate(coordinate)
        workStatus = message
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
