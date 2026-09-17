import XCTest
@testable import FlockSurveillance

/// Locks stranger-facing chrome to the App Store product name.
/// Overwatch is a Drive/proximity mode, never a competing app title.
final class ProductChromeCopyTests: XCTestCase {
    func testChromeTokensMatchStoreName() {
        XCTAssertEqual(AppIdentity.displayName, "Flock Surveillance")
        XCTAssertEqual(AppIdentity.chromeMono, "FLOCK SURVEILLANCE")
        XCTAssertEqual(AppIdentity.chromeEyebrow("MAP"), "FLOCK SURVEILLANCE · MAP")
        XCTAssertEqual(AppIdentity.chromeEyebrow("ROUTE"), "FLOCK SURVEILLANCE · ROUTE")
        XCTAssertEqual(AppIdentity.chromeEyebrow("INTEL"), "FLOCK SURVEILLANCE · INTEL")
        XCTAssertEqual(AppIdentity.chromeEyebrow("GEAR"), "FLOCK SURVEILLANCE · GEAR")
        XCTAssertEqual(AppIdentity.chromeEyebrow("DRIVE"), "FLOCK SURVEILLANCE · DRIVE")
        XCTAssertEqual(AppIdentity.chromeEyebrow("AR SIGHT"), "FLOCK SURVEILLANCE · AR SIGHT")
        XCTAssertFalse(AppIdentity.chromeEyebrow("ROUTE").hasPrefix("OVERWATCH"))
        XCTAssertFalse(AppIdentity.chromeMono.contains("OVERWATCH"))
    }

    func testTabAndModeChromeUsesProductEyebrow() throws {
        let learn = try readProductSource("FlockSurveillance/Features/Learn/LearnView.swift")
        XCTAssertTrue(learn.contains("AppIdentity.chromeEyebrow(\"INTEL\")"))
        XCTAssertFalse(learn.contains("OVERWATCH · INTEL"))

        let settings = try readProductSource("FlockSurveillance/Features/Settings/SettingsView.swift")
        XCTAssertTrue(settings.contains("AppIdentity.chromeEyebrow(\"GEAR\")"))
        XCTAssertTrue(settings.contains("Tune Drive Mode, Home & Work for commute, and local cache."))
        XCTAssertFalse(settings.contains("OVERWATCH · GEAR"))
        XCTAssertFalse(settings.contains("Tune Overwatch"))

        let route = try readProductSource("FlockSurveillance/Features/Route/RouteExposureView.swift")
        XCTAssertTrue(route.contains("AppIdentity.chromeEyebrow(\"ROUTE\")"))
        XCTAssertTrue(route.contains("AppIdentity.chromeEyebrow(\"DRIVE\")"))
        XCTAssertTrue(route.contains("Resume Drive"))
        XCTAssertTrue(route.contains("Start Drive"))
        XCTAssertTrue(route.contains("Switch Drive"))
        XCTAssertFalse(route.contains("OVERWATCH · ROUTE"))
        XCTAssertFalse(route.contains("OVERWATCH · DRIVE"))
        XCTAssertFalse(route.contains("Resume Overwatch"))
        XCTAssertFalse(route.contains("Start Overwatch Drive"))

        let drive = try readProductSource("FlockSurveillance/Features/Route/DriveModeView.swift")
        XCTAssertTrue(drive.contains("AppIdentity.chromeEyebrow(\"DRIVE\")"))
        XCTAssertTrue(drive.contains("Hide HUD"))
        XCTAssertTrue(drive.contains("Hide drive HUD"))
        XCTAssertTrue(drive.contains("AppIdentity.displayName) drive"))
        XCTAssertFalse(drive.contains("OVERWATCH · DRIVE"))
        XCTAssertFalse(drive.contains("Hide Overwatch"))

        let ar = try readProductSource("FlockSurveillance/Features/AR/ARCameraSightView.swift")
        XCTAssertTrue(ar.contains("AppIdentity.chromeEyebrow(\"AR SIGHT\")"))
        XCTAssertFalse(ar.contains("OVERWATCH · AR SIGHT"))
    }

    func testMapBootAndOnboardingNameTheStoreProduct() throws {
        let chrome = try readProductSource("FlockSurveillance/Theme/OverwatchChrome.swift")
        XCTAssertTrue(chrome.contains("AppIdentity.chromeMono"))
        XCTAssertTrue(chrome.contains("AppIdentity.displayName"), "VoiceOver header/boot must speak the store name.")
        XCTAssertFalse(chrome.contains("OVERWATCH ONLINE"))
        XCTAssertFalse(chrome.contains("\"OVERWATCH\""))

        let onboarding = try readProductSource("FlockSurveillance/Features/Onboarding/OnboardingView.swift")
        XCTAssertTrue(onboarding.contains("AppIdentity.chromeMono"))
        XCTAssertTrue(onboarding.contains("Start Drive Mode"))
        XCTAssertTrue(onboarding.contains("powers Drive Mode proximity"))
        XCTAssertFalse(onboarding.contains("Turn on Overwatch"))
        XCTAssertFalse(onboarding.contains("powers Overwatch"))
    }

    func testShareCardsAndWidgetsUseProductName() throws {
        let shareCards = try readProductSource("FlockSurveillance/Theme/ShareCardRenderer.swift")
        XCTAssertTrue(shareCards.contains("AppIdentity.chromeMono"))
        XCTAssertTrue(shareCards.contains("\"PLACE SCORE\""))
        XCTAssertTrue(shareCards.contains("\"FEWEST PINS\""))
        XCTAssertTrue(shareCards.contains("MapHonestyCopy.chipLine"))
        XCTAssertFalse(shareCards.contains("OVERWATCH //"))

        let geo = try readProductSource("FlockSurveillance/Services/GeoHelpers.swift")
        XCTAssertTrue(geo.contains("AppIdentity.chromeMono"))
        XCTAssertFalse(geo.contains("FLOCK SURVEILLANCE · OVERWATCH"))

        let live = try readProductSource("FlockSurveillance/Services/DriveLiveActivityController.swift")
        XCTAssertTrue(live.contains("AppIdentity.displayName"))
        XCTAssertFalse(live.contains("Overwatch Drive"))

        let widget = try readProductSource("NearbyCamerasWidget/NearbyCamerasWidget.swift")
        XCTAssertTrue(widget.contains("AppIdentity.chromeMono"))
        XCTAssertTrue(widget.contains("Flock Surveillance · Home"))
        XCTAssertTrue(widget.contains("accessibilityLabel(AppIdentity.displayName)"))
        XCTAssertFalse(widget.contains("\"OVERWATCH\""))
        XCTAssertFalse(widget.contains("Overwatch · Home"))

        let activity = try readProductSource("NearbyCamerasWidget/DriveLiveActivityWidget.swift")
        XCTAssertTrue(activity.contains("AppIdentity.chromeEyebrow(\"DRIVE\")"))
        XCTAssertTrue(activity.contains("AppIdentity.displayName) drive"))
        XCTAssertFalse(activity.contains("OVERWATCH · DRIVE"))
    }

    func testMapHonestyAndFlockFilterUnchanged() {
        XCTAssertEqual(MapHonestyCopy.chipLine, "Not affiliated with Flock Safety · OSM / DeFlock community · Incomplete map.")
        XCTAssertEqual(CameraFilter.flockOnly.title, "Flock-branded pins")
        XCTAssertEqual(AppIdentity.displayName, "Flock Surveillance")
        XCTAssertEqual(AppIdentity.urlScheme, "flocksurveillance")
        XCTAssertEqual(AppIdentity.appGroupID, "group.com.flocksurveillance.shared")
    }

    func testMapWatchToggleKeepsOverwatchAsMode() throws {
        let hud = try readProductSource("FlockSurveillance/Features/Map/CameraAnnotationView.swift")
        XCTAssertTrue(hud.contains("Disable overwatch mode"))
        XCTAssertTrue(hud.contains("Set overwatch mode"))
        XCTAssertFalse(hud.contains("OVERWATCH ·"))
    }

    private func readProductSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
