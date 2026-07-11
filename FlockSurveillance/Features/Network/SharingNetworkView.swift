import MapKit
import SwiftUI

struct SharingNetworkView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = SharingNetworkStore()
    @State private var selectedHubID: String?
    @State private var selectedPartner: SharingPartner?
    @State private var selectedPartnerID: String?
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.8, longitude: -98.5),
            span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 50)
        )
    )
    @State private var visibleRegion: MKCoordinateRegion?

    private var selectedHub: SharingHub? {
        guard let selectedHubID else { return store.hubs.first }
        return store.hubs.first { $0.id == selectedHubID } ?? store.hubs.first
    }

    /// Every partner pin (uncapped) — matches the source “reach point” footprint.
    private var reachPoints: [SharingArc] {
        guard let hub = selectedHub else { return [] }
        return store.reachPoints(for: hub.id)
    }

    /// Polylines stay capped for map performance.
    private var arcs: [SharingArc] {
        guard let hub = selectedHub else { return [] }
        return store.arcs(for: hub.id, limit: 250, preferring: visibleRegion)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                AppTheme.background.ignoresSafeArea()

                // MapKit misbehaves when created at a degenerate size, so gate
                // on live geometry until the container has a real frame.
                if geo.size.width > 1, geo.size.height > 1 {
                    mapContent
                } else {
                    ProgressView()
                        .tint(AppTheme.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

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
            selectedPartner = reachPoints.first { $0.partner.id == partnerID }?.partner
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

                ForEach(reachPoints) { point in
                    Marker(point.partner.name, coordinate: point.partner.coordinate)
                        .tint(markerTint(point.direction))
                        .tag(point.partner.id)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .ignoresSafeArea()
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleRegion = context.region
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
        let points = reachPoints.count
        let shownArcs = arcs.count
        if points > shownArcs {
            return "\(hub.shortName) · \(points) partners · \(shownArcs) arcs"
        }
        return "\(hub.shortName) · \(points) partners"
    }

    private func selectHub(_ hub: SharingHub) {
        selectedHubID = hub.id
        selectedPartnerID = nil
        // Clear stale viewport so the new hub isn't filtered against the previous camera.
        visibleRegion = nil
        fitCamera(to: hub, animated: true)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func fitCamera(to hub: SharingHub?, animated: Bool = false) {
        guard let hub else { return }
        let fitted = SharingNetworkStore.regionFitting(
            hub: hub,
            partners: store.partners(for: hub.id)
        )
        visibleRegion = fitted
        if animated {
            withAnimation(.easeInOut(duration: 0.35)) {
                position = .region(fitted)
            }
        } else {
            position = .region(fitted)
        }
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
