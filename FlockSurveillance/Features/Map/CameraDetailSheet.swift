import CoreLocation
import SwiftUI

struct CameraDetailSheet: View {
    let cameras: [ALPRCamera]
    var userLocation: CLLocation?

    private let highlightKeys = [
        "manufacturer", "brand", "operator", "direction", "camera:direction",
        "surveillance", "surveillance:type", "camera:type", "name", "ref"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(cameras.count == 1 ? "Camera Intel" : "\(cameras.count) Cameras")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppTheme.foreground)

                    Text("Crowdsourced OpenStreetMap data. Locations may be incomplete or outdated.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.mutedForeground)

                    ForEach(cameras, id: \.id) { camera in
                        SectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(camera.displayTitle)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(AppTheme.foreground)
                                    Spacer()
                                    StatusBadge(
                                        text: camera.isFlock ? "Flock" : "ALPR",
                                        color: camera.isFlock ? AppTheme.flockMarker : AppTheme.otherMarker
                                    )
                                }

                                detailRow("Manufacturer", camera.displayManufacturer)
                                detailRow("Operator", camera.operatorName ?? "Not tagged")
                                detailRow("Direction", camera.direction ?? "Not tagged")

                                if let userLocation {
                                    let meters = camera.location.distance(from: userLocation)
                                    detailRow("Distance", ProximityRadar.formatDistance(meters))
                                }

                                let coords = String(format: "%.5f, %.5f", camera.latitude, camera.longitude)
                                HStack(alignment: .bottom) {
                                    detailRow("Coordinates", coords)
                                    Spacer()
                                    Button {
                                        UIPasteboard.general.string = coords
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(AppTheme.accent)
                                    }
                                    .buttonStyle(.plain)
                                }

                                let tags = parsedTags(camera.tagsJSON)
                                let extras = tags.filter { highlightKeys.contains($0.key) && !isDuplicate($0.key, camera: camera) }
                                if !extras.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("OSM TAGS")
                                            .font(.system(size: 10, weight: .semibold))
                                            .tracking(0.8)
                                            .foregroundStyle(AppTheme.mutedForeground)
                                        ForEach(extras.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                            HStack {
                                                Text(key)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(AppTheme.mutedForeground)
                                                Spacer()
                                                Text(value)
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(AppTheme.foreground)
                                                    .multilineTextAlignment(.trailing)
                                            }
                                        }
                                    }
                                }

                                if let url = OverpassParser.osmURL(forCameraID: camera.id) {
                                    Link(destination: url) {
                                        Label("Open in OpenStreetMap", systemImage: "arrow.up.right.square")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(AppTheme.accent)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.top, 4)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background.ignoresSafeArea())
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(AppTheme.mutedForeground)
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.foreground)
        }
    }

    private func parsedTags(_ json: String) -> [String: String] {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }

    private func isDuplicate(_ key: String, camera: ALPRCamera) -> Bool {
        switch key {
        case "manufacturer", "brand":
            return camera.manufacturer != nil
        case "operator":
            return camera.operatorName != nil
        case "direction", "camera:direction":
            return camera.direction != nil
        case "name", "ref":
            return camera.cameraName != nil
        default:
            return false
        }
    }
}
