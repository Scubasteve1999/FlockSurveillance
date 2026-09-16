import XCTest

/// Locks the ASC/TF privacy manifests to the audited Required Reason API
/// and location nutrition label. Location is on-device only; not tracking.
final class PrivacyManifestTests: XCTestCase {
    func testAppManifestDeclaresUserDefaultsAndLocationWithoutTracking() throws {
        let plist = try loadPlist("FlockSurveillance/PrivacyInfo.xcprivacy")

        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
        let domains = try XCTUnwrap(plist["NSPrivacyTrackingDomains"] as? [Any])
        XCTAssertTrue(domains.isEmpty)

        let apiTypes = try XCTUnwrap(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        XCTAssertEqual(apiTypes.count, 1)
        XCTAssertEqual(apiTypes[0]["NSPrivacyAccessedAPIType"] as? String, "NSPrivacyAccessedAPICategoryUserDefaults")
        XCTAssertEqual(apiTypes[0]["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"])

        let collected = try XCTUnwrap(plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        let types = Set(collected.compactMap { $0["NSPrivacyCollectedDataType"] as? String })
        XCTAssertEqual(types, [
            "NSPrivacyCollectedDataTypePreciseLocation",
            "NSPrivacyCollectedDataTypeCoarseLocation"
        ])

        for entry in collected {
            XCTAssertEqual(entry["NSPrivacyCollectedDataTypeLinked"] as? Bool, false)
            XCTAssertEqual(entry["NSPrivacyCollectedDataTypeTracking"] as? Bool, false)
            XCTAssertEqual(
                entry["NSPrivacyCollectedDataTypePurposes"] as? [String],
                ["NSPrivacyCollectedDataTypePurposeAppFunctionality"]
            )
        }
    }

    func testWidgetManifestDeclaresAppGroupUserDefaultsWithoutLocation() throws {
        let plist = try loadPlist("NearbyCamerasWidget/PrivacyInfo.xcprivacy")

        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
        let collected = try XCTUnwrap(plist["NSPrivacyCollectedDataTypes"] as? [Any])
        XCTAssertTrue(collected.isEmpty, "Widget does not call CLLocationManager; location stays app-only")

        let apiTypes = try XCTUnwrap(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        XCTAssertEqual(apiTypes.count, 1)
        XCTAssertEqual(apiTypes[0]["NSPrivacyAccessedAPIType"] as? String, "NSPrivacyAccessedAPICategoryUserDefaults")
        XCTAssertEqual(apiTypes[0]["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"])
    }

    func testAppBundleCopiesPrivacyManifest() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
            "PrivacyInfo.xcprivacy must be in Copy Bundle Resources for FlockSurveillance"
        )
        let data = try Data(contentsOf: url)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        )
        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
    }

    func testProjectMembershipWiresManifestsIntoAppAndWidget() throws {
        let pbx = try String(contentsOf: repoFile("FlockSurveillance.xcodeproj/project.pbxproj"), encoding: .utf8)
        XCTAssertTrue(pbx.contains("PrivacyInfo.xcprivacy in Resources"))
        XCTAssertTrue(pbx.contains("PrivacyManifestTests.swift"))
        XCTAssertTrue(
            pbx.contains("FlockSurveillance/PrivacyInfo.xcprivacy") || pbx.contains("path = PrivacyInfo.xcprivacy"),
            "xcodegen/pbxproj must copy PrivacyInfo.xcprivacy into target bundles"
        )
    }

    func testProjectYmlWiresPrivacyInfoResourcesWithoutVersionBump() throws {
        let yaml = try String(contentsOf: repoFile("project.yml"), encoding: .utf8)
        XCTAssertTrue(yaml.contains("MARKETING_VERSION: \"1.9.3\""))
        XCTAssertTrue(yaml.contains("CURRENT_PROJECT_VERSION: \"19\""))
        XCTAssertTrue(yaml.contains("FlockSurveillance/PrivacyInfo.xcprivacy"))
        XCTAssertTrue(yaml.contains("NearbyCamerasWidget/PrivacyInfo.xcprivacy"))
        XCTAssertTrue(yaml.contains("iOS: \"17.0\""))
        XCTAssertTrue(yaml.contains("xcodeVersion: \"16.0\""))
    }

    private func loadPlist(_ relativePath: String) throws -> [String: Any] {
        let data = try Data(contentsOf: repoFile(relativePath))
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try XCTUnwrap(plist as? [String: Any])
    }

    private func repoFile(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
    }
}
