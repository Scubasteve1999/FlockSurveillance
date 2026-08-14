import MapKit
import SwiftUI
import UIKit

struct SharingNetworkView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var store = SharingNetworkStore()
    @State private var selectedHubID: String?
    @State private var selectedPartner: SharingPartner?
    @State private var selectedStateGroup: SharingStateGroup?
    @State private var selectedStateID: String?
    @State private var showPartnerSearch = false
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.8, longitude: -98.5),
            span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 50)
        )
    )
    @State private var stateGroups: [SharingStateGroup] = []

    private var selectedHub: SharingHub? {
        guard let selectedHubID else { return store.hubs.first }
        return store.hubs.first { $0.id == selectedHubID } ?? store.hubs.first
    }

    private var totalPartnerCount: Int {
        guard let hub = selectedHub else { return 0 }
        return store.partners(for: hub.id).count
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                AppTheme.background.ignoresSafeArea()

                MapKitSizeGate(size: geo.size) { mapContent }

                VStack(spacing: 10) {
                    header
                    hubPicker
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
        .onChange(of: selectedStateID) { _, stateID in
            guard let stateID else { return }
            selectedStateGroup = stateGroups.first { $0.state == stateID }
        }
        .onChange(of: store.isLoaded) { _, loaded in
            guard loaded, selectedHubID == nil else { return }
            selectedHubID = store.hubs.first?.id
            refreshStateGroups()
            fitCamera(to: selectedHub)
        }
        .sheet(item: $selectedStateGroup) { group in
            if let hub = selectedHub {
                SharingStateSheet(group: group, hub: hub, attribution: store.attribution)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(AppTheme.background)
                    .onDisappear { selectedStateID = nil }
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
    }

    private var mapContent: some View {
        Map(position: $position, selection: $selectedStateID) {
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

                ForEach(stateGroups) { group in
                    MapPolyline(geodesicPolyline(from: hub.coordinate, to: group.coordinate))
                        .stroke(arcColor(group.dominantDirection), lineWidth: 1.15)
                }

                ForEach(stateGroups) { group in
                    Marker(group.markerTitle, coordinate: group.coordinate)
                        .tint(markerTint(group.dominantDirection))
                        .tag(group.state)
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
                    Text("Sample of a public FOIA snapshot — not live Flock data")
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
                Text("Agency-to-agency FOIA links, mapped by state — not which cameras feed which agency.")
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
        let agencies = totalPartnerCount
        let states = stateGroups.count
        let agencyWord = agencies == 1 ? "agency" : "agencies"
        let stateWord = states == 1 ? "state" : "states"
        return "\(hub.shortName) shares with \(agencies) \(agencyWord) in \(states) \(stateWord)"
    }

    private func selectHub(_ hub: SharingHub) {
        selectedHubID = hub.id
        selectedPartner = nil
        selectedStateID = nil
        selectedStateGroup = nil
        refreshStateGroups()
        fitCamera(to: hub, animated: true)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func focusPartner(_ partner: SharingPartner) {
        selectedStateID = nil
        selectedStateGroup = nil
        selectedPartner = partner
        if let group = stateGroups.first(where: { $0.state == partner.state.uppercased() }) {
            let region = MKCoordinateRegion(
                center: group.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
            )
            moveCamera(to: region, animated: true)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func fitCamera(to hub: SharingHub?, animated: Bool = false) {
        guard let hub else { return }
        let fitted = SharingNetworkStore.regionFitting(hub: hub, stateGroups: stateGroups)
        moveCamera(to: fitted, animated: animated)
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

    private func refreshStateGroups() {
        guard let hub = selectedHub else {
            stateGroups = []
            return
        }
        let cap = SharingNetworkStore.maxRenderedPartners
        stateGroups = Array(store.stateGroups(for: hub.id).prefix(cap))
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

private struct SharingStateSheet: View {
    let group: SharingStateGroup
    let hub: SharingHub
    let attribution: SharingAttribution?

    @State private var selectedPartner: SharingPartner?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.name)
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
                    Text("Agencies")
                        .foregroundStyle(AppTheme.mutedForeground)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle(group.state)
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

    private var countSummary: String {
        let total = group.partnerCount == 1 ? "1 agency" : "\(group.partnerCount) agencies"
        var parts = [total]
        if group.hubOut > 0 { parts.append("\(group.hubOut) hub shares out") }
        if group.hubIn > 0 { parts.append("\(group.hubIn) partner shares in") }
        if group.bidirectional > 0 { parts.append("\(group.bidirectional) both") }
        return parts.joined(separator: " · ")
    }
}

private struct SharingPartnerSearchSheet: View {
    let store: SharingNetworkStore
    let hub: SharingHub
    let totalPartnerCount: Int
    let onSelect: (SharingPartner) -> Void

    @Environment(\.dismiss) private var dismiss
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
                        description: Text("Type an agency name or state — searches all \(totalPartnerCount) partners for \(hub.shortName).")
                    )
                } else if matches.isEmpty {
                    ContentUnavailableView(
                        "No partners match",
                        systemImage: "slash.circle",
                        description: Text("Try another name or two-letter state.")
                    )
                } else {
                    List(matches) { partner in
                        Button {
                            onSelect(partner)
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
            .searchable(text: $query, prompt: "Agency or state")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
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
                            Text("Listed on the map under \(SharingStateGeography.displayName(for: partner.state)) — FOIA files do not include an agency address.")
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
}
