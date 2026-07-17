import CoreLocation
import XCTest
@testable import FlockSurveillance

/// Writes a Place Score share PNG for App Store framing when `ASO_EXPORT_DIR` is set.
@MainActor
final class ShareCardASOExportTests: XCTestCase {
    func testExportPlaceScoreShareCardForASO() throws {
        // Prefer TEST_RUNNER_ASO_EXPORT_DIR (forwarded into the simulator test host).
        // Fallback: repo docs path relative to this source file.
        let dir: String = {
            if let env = ProcessInfo.processInfo.environment["ASO_EXPORT_DIR"], !env.isEmpty {
                return env
            }
            return URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("docs/aso-captures/raw")
                .path
        }()

        let score = PlaceScore(
            coordinate: CLLocationCoordinate2D(latitude: 43.0731, longitude: -89.4012),
            radiusMeters: 1609.34,
            cameraCount: 9,
            flockCount: 9,
            flockPercent: 100,
            densityPerSquareMile: 2.9,
            grade: "Watched"
        )
        guard let image = ShareCardRenderer.placeScoreImage(score) else {
            XCTFail("ShareCardRenderer returned nil")
            return
        }
        guard let data = image.pngData() else {
            XCTFail("Could not encode PNG")
            return
        }

        let url = URL(fileURLWithPath: dir, isDirectory: true)
            .appendingPathComponent("04-share-card.png")
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: dir, isDirectory: true),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
}
