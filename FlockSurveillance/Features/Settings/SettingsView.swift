import MapKit
import SwiftUI

struct SettingsView: View {
    @Environment(CameraRepository.self) private var repository
    @Environment(LocationManager.self) private var locationManager
    @Environment(ProximityRadar.self) private var radar

    @AppStorage(AppPreferenceKey.showHeatDefault) private var showHeatDefault = true
    @AppStorage(AppPreferenceKey.defaultFilter) private var defaultFilterRaw = CameraFilter.all.rawValue
    @AppStorage(AppPreferenceKey.alertsEnabled) private var alertsEnabled = false
    @AppStorage(AppPreferenceKey.alertsFlockOnly) private var alertsFlockOnly = false
    @AppStorage(AppPreferenceKey.quietHoursEnabled) private var quietHoursEnabled = false
    @AppStorage(AppPreferenceKey.quietStartHour) private var quietStartHour = 22
    @AppStorage(AppPreferenceKey.quietEndHour) private var quietEndHour = 7

    @State private var homeQuery = ""
    @State private var homeSuggestions: [MKLocalSearchCompletion] = []
    @State private var completer = PlaceCompleter()
    @State private var homeStatus: String?
    @State private var didClearCache = false

    private var homeCoordinate: CLLocationCoordinate2D? {
        WidgetBridge.homeCoordinate()
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
                            Text("Tune radar, Home for the widget, and local cache.")
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
                                        Task { await AlertsEngine.shared.setEnabled(enabled) }
                                    }
                                )) {
                                    labelRow("ALPR proximity alerts", "Get notified near cameras, even with the app closed")
                                }
                                .tint(AppTheme.accent)

                                if alertsEnabled {
                                    if !AlertsEngine.shared.hasAlwaysAuthorization {
                                        Text("Allow “Always” location access so alerts work in the background. iOS may ask again after a few days of use.")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(AppTheme.primary)
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

                                if !homeSuggestions.isEmpty {
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
                completer.query = value
            }
            .onChange(of: completer.results) { _, results in
                homeSuggestions = results
            }
            .onAppear {
                if let location = locationManager.location {
                    completer.bias(to: location.coordinate)
                }
            }
        }
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
        if let coordinate = locationManager.location?.coordinate {
            AlertsEngine.shared.reseed(around: coordinate)
        }
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
}
