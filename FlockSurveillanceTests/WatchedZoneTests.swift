import Foundation
import XCTest
@testable import FlockSurveillance

final class WatchedZoneTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    // MARK: - Corridor entry

    func testFirstEntryStartsZone() {
        var tracker = WatchedZoneTracker()
        XCTAssertEqual(tracker.enter(cameraID: "a", now: t0), .enteredZone)
        XCTAssertTrue(tracker.isInside)
        XCTAssertEqual(tracker.passedCount, 1)
    }

    func testSecondCameraWhileInsideEmitsAnotherCamera() {
        var tracker = WatchedZoneTracker()
        _ = tracker.enter(cameraID: "a", now: t0)
        XCTAssertEqual(tracker.enter(cameraID: "b", now: t0), .anotherCamera(passedCount: 2))
    }

    func testDuplicateEntryIsSilent() {
        var tracker = WatchedZoneTracker()
        _ = tracker.enter(cameraID: "a", now: t0)
        XCTAssertNil(tracker.enter(cameraID: "a", now: t0))
        XCTAssertEqual(tracker.passedCount, 1)
    }

    // MARK: - Corridor exit

    func testExitOfNonLastRegionIsSilent() {
        var tracker = WatchedZoneTracker()
        _ = tracker.enter(cameraID: "a", now: t0)
        _ = tracker.enter(cameraID: "b", now: t0)
        XCTAssertNil(tracker.exit(cameraID: "a", now: t0))
        XCTAssertTrue(tracker.isInside)
    }

    func testExitOfLastRegionEmitsExitPendingWithPassedCount() {
        var tracker = WatchedZoneTracker()
        _ = tracker.enter(cameraID: "a", now: t0)
        _ = tracker.enter(cameraID: "b", now: t0)
        _ = tracker.exit(cameraID: "a", now: t0)
        XCTAssertEqual(tracker.exit(cameraID: "b", now: t0), .exitPending(passedCount: 2))
        XCTAssertFalse(tracker.isInside)
    }

    func testExitOfUnknownRegionIsSilent() {
        var tracker = WatchedZoneTracker()
        XCTAssertNil(tracker.exit(cameraID: "ghost", now: t0))
    }

    // MARK: - Linger window

    func testReentryWithinLingerResumesCorridor() {
        var tracker = WatchedZoneTracker()
        _ = tracker.enter(cameraID: "a", now: t0)
        _ = tracker.exit(cameraID: "a", now: t0)

        let withinLinger = t0.addingTimeInterval(WatchedZoneTracker.lingerInterval - 1)
        XCTAssertEqual(tracker.enter(cameraID: "b", now: withinLinger), .resumedZone)
        // Same corridor: passed cameras accumulate across the gap.
        XCTAssertEqual(tracker.enter(cameraID: "c", now: withinLinger), .anotherCamera(passedCount: 3))
    }

    func testReentryAfterLingerStartsFreshCorridor() {
        var tracker = WatchedZoneTracker()
        _ = tracker.enter(cameraID: "a", now: t0)
        _ = tracker.exit(cameraID: "a", now: t0)

        let afterLinger = t0.addingTimeInterval(WatchedZoneTracker.lingerInterval + 1)
        XCTAssertEqual(tracker.enter(cameraID: "b", now: afterLinger), .enteredZone)
        XCTAssertEqual(tracker.passedCount, 1)
    }

    // MARK: - Reseed reconciliation

    func testReconcileKeepsMonitoredInsideRegions() {
        var tracker = WatchedZoneTracker()
        _ = tracker.enter(cameraID: "a", now: t0)
        _ = tracker.enter(cameraID: "b", now: t0)
        XCTAssertNil(tracker.reconcile(monitoredIDs: ["a", "b", "c"], now: t0))
        XCTAssertEqual(tracker.insideIDs, ["a", "b"])
    }

    func testReconcilePrunesStaleButStaysInsideSilently() {
        var tracker = WatchedZoneTracker()
        _ = tracker.enter(cameraID: "a", now: t0)
        _ = tracker.enter(cameraID: "b", now: t0)
        XCTAssertNil(tracker.reconcile(monitoredIDs: ["b"], now: t0))
        XCTAssertEqual(tracker.insideIDs, ["b"])
    }

    func testReconcileEmptyingZoneEmitsExitPending() {
        var tracker = WatchedZoneTracker()
        _ = tracker.enter(cameraID: "a", now: t0)
        _ = tracker.enter(cameraID: "b", now: t0)
        XCTAssertEqual(
            tracker.reconcile(monitoredIDs: ["x", "y"], now: t0),
            .exitPending(passedCount: 2)
        )
        XCTAssertFalse(tracker.isInside)
    }

    // MARK: - Reset + persistence

    func testResetClearsAllState() {
        var tracker = WatchedZoneTracker()
        _ = tracker.enter(cameraID: "a", now: t0)
        _ = tracker.exit(cameraID: "a", now: t0)
        tracker.reset()
        XCTAssertEqual(tracker, WatchedZoneTracker())
    }

    func testStoreRoundTrip() {
        let defaults = UserDefaults(suiteName: "watched-zone-tests")!
        defaults.removeObject(forKey: WatchedZoneStore.key)

        var tracker = WatchedZoneTracker()
        _ = tracker.enter(cameraID: "a", now: t0)
        _ = tracker.enter(cameraID: "b", now: t0)
        _ = tracker.exit(cameraID: "b", now: t0)

        WatchedZoneStore.write(tracker, defaults: defaults)
        XCTAssertEqual(WatchedZoneStore.read(defaults: defaults), tracker)
    }

    func testStoreReadFallsBackToEmptyTracker() {
        let defaults = UserDefaults(suiteName: "watched-zone-tests-empty")!
        defaults.removeObject(forKey: WatchedZoneStore.key)
        XCTAssertEqual(WatchedZoneStore.read(defaults: defaults), WatchedZoneTracker())
    }

    func testApproxRadiusFeetMatchesRegionRadius() {
        // 150 m ≈ 492 ft → rounded to the 50 ft step for notification copy.
        XCTAssertEqual(AlertsEngine.approxRadiusFeet, 500)
    }
}
