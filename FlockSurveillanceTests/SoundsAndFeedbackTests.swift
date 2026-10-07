import AudioToolbox
import XCTest
@testable import FlockSurveillance

@MainActor
final class SoundsAndFeedbackTests: XCTestCase {
    private var savedSounds: Any?
    private var played: [SystemSoundID] = []

    override func setUp() async throws {
        try await super.setUp()
        savedSounds = UserDefaults.standard.object(forKey: AppPreferenceKey.soundsEnabled)
        played = []
        OverwatchAudio.soundSink = { [weak self] id in self?.played.append(id) }
        OverwatchAudio.resetCooldownsForTesting()
        BootBannerGate.resetForTesting()
    }

    override func tearDown() async throws {
        if let savedSounds {
            UserDefaults.standard.set(savedSounds, forKey: AppPreferenceKey.soundsEnabled)
        } else {
            UserDefaults.standard.removeObject(forKey: AppPreferenceKey.soundsEnabled)
        }
        OverwatchAudio.soundSink = { AudioServicesPlaySystemSound($0) }
        OverwatchAudio.resetCooldownsForTesting()
        BootBannerGate.resetForTesting()
        try await super.tearDown()
    }

    private func playEveryHelper() {
        OverwatchAudio.bootPing()
        OverwatchAudio.armClick()
        OverwatchAudio.zoneEnter()
        OverwatchAudio.zoneExit()
        OverwatchAudio.stingIfEnteringCritical(previous: .high, current: .critical)
    }

    // MARK: Boot banner

    func testBootBannerClaimsOncePerLaunch() {
        XCTAssertTrue(BootBannerGate.claim())
        XCTAssertFalse(BootBannerGate.claim())
        XCTAssertFalse(BootBannerGate.claim())
        BootBannerGate.resetForTesting()
        XCTAssertTrue(BootBannerGate.claim())
    }

    // MARK: Sounds gate

    func testSoundsDefaultToEnabledWhenUnset() {
        UserDefaults.standard.removeObject(forKey: AppPreferenceKey.soundsEnabled)
        XCTAssertTrue(AppPreferences.soundsEnabled)
    }

    func testSoundsDisabledSuppressesEverySound() {
        AppPreferences.soundsEnabled = false
        playEveryHelper()
        OverwatchAudio.play(1000)
        XCTAssertTrue(played.isEmpty, "No helper may bypass the central gate: \(played)")
    }

    func testSoundsEnabledPlaysEveryHelper() {
        AppPreferences.soundsEnabled = true
        playEveryHelper()
        for id: SystemSoundID in [1103, 1104, 1005, 1114, 1057] {
            XCTAssertTrue(played.contains(id), "Expected sound \(id) in \(played)")
        }
    }

    func testOnlyOverwatchAudioTouchesAudioServices() throws {
        for path in [
            "FlockSurveillance/Features/Map/MapRadarView.swift",
            "FlockSurveillance/Features/Map/CameraAnnotationView.swift",
            "FlockSurveillance/Features/Route/DriveModeView.swift",
            "FlockSurveillance/Services/DriveSession.swift",
            "FlockSurveillance/Features/Onboarding/OnboardingView.swift",
            "FlockSurveillance/Theme/OverwatchChrome.swift",
        ] {
            let src = try readSource(path)
            XCTAssertFalse(src.contains("AudioServicesPlaySystemSound"), "\(path) bypasses the Sounds gate")
        }
        let audio = try readSource("FlockSurveillance/Services/OverwatchAudio.swift")
        XCTAssertEqual(audio.components(separatedBy: "AudioServicesPlaySystemSound").count - 1, 1,
                       "Only the default soundSink may call AudioServices directly")
    }

    // MARK: One tap, one click, one haptic

    func testWatchToggleFiresFeedbackExactlyOnce() throws {
        let map = try readSource("FlockSurveillance/Features/Map/MapRadarView.swift")
        let start = try XCTUnwrap(map.range(of: "private func toggleWatchMode()"))
        let end = try XCTUnwrap(map.range(of: "private func startPulseIfNeeded"))
        let body = String(map[start.lowerBound..<end.lowerBound])
        XCTAssertEqual(body.components(separatedBy: "UIImpactFeedbackGenerator").count - 1, 1)
        XCTAssertEqual(body.components(separatedBy: "OverwatchAudio.armClick()").count - 1, 1)

        // No other armClick in the map, and the onChange handler must not repeat it.
        XCTAssertEqual(map.components(separatedBy: "OverwatchAudio.armClick()").count - 1, 1)

        let hud = try readSource("FlockSurveillance/Features/Map/CameraAnnotationView.swift")
        XCTAssertFalse(hud.contains("OverwatchAudio."), "RadarHUD must not play sounds; MapRadarView owns feedback")
        XCTAssertFalse(hud.contains("UIImpactFeedbackGenerator"), "RadarHUD must not duplicate haptics")
        XCTAssertFalse(hud.contains("UINotificationFeedbackGenerator"))
    }

    func testCriticalStingHasSingleOwnerInMapSurface() throws {
        let map = try readSource("FlockSurveillance/Features/Map/MapRadarView.swift")
        XCTAssertEqual(map.components(separatedBy: "stingIfEnteringCritical").count - 1, 1)
        let hud = try readSource("FlockSurveillance/Features/Map/CameraAnnotationView.swift")
        XCTAssertFalse(hud.contains("stingIfEnteringCritical"))
    }

    func testMapStaysMountedAcrossTabSwitches() throws {
        let root = try readSource("FlockSurveillance/App/RootTabView.swift")
        XCTAssertTrue(root.contains("mapMounted"))
        XCTAssertTrue(root.contains("selectedTab == 0 || mapMounted"))
    }

    private func readSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
