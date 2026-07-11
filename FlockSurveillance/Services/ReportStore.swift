import CoreLocation
import Foundation
import MapKit
import SwiftData
import UserNotifications

/// Tracks OSM camera reports locally and verifies when they land on the map.
@MainActor
@Observable
final class ReportStore {
    static let shared = ReportStore()

    /// Cameras within this distance of a new-camera report count as "landed".
    static let landedProximityMeters: CLLocationDistance = 75
    /// Minimum age / gap between verification passes per report.
    static let verificationThrottle: TimeInterval = 6 * 60 * 60
    /// Overpass bbox half-span (~200 m) around a pending pin.
    static let verifyRegionSpanDegrees: Double = 0.004

    private(set) var reports: [PendingReport] = []
    private var modelContext: ModelContext?
    private var isVerifying = false
    /// Set when a forced recheck arrives while a pass is already running.
    private var recheckRequested = false

    func attach(modelContext: ModelContext) {
        if self.modelContext != nil { return }
        self.modelContext = modelContext
        reload()
    }

    func reload() {
        guard let modelContext else {
            reports = []
            return
        }
        let fetched = (try? modelContext.fetch(FetchDescriptor<PendingReport>())) ?? []
        reports = fetched.sorted { $0.createdAt > $1.createdAt }
    }

    var activeMapReports: [PendingReport] {
        reports.filter(\.showsOnMap)
    }

    var openCount: Int {
        reports.filter { $0.status == .open || $0.status == .pending }.count
    }

    var landedCount: Int {
        reports.filter { $0.status == .landed }.count
    }

    @discardableResult
    func recordSubmission(
        report: OSMCameraReport,
        noteID: Int?,
        baselineCameraIDs: [String] = []
    ) -> PendingReport? {
        guard let modelContext else { return nil }
        let row = PendingReport(
            osmNoteID: noteID,
            kind: report.kind,
            latitude: report.coordinate.latitude,
            longitude: report.coordinate.longitude,
            existingCameraID: report.existingCameraID,
            direction: report.direction,
            mountType: report.mountType,
            operatorGuess: report.operatorGuess,
            notes: report.notes,
            status: noteID == nil ? .failed : .open,
            baselineCameraIDs: baselineCameraIDs
        )
        modelContext.insert(row)
        try? modelContext.save()
        reload()
        if noteID != nil {
            Task {
                _ = try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])
            }
        }
        return row
    }

    func updateStatus(_ report: PendingReport, to status: PendingReportStatus, landedCameraID: String? = nil) {
        guard let modelContext else { return }
        let previous = report.status
        report.status = status
        report.lastCheckedAt = .now
        if let landedCameraID {
            report.landedCameraID = landedCameraID
        }
        try? modelContext.save()
        reload()
        if status == .landed, previous != .landed {
            notifyLanded(report)
        }
    }

    func dismissFromMap(_ report: PendingReport) {
        guard let modelContext else { return }
        // Keep status open so verification continues; only hide the optimistic pin.
        report.hiddenFromMap = true
        try? modelContext.save()
        reload()
    }

    func pruneOldTerminal(olderThan days: TimeInterval = 90 * 24 * 60 * 60) {
        guard let modelContext else { return }
        let cutoff = Date().addingTimeInterval(-days)
        for report in reports where [.landed, .closed, .failed].contains(report.status) && report.createdAt < cutoff {
            modelContext.delete(report)
        }
        try? modelContext.save()
        reload()
    }

    /// Pure helper — a nearby ALPR means a new-camera report has landed.
    /// `baselineIDs` are cameras already present at submit time (ignored).
    nonisolated static func landedCameraID(
        for reportCoordinate: CLLocationCoordinate2D,
        among cameras: [(id: String, latitude: Double, longitude: Double)],
        baselineIDs: Set<String> = [],
        proximityMeters: CLLocationDistance = 75
    ) -> String? {
        let origin = CLLocation(latitude: reportCoordinate.latitude, longitude: reportCoordinate.longitude)
        return cameras
            .filter { !baselineIDs.contains($0.id) }
            .map { row -> (String, CLLocationDistance) in
                let location = CLLocation(latitude: row.latitude, longitude: row.longitude)
                return (row.id, location.distance(from: origin))
            }
            .filter { $0.1 <= proximityMeters }
            .sorted { $0.1 < $1.1 }
            .first?
            .0
    }

    /// Verify open reports: note status + nearby Overpass / cache.
    func verifyOpenReports(
        repository: CameraRepository,
        force: Bool = false
    ) async {
        if force {
            recheckRequested = true
        }
        guard !isVerifying else { return }
        isVerifying = true
        defer { isVerifying = false }

        var bypassThrottle = force
        repeat {
            recheckRequested = false
            pruneOldTerminal()
            let candidates = reports.filter { $0.status == .open || $0.status == .pending }
            if !candidates.isEmpty {
                for report in candidates {
                    if !bypassThrottle, let last = report.lastCheckedAt,
                       Date().timeIntervalSince(last) < Self.verificationThrottle {
                        continue
                    }
                    await verifyOne(report, repository: repository)
                }
            }
            bypassThrottle = recheckRequested
        } while recheckRequested
    }

    private func verifyOne(_ report: PendingReport, repository: CameraRepository) async {
        var noteClosed = false
        var noteLookupSucceeded = report.osmNoteID == nil
        if let noteID = report.osmNoteID {
            do {
                let note = try await OSMReportService.shared.fetchNote(id: noteID)
                noteClosed = note.isClosed
                noteLookupSucceeded = true
            } catch {
                // Soft-fail note lookup; still try Overpass when useful.
            }
        }

        let region = MKCoordinateRegion(
            center: report.coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: Self.verifyRegionSpanDegrees,
                longitudeDelta: Self.verifyRegionSpanDegrees
            )
        )

        switch report.kind {
        case .newCamera:
            // Probe must not poison Place Score settlement via lastFetchedRegion.
            let remoteIDs = await repository.probeCameras(in: region)
            guard let remoteIDs else {
                // Don't burn the 6h throttle on a failed Overpass call.
                return
            }
            let nearby = repository.cameras(near: report.coordinate, radiusMeters: Self.landedProximityMeters)
                .filter { !$0.isHidden && !$0.isAbsentFromOSM && remoteIDs.contains($0.id) }
            let matchID = Self.landedCameraID(
                for: report.coordinate,
                among: nearby.map { ($0.id, $0.latitude, $0.longitude) },
                baselineIDs: report.baselineCameraIDs
            )
            if let matchID {
                updateStatus(report, to: .landed, landedCameraID: matchID)
            } else if noteLookupSucceeded, noteClosed {
                updateStatus(report, to: .closed)
            } else {
                markChecked(report)
            }

        case .wrongInfo:
            guard noteLookupSucceeded else { return }
            if noteClosed {
                updateStatus(report, to: .closed)
            } else {
                markChecked(report)
            }

        case .removed:
            guard let cameraID = report.existingCameraID else {
                if noteLookupSucceeded, noteClosed {
                    updateStatus(report, to: .closed)
                }
                return
            }
            let remoteIDs = await repository.probeCameras(in: region)
            guard let remoteIDs else { return }
            let stillOnOSM = remoteIDs.contains(cameraID)
            if noteLookupSucceeded, noteClosed, !stillOnOSM {
                repository.hideCamera(id: cameraID)
                updateStatus(report, to: .landed, landedCameraID: cameraID)
            } else if noteLookupSucceeded, noteClosed {
                updateStatus(report, to: .closed)
            } else {
                markChecked(report)
            }
        }
    }

    private func markChecked(_ report: PendingReport) {
        report.lastCheckedAt = .now
        try? modelContext?.save()
        reload()
    }

    private func notifyLanded(_ report: PendingReport) {
        let content = UNMutableNotificationContent()
        content.title = "Your report landed"
        switch report.kind {
        case .newCamera:
            content.body = "A mapped ALPR now appears near your report. Open the map to see it."
        case .removed:
            content.body = "Your removal report was confirmed — that camera is hidden on your map."
        case .wrongInfo:
            content.body = "Mappers closed your correction note."
        }
        content.sound = .default
        let lat = String(format: "%.3f", report.latitude)
        let lon = String(format: "%.3f", report.longitude)
        content.userInfo = ["deepLink": "flocksurveillance://map?lat=\(lat)&lon=\(lon)"]

        let request = UNNotificationRequest(
            identifier: "report.landed.\(report.id.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
