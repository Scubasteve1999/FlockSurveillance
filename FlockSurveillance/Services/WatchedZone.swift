import Foundation

/// Event emitted by `WatchedZoneTracker` when geofence membership changes.
enum WatchedZoneEvent: Equatable {
    /// First mapped camera of a new corridor — announce the zone.
    case enteredZone
    /// Re-entered during the linger window; cancel any pending exit summary silently.
    case resumedZone
    /// Another camera while already inside; `passedCount` is unique cameras this corridor.
    case anotherCamera(passedCount: Int)
    /// Left the last region; schedule an exit summary after the linger window.
    case exitPending(passedCount: Int)
}

/// Pure state machine for the "watched zone" corridor experience: tracks which
/// alert geofences the user is currently inside and turns raw region
/// enter/exit callbacks into corridor-level events. A corridor survives brief
/// gaps between cameras via a linger window, so one stretch of road produces a
/// single enter/exit pair instead of one per camera.
struct WatchedZoneTracker: Codable, Equatable {
    static let lingerInterval: TimeInterval = 90

    private(set) var insideIDs: Set<String> = []
    private(set) var passedIDs: Set<String> = []
    private(set) var lingerUntil: Date?

    var isInside: Bool { !insideIDs.isEmpty }
    var passedCount: Int { passedIDs.count }

    mutating func enter(cameraID: String, now: Date = .now) -> WatchedZoneEvent? {
        let wasInside = isInside
        let resuming = !wasInside && lingerUntil.map { now < $0 } ?? false
        if !wasInside, !resuming {
            passedIDs = []
        }
        lingerUntil = nil

        let inserted = insideIDs.insert(cameraID).inserted
        passedIDs.insert(cameraID)
        guard inserted else { return nil }

        if wasInside {
            return .anotherCamera(passedCount: passedIDs.count)
        }
        return resuming ? .resumedZone : .enteredZone
    }

    mutating func exit(cameraID: String, now: Date = .now) -> WatchedZoneEvent? {
        guard insideIDs.remove(cameraID) != nil, insideIDs.isEmpty else { return nil }
        lingerUntil = now.addingTimeInterval(Self.lingerInterval)
        return .exitPending(passedCount: passedIDs.count)
    }

    /// Reseeding stops monitoring for dropped regions, so their exit callbacks
    /// never arrive. Prune inside IDs that are no longer monitored; if that
    /// empties the zone, treat it as an exit.
    mutating func reconcile(monitoredIDs: Set<String>, now: Date = .now) -> WatchedZoneEvent? {
        let stale = insideIDs.subtracting(monitoredIDs)
        guard !stale.isEmpty else { return nil }
        insideIDs.subtract(stale)
        guard insideIDs.isEmpty else { return nil }
        lingerUntil = now.addingTimeInterval(Self.lingerInterval)
        return .exitPending(passedCount: passedIDs.count)
    }

    mutating func reset() {
        insideIDs = []
        passedIDs = []
        lingerUntil = nil
    }
}

/// Persists the tracker so corridor state survives background relaunches
/// (region callbacks routinely arrive after the system restarts the app).
enum WatchedZoneStore {
    static let key = "alerts.watchedZone"

    static func read(defaults: UserDefaults = .standard) -> WatchedZoneTracker {
        guard let data = defaults.data(forKey: key),
              let tracker = try? JSONDecoder().decode(WatchedZoneTracker.self, from: data)
        else { return WatchedZoneTracker() }
        return tracker
    }

    static func write(_ tracker: WatchedZoneTracker, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(tracker) else { return }
        defaults.set(data, forKey: key)
    }
}
