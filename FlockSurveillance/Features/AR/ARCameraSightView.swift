import AVFoundation
import ARKit
import CoreLocation
import MapKit
import SwiftUI
import UIKit

struct ARCameraSightView: View {
    @Environment(CameraRepository.self) private var repository
    @Environment(LocationManager.self) private var locationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var cameraAuth: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var selectedDetail: ARSelectedCamera?
    @State private var anchorCoordinate: CLLocationCoordinate2D?
    @State private var lastAnchorLocation: CLLocation?
    /// Last location used for soft nearby membership refresh (no AR reset).
    @State private var lastSoftRefreshLocation: CLLocation?
    @State private var isSessionActive = true
    @State private var trackingResetID = UUID()
    /// Cached nearby set — refreshed on anchor / cache / fetch changes, not every body pass.
    @State private var nearbyItems: [NearbyARItem] = []

    /// Soft-refresh which cameras are in range while walking.
    private let softRefreshMeters: CLLocationDistance = 8
    /// Only hard-reset AR world origin when GPS has drifted far from the session anchor.
    private let hardReanchorMeters: CLLocationDistance = 80

    private var arSupported: Bool {
        ARWorldTrackingConfiguration.isSupported
    }

    private var locationDenied: Bool {
        let status = locationManager.authorizationStatus
        return status == .denied || status == .restricted
    }

    private var cameraDenied: Bool {
        cameraAuth == .denied || cameraAuth == .restricted
    }

    private var annotations: [ARCameraAnnotation] {
        let live = locationManager.location
        return nearbyItems.map { item in
            let yaw: Float? = GeoHelpers.directionDegrees(from: item.camera.direction)
                .map { ARGeoMath.fovYawRadians(bearingDegrees: $0) }
            let liveDistance = live.map { item.camera.location.distance(from: $0) } ?? item.offset.distance
            return ARCameraAnnotation(
                id: item.camera.id,
                position: ARGeoMath.arPosition(for: item.offset),
                distanceLabel: ProximityRadar.formatDistance(liveDistance),
                isFlock: item.camera.isFlock,
                fovYawRadians: yaw
            )
        }
    }

    private var nearestMeters: CLLocationDistance? {
        guard let live = locationManager.location else {
            return nearbyItems.first?.offset.distance
        }
        return nearbyItems.map { $0.camera.location.distance(from: live) }.min()
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if !arSupported {
                unsupportedState
            } else if cameraDenied {
                permissionState(
                    title: "Camera access needed",
                    message: "AR Camera Sight overlays mapped ALPR locations on your camera view. Video stays on your device and is never recorded.",
                    icon: "camera.fill"
                )
            } else if locationDenied {
                permissionState(
                    title: "Location access needed",
                    message: "Enable location so pins can be placed relative to where you are standing.",
                    icon: "location.slash.fill"
                )
            } else if cameraAuth == .authorized {
                ARCameraSightRepresentable(
                    annotations: annotations,
                    onSelectCameraID: { id in
                        if let camera = nearbyItems.first(where: { $0.id == id })?.camera {
                            selectedDetail = ARSelectedCamera(camera: camera)
                        }
                    },
                    isActive: isSessionActive,
                    trackingResetID: trackingResetID
                )
                .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(AppTheme.accent)
            }

            VStack {
                hud
                Spacer()
                    .allowsHitTesting(false)
                if arSupported, cameraAuth == .authorized, !locationDenied, nearbyItems.isEmpty {
                    emptyBanner
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                        .allowsHitTesting(false)
                } else {
                    Text("Positions are approximate · mapped locations only — not a live feed")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.mutedForeground)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                        .allowsHitTesting(false)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            locationManager.start()
            refreshCameraAuth()
            requestCameraIfNeeded()
            reanchor(to: locationManager.location, resetTracking: true)
            lastSoftRefreshLocation = locationManager.location
            fetchNearbyRegion()
            refreshNearby()
            isSessionActive = true
        }
        .onDisappear {
            isSessionActive = false
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshCameraAuth()
            refreshNearby()
        }
        .onChange(of: locationManager.location?.timestamp) { _, _ in
            handleLocationMove()
        }
        .onChange(of: repository.cameras.count) { _, _ in
            refreshNearby()
        }
        .onChange(of: repository.isLoading) { _, loading in
            if !loading {
                refreshNearby()
            }
        }
        .sheet(item: $selectedDetail) { item in
            CameraDetailSheet(cameras: [item.camera], userLocation: locationManager.location)
                .presentationDetents([.medium, .large])
                .presentationBackground(AppTheme.background)
        }
    }

    private var hud: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SEE WHO'S WATCHING")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(AppTheme.foreground)
                Text(hudSubtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
            }
            .allowsHitTesting(false)
            Spacer()
                .allowsHitTesting(false)
            Button {
                isSessionActive = false
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
            .accessibilityLabel("Close AR")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var hudSubtitle: String {
        if !arSupported { return "Requires a physical iPhone" }
        if cameraDenied || locationDenied { return "Permissions required" }
        let count = nearbyItems.count
        if count == 0 {
            return "No mapped cameras within 400 m"
        }
        let nearest = nearestMeters.map(ProximityRadar.formatDistance) ?? "—"
        return "\(count) in range · nearest \(nearest)"
    }

    private var emptyBanner: some View {
        VStack(spacing: 8) {
            Text("No mapped cameras within 400 m")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.foreground)
            Text("Pan the map or report one — AR only shows OpenStreetMap locations.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(AppTheme.card.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var unsupportedState: some View {
        VStack(spacing: 16) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(AppTheme.accent)
            Text("AR requires a device")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.foreground)
            Text("World tracking isn’t available in Simulator. Run on a physical iPhone to see mapped cameras in the street.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private func permissionState(title: String, message: String, icon: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppTheme.primary)
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.foreground)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(AppTheme.accent)
        }
    }

    private func refreshCameraAuth() {
        cameraAuth = AVCaptureDevice.authorizationStatus(for: .video)
    }

    private func requestCameraIfNeeded() {
        refreshCameraAuth()
        guard cameraAuth == .notDetermined else { return }
        AVCaptureDevice.requestAccess(for: .video) { granted in
            Task { @MainActor in
                cameraAuth = granted ? .authorized : .denied
            }
        }
    }

    private func refreshNearby() {
        guard let sessionOrigin = anchorCoordinate else {
            nearbyItems = []
            return
        }
        // Membership by live GPS; world positions relative to fixed session origin.
        let liveCoordinate = locationManager.location?.coordinate ?? sessionOrigin
        nearbyItems = ARGeoMath.nearbyCameras(from: repository.cameras, user: liveCoordinate)
            .map { item in
                NearbyARItem(
                    camera: item.camera,
                    offset: ARGeoMath.enuOffset(from: sessionOrigin, to: item.camera.coordinate)
                )
            }
    }

    private func fetchNearbyRegion() {
        guard let coordinate = locationManager.location?.coordinate ?? anchorCoordinate else { return }
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )
        repository.scheduleFetch(for: region, delayNanoseconds: 100_000_000)
    }

    private func handleLocationMove() {
        guard let location = locationManager.location else { return }

        // First fix (cold open often has no GPS on appear).
        if anchorCoordinate == nil || lastAnchorLocation == nil {
            reanchor(to: location, resetTracking: true)
            lastSoftRefreshLocation = location
            fetchNearbyRegion()
            refreshNearby()
            return
        }

        if let origin = lastAnchorLocation, location.distance(from: origin) >= hardReanchorMeters {
            reanchor(to: location, resetTracking: true)
            lastSoftRefreshLocation = location
            fetchNearbyRegion()
            refreshNearby()
            return
        }

        if let lastSoft = lastSoftRefreshLocation, location.distance(from: lastSoft) >= softRefreshMeters {
            lastSoftRefreshLocation = location
            refreshNearby()
            if location.distance(from: lastSoft) >= 40 {
                fetchNearbyRegion()
            }
        } else if lastSoftRefreshLocation == nil {
            lastSoftRefreshLocation = location
            refreshNearby()
        }
    }

    private func reanchor(to location: CLLocation?, resetTracking: Bool) {
        guard let location else { return }
        anchorCoordinate = location.coordinate
        lastAnchorLocation = location
        if resetTracking {
            trackingResetID = UUID()
        }
    }
}

private struct NearbyARItem: Identifiable {
    let camera: ALPRCamera
    let offset: ARGeoMath.LocalOffset
    var id: String { camera.id }
}

private struct ARSelectedCamera: Identifiable {
    let camera: ALPRCamera
    var id: String { camera.id }
}
