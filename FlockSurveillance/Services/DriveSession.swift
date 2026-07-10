import CoreLocation
import Foundation
import MapKit
import UIKit

struct DriveHit: Identifiable, Hashable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let manufacturer: String
    let isFlock: Bool
    let metersFromStart: CLLocationDistance

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DriveHit, rhs: DriveHit) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
@Observable
final class DriveSession {
    /// Shared instance so the CarPlay scene can observe the active drive.
    static let shared = DriveSession()

    private(set) var isActive = false
    private(set) var route: MKRoute?
    private(set) var hits: [DriveHit] = []
    private(set) var passedIDs: Set<String> = []
    private(set) var nextHit: DriveHit?
    private(set) var metersToNext: CLLocationDistance?
    private(set) var camerasRemaining = 0
    private(set) var exposureLabel = "Clear"

    private var lastPulseDistance: CLLocationDistance = .greatestFiniteMagnitude

    func start(from result: RouteExposureResult) {
        route = result.route
        hits = result.cameras.map {
            DriveHit(
                id: $0.camera.id,
                coordinate: $0.camera.coordinate,
                title: $0.camera.displayTitle,
                manufacturer: $0.camera.displayManufacturer,
                isFlock: $0.camera.isFlock,
                metersFromStart: $0.metersFromStart
            )
        }
        passedIDs = []
        exposureLabel = result.exposureScore
        isActive = true
        lastPulseDistance = .greatestFiniteMagnitude
        // The Drive HUD already surfaces approaches; don't double-notify.
        AlertsEngine.shared.isSuppressed = true
        refresh(userLocation: nil)
        Task { await DriveLiveActivityController.shared.start(session: self) }
    }

    func stop() {
        isActive = false
        AlertsEngine.shared.isSuppressed = false
        route = nil
        hits = []
        passedIDs = []
        nextHit = nil
        metersToNext = nil
        camerasRemaining = 0
        Task { await DriveLiveActivityController.shared.end() }
    }

    func update(userLocation: CLLocation?, hapticsEnabled: Bool) {
        guard isActive else { return }
        refresh(userLocation: userLocation)
        Task { await DriveLiveActivityController.shared.update(session: self) }

        guard hapticsEnabled, let metersToNext else { return }
        let thresholds: [CLLocationDistance] = [400, 200, 100, 50]
        for threshold in thresholds {
            if metersToNext <= threshold, lastPulseDistance > threshold {
                let style: UIImpactFeedbackGenerator.FeedbackStyle = threshold <= 100 ? .heavy : .medium
                let generator = UIImpactFeedbackGenerator(style: style)
                generator.prepare()
                generator.impactOccurred(intensity: threshold <= 100 ? 1.0 : 0.75)
                break
            }
        }
        lastPulseDistance = metersToNext
    }

    private func refresh(userLocation: CLLocation?) {
        guard let userLocation else {
            nextHit = hits.first(where: { !passedIDs.contains($0.id) })
            camerasRemaining = hits.filter { !passedIDs.contains($0.id) }.count
            metersToNext = nil
            return
        }

        for hit in hits where !passedIDs.contains(hit.id) {
            let distance = userLocation.distance(
                from: CLLocation(latitude: hit.coordinate.latitude, longitude: hit.coordinate.longitude)
            )
            if distance < 35 {
                passedIDs.insert(hit.id)
            }
        }

        let remaining = hits
            .filter { !passedIDs.contains($0.id) }
            .map { hit -> (DriveHit, CLLocationDistance) in
                let meters = userLocation.distance(
                    from: CLLocation(latitude: hit.coordinate.latitude, longitude: hit.coordinate.longitude)
                )
                return (hit, meters)
            }
            .sorted { $0.1 < $1.1 }

        camerasRemaining = remaining.count
        if let nearest = remaining.first {
            nextHit = nearest.0
            metersToNext = nearest.1
        } else {
            nextHit = nil
            metersToNext = nil
        }
    }
}
