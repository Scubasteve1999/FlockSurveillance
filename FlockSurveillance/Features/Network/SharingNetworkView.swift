import MapKit
import SwiftUI
import UIKit

struct SharingNetworkView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = SharingNetworkStore()
    @State private var selectedHubID: String?
    @State private var selectedPartner: SharingPartner?
    @State private var selectedPartnerID: String?
    @State private var focusedPartner: SharingPartner?
    @State private var showPartnerSearch = false
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.8, longitude: -98.5),
            span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 50)
        )
    )
    @State private var visibleRegion: MKCoordinateRegion?

    /// Rendered pins and polylines both stay capped — an uncapped Marker count (up to
    /// 1,000+) overwhelms the accessibility tree and makes the sheet's own controls
    /// (close button, hub chips) unreachable to VoiceOver/UI automation. Kept in sync by
    /// `refreshArcs()` whenever the hub or visible region changes, rather than recomputed
    /// on every body evaluation — `store.arcs` rescans and stride-samples the full partner list.
    @State private var arcs: [SharingArc] = []

    private var selectedHub: SharingHub? {
        guard let selectedHubID else { return store.hubs.first }
        return store.hubs.first { $0.id == selectedHubID } ?? store.hubs.first
    }

    /// Total partner count for the hub, for the status line only — not the rendered list.
    private var totalPartnerCount: Int {
        guard let hub = selectedHub else { return 0 }
        return store.partners(for: hub.id).count
    }

    private var focusIsOffSample: Bool {
        guard let focusedPartner else { return false }
        return !arcs.contains { $0.partner.id == focusedPartner.id }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                AppTheme.background.ignoresSafeArea()

                MapKitSizeGate(size: geo.size) { mapContent }

                // Top chrome only — no full-height Spacer, so map gestures and
                // hub chips aren't fighting a pass-through overlay.
                VStack(spacing: 10) {
                    header
                    hubPicker
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
        .onChange(of: selectedPartnerID) { _, partnerID in
            guard let partnerID else { return }
            if let fromArcs = arcs.first(where: { $0.partner.id == partnerID })?.partner {
                selectedPartner = fromArcs
                // Drop search focus overlay when the user picks a different map pin.
                if focusedPartner?.id != partnerID {
                    focusedPartner = nil
                }
            } else if focusedPartner?.id == partnerID {
                selectedPartner = focusedPartner
            }
        }
        .onChange(of: store.isLoaded) { _, loaded in
            guard loaded, selectedHubID == nil else { return }
            selectedHubID = store.hubs.first?.id
            fitCamera(to: selectedHub)
        }
        .sheet(item: $selectedPartner) { partner in
            SharingPartnerSheet(
                partner: partner,
                hub: selectedHub,
                attribution: store.attribution
            )
            .presentationDetents([.medium, .large])
            .presentationBackground(AppTheme.background)
            .onDisappear { selectedPartnerID = nil }
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
        Map(position: $position, selection: $selectedPartnerID) {
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

                ForEach(arcs) { arc in
                    MapPolyline(geodesicPolyline(from: hub.coordinate, to: arc.partner.coordinate))
                        .stroke(arcColor(arc.direction), lineWidth: 1.15)
                }

                ForEach(arcs) { point in
                    Marker(point.partner.name, coordinate: point.partner.coordinate)
                        .tint(markerTint(point.direction))
                        .tag(point.partner.id)
                }

                // One extra pin for a search hit outside the 250-arc sample — never uncapped.
                if focusIsOffSample, let focused = focusedPartner,
                   let link = focused.link(for: hub.id) {
                    MapPolyline(geodesicPolyline(from: hub.coordinate, to: focused.coordinate))
                        .stroke(arcColor(link.direction), lineWidth: 1.35)
                    Marker(focused.name, coordinate: focused.coordinate)
                        .tint(markerTint(link.direction))
                        .tag(focused.id)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .ignoresSafeArea()
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleRegion = context.region
            refreshArcs()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SHARING NETWORK")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(AppTheme.foreground)
                Text(statusLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
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
                Text("Public records snapshot · not live Flock data")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedForeground)
                Text(store.attribution?.note ?? "Agency sharing links from FOIA releases — not which cameras feed which agency.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Partner pins are approximate (state-level), not exact agency addresses.")
                    .font(.system(size: 11, weight: .medium))
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
        let points = totalPartnerCount
        let shownArcs = arcs.count
        if points > shownArcs {
            return "\(hub.shortName) · \(points) partners · \(shownArcs) arcs"
        }
        return "\(hub.shortName) · \(points) partners"
    }

    private func selectHub(_ hub: SharingHub) {
        selectedHubID = hub.id
        selectedPartnerID = nil
        focusedPartner = nil
        // Clear stale viewport so the new hub isn't filtered against the previous camera.
        visibleRegion = nil
        fitCamera(to: hub, animated: true)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func focusPartner(_ partner: SharingPartner) {
        focusedPartner = partner
        selectedPartnerID = partner.id
        selectedPartner = partner
        let region = MKCoordinateRegion(
            center: partner.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4)
        )
        visibleRegion = region
        refreshArcs()
        withAnimation(.easeInOut(duration: 0.35)) {
            position = .region(region)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func fitCamera(to hub: SharingHub?, animated: Bool = false) {
        guard let hub else { return }
        let fitted = SharingNetworkStore.regionFitting(
            hub: hub,
            partners: store.partners(for: hub.id)
        )
        visibleRegion = fitted
        refreshArcs()
        if animated {
            withAnimation(.easeInOut(duration: 0.35)) {
                position = .region(fitted)
            }
        } else {
            position = .region(fitted)
        }
    }

    private func refreshArcs() {
        guard let hub = selectedHub else {
            arcs = []
            return
        }
        arcs = store.arcs(
            for: hub.id,
            limit: SharingNetworkStore.maxRenderedPartners,
            preferring: visibleRegion
        )
    }

    private func arcColor(_ direction: SharingDirection) -> Color {
        switch direction {
        case .hubOut: return AppTheme.primary.opacity(0.75)
        case .hubIn: return AppTheme.accent.opacity(0.75)
        case .bidirectional: return Color(red: 0.95, green: 0.72, blue: 0.28).opacity(0.8)
        }
    }

    private func markerTint(_ direction: SharingDirection) -> Color {
        switch direction {
        case .hubOut: return AppTheme.primary
        case .hubIn: return AppTheme.accent
        case .bidirectional: return Color(red: 0.95, green: 0.72, blue: 0.28)
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
                            Text("Map position is approximate (state-level centroid), not an exact agency address.")
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
