import XCTest

/// The app's display name, export-compliance flag, Live Activities flag and
/// camera/location usage strings come from INFOPLIST_KEY_* build settings in
/// project.yml, not from Info.plist. These checks read the built app's Info.plist
/// (the test host) so a key that silently drops out of the build fails CI.
final class InfoPlistKeysTests: XCTestCase {
    private var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }

    func testBuildSettingKeysReachBuiltInfoPlist() {
        XCTAssertEqual(info["CFBundleDisplayName"] as? String, "Flock Surveillance")
        XCTAssertEqual(info["ITSAppUsesNonExemptEncryption"] as? Bool, false)
        XCTAssertEqual(info["NSSupportsLiveActivities"] as? Bool, true)
        XCTAssertEqual(
            info["NSCameraUsageDescription"] as? String,
            "Flock Surveillance uses the camera only to overlay mapped ALPR locations in AR. Video stays on your device and is not recorded or uploaded."
        )
        XCTAssertEqual(
            info["NSLocationAlwaysAndWhenInUseUsageDescription"] as? String,
            "Used for nearby pin alerts. Your precise location stays on your device; only a rough ~10 km area is requested from public OpenStreetMap servers."
        )
        XCTAssertEqual(
            info["NSLocationWhenInUseUsageDescription"] as? String,
            "Flock Surveillance uses your location to show nearby mapped ALPR cameras and route exposure."
        )
    }

    func testInfoPlistFileKeysStillPresent() {
        XCTAssertEqual(info["CFBundleIconName"] as? String, "AppIcon")
        XCTAssertEqual(info["UIBackgroundModes"] as? [String], ["location"])
        let urlTypes = info["CFBundleURLTypes"] as? [[String: Any]]
        XCTAssertEqual(urlTypes?.first?["CFBundleURLSchemes"] as? [String], ["flocksurveillance"])
        XCTAssertNotNil(info["UILaunchScreen"])
    }

    func testVersionKeysComeFromBuildSettings() {
        let version = info["CFBundleShortVersionString"] as? String
        let build = info["CFBundleVersion"] as? String
        XCTAssertNotNil(version)
        XCTAssertNotNil(build)
        XCTAssertNotEqual(version, "1.0", "Info.plist must use $(MARKETING_VERSION), not xcodegen's default")
        XCTAssertNotEqual(build, "1", "Info.plist must use $(CURRENT_PROJECT_VERSION), not xcodegen's default")
        XCTAssertFalse(version?.contains("$(") ?? true)
    }
}
