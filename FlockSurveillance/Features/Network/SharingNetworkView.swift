import MapKit
import SwiftUI
import UIKit

private enum SharingDrillLevel: Equatable {
    case nation
    case state(String)
    case county(state: String, county: String)
}

struct SharingNetworkView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var store = SharingNetworkStore()
    @State private var selectedHubID: String?
    @State private var selectedPartner: SharingPartner?
    @State private var selectedCountyGroup: SharingCountyGroup?
    @State private var selectedMarkerID: String?
    @State private var showPartnerSearch = false
    @State private var showUngrouped = false
    @State private var drillLevel: SharingDrillLevel = .nation
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.8, longitude: -98.5),
            span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 50)
        )
    )
    @State private var stateGroups: [SharingStateGroup] = []
    @State private var countyGroups: [SharingCountyGroup] = []
    @State private var agencyPins: [SharingPartner] = []

    private var selectedHub: SharingHub? {
        guard let selectedHubID else { return store.hubs.first }
        return store.hubs.first { $0.id == selectedHubID } ?? store.hubs.first
    }

    private var totalPartnerCount: Int {
        guard let hub = selectedHub else { return 0 }
        return store.partners(for: hub.id).count
    }

    private var currentStateGroup: SharingStateGroup? {
        guard case .state(let state) = drillLevel else { return nil }
        return stateGroups.first { $0.state == state }
    }

    private var pinsAgenciesDirectly: Bool {
        guard let group = currentStateGroup else { return false }
        return SharingNetworkStore.shouldPinAgenciesDirectly(partnerCount: group.partnerCount)
    }

    private var ungroupedInState: [SharingPartner] {
        guard let hub = selectedHub, case .state(let state) = drillLevel else { return [] }
        return store.ungroupedPartners(for: hub.id, state: state)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                AppTheme.background.ignoresSafeArea()

                MapKitSizeGate(size: geo.size) { mapContent }

                VStack(spacing: 10) {
                    header
                    hubPicker
                    breadcrumb
                    legend
                }
                .padding(.top, 8)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
        .preferredColorScheme(.dark)
        .task {
            await store.loadIfNeeded()
        }
        .onChange(of: selectedMarkerID) { _, markerID in
            handleMarkerSelection(markerID)
        }
        .onChange(of: store.isLoaded) { _, loaded in
            guard loaded, selectedHubID == nil else { return }
            selectedHubID = store.hubs.first?.id
            refreshVisibleGroups()
            fitCurrentLevel(animated: false)
        }
        .sheet(item: $selectedCountyGroup) { group in
            if let hub = selectedHub {
                SharingCountySheet(group: group, hub: hub, attribution: store.attribution)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(AppTheme.background)
            }
        }
        .sheet(item: $selectedPartner) { partner in
            SharingPartnerSheet(
                partner: partner,
                hub: selectedHub,
                attribution: store.attribution
            )
            .presentationDetents([.medium, .large])
            .presentationBackground(AppTheme.background)
        }
        .sheet(isPresented: $showPartnerSearch) {
            if let hub = selectedHub {
                SharingPartnerSearchSheet(
                    store: store,
                    hub: hub,
                    totalPartnerCount: totalPartnerCount
                ) { partner in
                    showPartnerSearch = false
                    focusPartner(partner)
                }
                .presentationDetents([.medium, .large])
                .presentationBackground(AppTheme.background)
            }
        }
        .sheet(isPresented: $showUngrouped) {
            if let hub = selectedHub, case .state(let state) = drillLevel {
                SharingUngroupedSheet(
                    partners: ungroupedInState,
                    stateName: SharingStateGeography.displayName(for: state),
                    hub: hub,
                    attribution: store.attribution
                )
                .presentationDetents([.medium, .large])
                .presentationBackground(AppTheme.background)
            }
        }
    }

    private var mapContent: some View {
        Map(position: $position, selection: $selectedMarkerID) {
            if let hub = selectedHub {
                Annotation(hub.shortName, coordinate: hub.coordinate, anchor: .center) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primary.opacity(0.25))
                            .frame(width: 36, height: 36)
                        Circle()
                            .fill(AppTheme.primary)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1.5))
                    }
                    .accessibilityLabel(hub.name)
                }
                .annotationTitles(.hidden)

                switch drillLevel {
                case .nation:
                    ForEach(stateGroups) { group in
                        MapPolyline(geodesicPolyline(from: hub.coordinate, to: group.coordinate))
                            .stroke(arcColor(group.dominantDirection), lineWidth: 1.15)
                    }
                    ForEach(stateGroups) { group in
                        Marker(group.markerTitle, coordinate: group.coordinate)
                            .tint(markerTint(group.dominantDirection))
                            .tag(group.state)
                    }
                case .state:
                    if pinsAgenciesDirectly {
                        ForEach(agencyPins) { partner in
                            if let link = partner.link(for: hub.id) {
                                MapPolyline(geodesicPolyline(from: hub.coordinate, to: partner.coordinate))
                                    .stroke(arcColor(link.direction), lineWidth: 1.15)
                            }
                        }
                        ForEach(agencyPins) { partner in
                            Marker(partner.name, coordinate: partner.coordinate)
                                .tint(markerTint(partner.link(for: hub.id)?.direction ?? .hubOut))
                                .tag(partner.id)
                        }
                    } else {
                        ForEach(countyGroups) { group in
                            MapPolyline(geodesicPolyline(from: hub.coordinate, to: group.coordinate))
                                .stroke(arcColor(group.dominantDirection), lineWidth: 1.15)
                        }
                        ForEach(countyGroups) { group in
                            Marker(group.markerTitle, coordinate: group.coordinate)
                                .tint(markerTint(group.dominantDirection))
                                .tag(group.id)
                        }
                    }
                case .county:
                    ForEach(agencyPins) { partner in
                        if let link = partner.link(for: hub.id) {
                            MapPolyline(geodesicPolyline(from: hub.coordinate, to: partner.coordinate))
                                .stroke(arcColor(link.direction), lineWidth: 1.15)
                        }
                    }
                    ForEach(agencyPins) { partner in
                        Marker(partner.name, coordinate: partner.coordinate)
                            .tint(markerTint(partner.link(for: hub.id)?.direction ?? .hubOut))
                            .tag(partner.id)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SHARING NETWORK")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(AppTheme.foreground)
                Text(statusLine)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                if store.isLoaded, selectedHub != nil {
                    Text("FOIA names pinned to Census places — not live Flock data")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.mutedForeground)
                }
            }
            Spacer()
            Button {
                showPartnerSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.foreground)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.card.opacity(0.92))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
            }
            .accessibilityLabel("Find partners")
            .disabled(selectedHub == nil || !store.isLoaded)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.foreground)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.card.opacity(0.92))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
            }
            .accessibilityLabel("Close sharing network")
        }
        .padding(.horizontal, 16)
    }

    private var hubPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.hubs) { hub in
                    Button {
                        selectHub(hub)
                    } label: {
                        Text(hub.shortName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selectedHub?.id == hub.id ? AppTheme.background : AppTheme.foreground)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedHub?.id == hub.id ? AppTheme.primary : AppTheme.card.opacity(0.92))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.border, lineWidth: selectedHub?.id == hub.id ? 0 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(hub.shortName) sharing network")
                    .accessibilityAddTraits(selectedHub?.id == hub.id ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var breadcrumb: some View {
        if drillLevel != .nation {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    breadcrumbChip("United States") {
                        goNation(animated: true)
                    }
                    if case .county(let state, _) = drillLevel {
                        breadcrumbChip(SharingStateGeography.displayName(for: state)) {
                            enterState(state, animated: true)
                        }
                    }
                    if case .state = drillLevel, !ungroupedInState.isEmpty, !pinsAgenciesDirectly {
                        breadcrumbChip("Ungrouped · \(ungroupedInState.count)") {
                            showUngrouped = true
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func breadcrumbChip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(AppTheme.card.opacity(0.92))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var legend: some View {
        HStack(spacing: 10) {
            legendItem(color: AppTheme.primary, text: "Hub shares out")
            legendItem(color: AppTheme.accent, text: "Partner shares in")
            legendItem(color: AppTheme.sharingBidirectional, text: "Both")
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hub shares with partner, partner shares with hub, or bidirectional")
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.mutedForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = store.loadError {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.primary)
                Button("Try again") {
                    Task { await store.reload() }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .disabled(store.isLoading)
            } else {
                Text("Agency-to-agency FOIA links, mapped by inferred county from the agency name — not which cameras feed which agency.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var statusLine: String {
        if store.isLoading && !store.isLoaded {
            return "Loading…"
        }
        guard let hub = selectedHub else {
            return store.loadError == nil ? "Loading…" : "Unavailable"
        }
        switch drillLevel {
        case .nation:
            let agencies = totalPartnerCount
            let states = stateGroups.count
            let agencyWord = agencies == 1 ? "agency" : "agencies"
            let stateWord = states == 1 ? "state" : "states"
            return "\(hub.shortName) shares with \(agencies) \(agencyWord) in \(states) \(stateWord)"
        case .state(let state):
            let group = currentStateGroup
            let agencies = group?.partnerCount ?? 0
            let agencyWord = agencies == 1 ? "agency" : "agencies"
            if pinsAgenciesDirectly {
                return "\(SharingStateGeography.displayName(for: state)) · \(agencies) \(agencyWord)"
            }
            let counties = countyGroups.count
            let countyWord = counties == 1 ? "county" : "counties"
            return "\(SharingStateGeography.displayName(for: state)) · \(agencies) \(agencyWord) in \(counties) \(countyWord)"
        case .county(_, let county):
            let agencies = agencyPins.count
            let agencyWord = agencies == 1 ? "agency" : "agencies"
            return "\(county) · \(agencies) \(agencyWord)"
        }
    }

    private func handleMarkerSelection(_ markerID: String?) {
        guard let markerID else { return }
        switch drillLevel {
        case .nation:
            enterState(markerID, animated: true)
        case .state(let state):
            if pinsAgenciesDirectly {
                selectedPartner = agencyPins.first { $0.id == markerID }
            } else if let group = countyGroups.first(where: { $0.id == markerID }) {
                enterCounty(state: state, county: group.county, animated: true, presentSheet: true)
            }
        case .county:
            selectedPartner = agencyPins.first { $0.id == markerID }
        }
    }

    private func selectHub(_ hub: SharingHub) {
        selectedHubID = hub.id
        selectedPartner = nil
        selectedCountyGroup = nil
        selectedMarkerID = nil
        showUngrouped = false
        drillLevel = .nation
        refreshVisibleGroups()
        fitCurrentLevel(animated: true)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func goNation(animated: Bool) {
        selectedMarkerID = nil
        selectedCountyGroup = nil
        showUngrouped = false
        drillLevel = .nation
        refreshVisibleGroups()
        fitCurrentLevel(animated: animated)
    }

    private func enterState(_ state: String, animated: Bool) {
        selectedMarkerID = nil
        selectedCountyGroup = nil
        showUngrouped = false
        drillLevel = .state(state.uppercased())
        refreshVisibleGroups()
        fitCurrentLevel(animated: animated)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func enterCounty(state: String, county: String, animated: Bool, presentSheet: Bool) {
        selectedMarkerID = nil
        drillLevel = .county(state: state.uppercased(), county: county)
        refreshVisibleGroups()
        if presentSheet {
            if let group = countyGroups.first(where: { $0.county == county }) {
                selectedCountyGroup = group
            } else if let hub = selectedHub {
                selectedCountyGroup = store.countyGroups(for: hub.id, state: state)
                    .first { $0.county == county }
            }
        } else {
            selectedCountyGroup = nil
        }
        fitCurrentLevel(animated: animated)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func focusPartner(_ partner: SharingPartner) {
        selectedMarkerID = nil
        if let county = partner.inferredCountyName, partner.hasInferredLocation {
            enterCounty(state: partner.state, county: county, animated: true, presentSheet: false)
        } else {
            enterState(partner.state, animated: true)
        }
        selectedPartner = partner
        if partner.hasInferredLocation {
            moveCamera(
                to: MKCoordinateRegion(
                    center: partner.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 0.6)
                ),
                animated: true
            )
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func fitCurrentLevel(animated: Bool) {
        guard let hub = selectedHub else { return }
        let region: MKCoordinateRegion
        switch drillLevel {
        case .nation:
            region = SharingNetworkStore.regionFitting(hub: hub, stateGroups: stateGroups)
        case .state:
            if pinsAgenciesDirectly {
                region = SharingNetworkStore.regionFitting(
                    partners: agencyPins,
                    fallback: currentStateGroup?.coordinate ?? hub.coordinate
                )
            } else {
                region = SharingNetworkStore.regionFitting(hub: hub, countyGroups: countyGroups)
            }
        case .county(_, let county):
            let fallback = countyGroups.first { $0.county == county }?.coordinate
                ?? currentStateGroup?.coordinate
                ?? hub.coordinate
            region = SharingNetworkStore.regionFitting(partners: agencyPins, fallback: fallback)
        }
        moveCamera(to: region, animated: animated)
    }

    private func moveCamera(to region: MKCoordinateRegion, animated: Bool) {
        if animated, !reduceMotion {
            withAnimation(.easeInOut(duration: 0.35)) {
                position = .region(region)
            }
        } else {
            position = .region(region)
        }
    }

    private func refreshVisibleGroups() {
        guard let hub = selectedHub else {
            stateGroups = []
            countyGroups = []
            agencyPins = []
            return
        }
        let cap = SharingNetworkStore.maxRenderedPartners
        stateGroups = Array(store.stateGroups(for: hub.id).prefix(cap))
        switch drillLevel {
        case .nation:
            countyGroups = []
            agencyPins = []
        case .state(let state):
            let group = stateGroups.first { $0.state == state }
            if SharingNetworkStore.shouldPinAgenciesDirectly(partnerCount: group?.partnerCount ?? 0) {
                countyGroups = []
                agencyPins = Array(
                    store.partners(for: hub.id, state: state)
                        .filter(\.hasInferredLocation)
                        .prefix(cap)
                )
            } else {
                countyGroups = Array(store.countyGroups(for: hub.id, state: state).prefix(cap))
                agencyPins = []
            }
        case .county(let state, let county):
            countyGroups = Array(store.countyGroups(for: hub.id, state: state).prefix(cap))
            let group = countyGroups.first { $0.county == county }
            agencyPins = Array((group?.partners ?? []).prefix(cap))
        }
    }

    private func arcColor(_ direction: SharingDirection) -> Color {
        markerTint(direction).opacity(0.75)
    }

    private func markerTint(_ direction: SharingDirection) -> Color {
        switch direction {
        case .hubOut: return AppTheme.primary
        case .hubIn: return AppTheme.accent
        case .bidirectional: return AppTheme.sharingBidirectional
        }
    }

    private func geodesicPolyline(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) -> MKGeodesicPolyline {
        var coordinates = [start, end]
        return MKGeodesicPolyline(coordinates: &coordinates, count: coordinates.count)
    }
}

private struct SharingCountySheet: View {
    let group: SharingCountyGroup
    let hub: SharingHub
    let attribution: SharingAttribution?

    @State private var selectedPartner: SharingPartner?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(group.county), \(SharingStateGeography.displayName(for: group.state))")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.foreground)
                        Text(countSummary)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground)
                    }
                    .listRowBackground(AppTheme.card)
                }

                Section {
                    ForEach(group.partners) { partner in
                        Button {
                            selectedPartner = partner
                        } label: {
                            partnerRow(partner)
                        }
                        .listRowBackground(AppTheme.card)
                    }
                } header: {
                    Text("Agencies")
                        .foregroundStyle(AppTheme.mutedForeground)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle(group.county)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedPartner) { partner in
                SharingPartnerSheet(
                    partner: partner,
                    hub: hub,
                    attribution: attribution
                )
                .presentationDetents([.medium, .large])
                .presentationBackground(AppTheme.background)
            }
        }
    }

    private func partnerRow(_ partner: SharingPartner) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(partner.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.foreground)
                .multilineTextAlignment(.leading)
            if let link = partner.link(for: hub.id) {
                Text(link.direction.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
            }
        }
        .padding(.vertical, 4)
    }

    private var countSummary: String {
        let total = group.partnerCount == 1 ? "1 agency" : "\(group.partnerCount) agencies"
        var parts = [total]
        if group.hubOut > 0 { parts.append("\(group.hubOut) hub shares out") }
        if group.hubIn > 0 { parts.append("\(group.hubIn) partner shares in") }
        if group.bidirectional > 0 { parts.append("\(group.bidirectional) both") }
        return parts.joined(separator: " · ")
    }
}

private struct SharingUngroupedSheet: View {
    let partners: [SharingPartner]
    let stateName: String
    let hub: SharingHub
    let attribution: SharingAttribution?

    @State private var selectedPartner: SharingPartner?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("These FOIA names did not match a Census county or place in \(stateName). They stay on the list — not on a fake pin.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.mutedForeground)
                        .listRowBackground(AppTheme.card)
                }
                Section {
                    ForEach(partners) { partner in
                        Button {
                            selectedPartner = partner
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(partner.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.foreground)
                                    .multilineTextAlignment(.leading)
                                if let link = partner.link(for: hub.id) {
                                    Text(link.direction.label)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppTheme.mutedForeground)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(AppTheme.card)
                    }
                } header: {
                    Text("Ungrouped agencies")
                        .foregroundStyle(AppTheme.mutedForeground)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Ungrouped")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedPartner) { partner in
                SharingPartnerSheet(
                    partner: partner,
                    hub: hub,
                    attribution: attribution
                )
                .presentationDetents([.medium, .large])
                .presentationBackground(AppTheme.background)
            }
        }
    }
}

private struct SharingPartnerSearchSheet: View {
    let store: SharingNetworkStore
    let hub: SharingHub
    let totalPartnerCount: Int
    let onSelect: (SharingPartner) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissSearch) private var dismissSearch
    @State private var query = ""

    private var matches: [SharingPartner] {
        store.matchingPartners(for: hub.id, query: query)
    }

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        "Find partners",
                        systemImage: "magnifyingglass",
                        description: Text("Type an agency, county, or state — searches all \(totalPartnerCount) partners for \(hub.shortName).")
                    )
                } else if matches.isEmpty {
                    ContentUnavailableView(
                        "No partners match",
                        systemImage: "slash.circle",
                        description: Text("Try another name, county, or two-letter state.")
                    )
                } else {
                    List(matches) { partner in
                        Button {
                            closeSearch { onSelect(partner) }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(partner.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.foreground)
                                    .multilineTextAlignment(.leading)
                                HStack(spacing: 8) {
                                    Text(partner.state)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(AppTheme.accent)
                                    if let county = partner.inferredCountyName {
                                        Text(county)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(AppTheme.mutedForeground)
                                    }
                                    if let link = partner.link(for: hub.id) {
                                        Text(link.direction.label)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(AppTheme.mutedForeground)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(AppTheme.card)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Find partners")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Agency, county, or state")
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { closeSearch { dismiss() } }
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .onDisappear { KeyboardDismiss.resign() }
        }
    }

    private func closeSearch(then action: () -> Void) {
        dismissSearch()
        KeyboardDismiss.resign()
        action()
    }
}

private struct SharingPartnerSheet: View {
    let partner: SharingPartner
    let hub: SharingHub?
    let attribution: SharingAttribution?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(partner.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.foreground)

                    HStack(spacing: 8) {
                        StatusBadge(text: partner.state, color: AppTheme.accent)
                        if let county = partner.inferredCountyName {
                            StatusBadge(text: county, color: AppTheme.sharingBidirectional)
                        }
                        StatusBadge(
                            text: partner.entityType.replacingOccurrences(of: "_", with: " "),
                            color: AppTheme.mutedForeground
                        )
                    }

                    if let hub, let link = partner.link(for: hub.id) {
                        SectionCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("LINK TO \(hub.shortName.uppercased())")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.8)
                                    .foregroundStyle(AppTheme.mutedForeground)
                                Text(link.direction.label)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppTheme.foreground)
                                if let release = hub.releaseDate {
                                    Text("Hub release \(release)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppTheme.mutedForeground)
                                }
                            }
                        }
                    }

                    SectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SOURCE")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(AppTheme.mutedForeground)
                            Text(attribution?.title ?? "DeFlock Dane Shared Networks")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.foreground)
                            Text(attribution?.note ?? "")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.mutedForeground)
                            Text(pinHonesty)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.mutedForeground)
                            if let urlString = attribution?.url, let url = URL(string: urlString) {
                                Link("Open DeFlock Dane", destination: url)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(AppTheme.background)
            .navigationTitle("Partner agency")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var pinHonesty: String {
        let stateName = SharingStateGeography.displayName(for: partner.state)
        if partner.geocode == "place", let place = partner.placeName {
            let county = partner.inferredCountyName.map { " in \($0) County" } ?? ""
            return "Pinned from the agency name to \(place)\(county), \(stateName) — not a FOIA address."
        }
        if partner.geocode == "county", let county = partner.inferredCountyName {
            return "Pinned from the agency name to \(county) County, \(stateName) — not a FOIA address."
        }
        return "Listed under \(stateName) — the FOIA name did not match a Census place, and files do not include an agency address."
    }
}
