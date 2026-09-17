import XCTest
@testable import FlockSurveillance

/// Locks P1.3 MAP + GEAR Dynamic Type: critical labels use text styles, not tiny point sizes.
final class DynamicTypeChromeTests: XCTestCase {
    func testAppTypographyTokensAreTextStylesNotPointSizes() throws {
        let theme = try readProductSource("FlockSurveillance/Theme/AppTheme.swift")
        XCTAssertTrue(theme.contains("enum AppTypography"))
        XCTAssertTrue(theme.contains("static let chip = Font.caption.weight(.medium)"))
        XCTAssertTrue(theme.contains("static let filterChip = Font.footnote.weight(.semibold)"))
        XCTAssertTrue(theme.contains("static let pageTitle = Font.title.weight(.black)"))
        XCTAssertTrue(theme.contains("static let pageEyebrow = Font.system(.caption, design: .monospaced).weight(.black)"))
        XCTAssertTrue(theme.contains("static let pageSubtitle = Font.subheadline.weight(.medium)"))
        XCTAssertTrue(theme.contains("static let sectionEyebrow = Font.caption2.weight(.semibold)"))
        XCTAssertTrue(theme.contains("static let rowTitle = Font.subheadline.weight(.semibold)"))
        XCTAssertTrue(theme.contains("static let rowSubtitle = Font.caption.weight(.medium)"))
        XCTAssertTrue(theme.contains("static let hudMono = Font.system(.caption, design: .monospaced).weight(.black)"))
        XCTAssertFalse(theme.contains("static let chip = Font.system(size:"))
        XCTAssertFalse(theme.contains("static let filterChip = Font.system(size:"))
        XCTAssertFalse(theme.contains("static let pageTitle = Font.system(size:"))
        XCTAssertFalse(theme.contains("static let sectionEyebrow = Font.system(size:"))
        XCTAssertFalse(theme.contains("static let rowTitle = Font.system(size:"))
    }

    func testHonestyChipUsesScalableChipStyleAndStillWraps() throws {
        let theme = try readProductSource("FlockSurveillance/Theme/AppTheme.swift")
        XCTAssertTrue(theme.contains("Text(MapHonestyCopy.chipLine)"))
        XCTAssertTrue(theme.contains(".font(AppTypography.chip)"))
        XCTAssertTrue(theme.contains(".font(AppTypography.chipIcon)"))
        XCTAssertTrue(theme.contains("fixedSize(horizontal: false, vertical: true)"))
        XCTAssertTrue(theme.contains("map-honesty-chip"))
        XCTAssertFalse(theme.contains(".font(.system(size: 11, weight: .medium))"))
        XCTAssertFalse(theme.contains(".font(.system(size: 10, weight: .semibold))"))
    }

    func testGearSettingsCriticalLabelsUseAppTypography() throws {
        let settings = try readProductSource("FlockSurveillance/Features/Settings/SettingsView.swift")
        XCTAssertTrue(settings.contains("AppIdentity.chromeEyebrow(\"GEAR\")"))
        XCTAssertTrue(settings.contains("AppTypography.sectionEyebrow"))
        XCTAssertTrue(settings.contains("AppTypography.rowTitle"))
        XCTAssertTrue(settings.contains("AppTypography.rowSubtitle"))
        XCTAssertTrue(settings.contains("AppTypography.footer"))
        XCTAssertFalse(settings.contains(".font(.system(size:"), "GEAR user-facing copy must not use raw point sizes.")
        XCTAssertTrue(settings.contains("fixedSize(horizontal: false, vertical: true)"))

        let tipJar = try readProductSource("FlockSurveillance/Features/Settings/TipJarSection.swift")
        XCTAssertTrue(tipJar.contains("AppTypography.sectionEyebrow"))
        XCTAssertTrue(tipJar.contains("AppTypography.footer"))
        XCTAssertFalse(tipJar.contains(".font(.system(size:"))
    }

    func testPageHeaderUsesScalableStyles() throws {
        let chrome = try readProductSource("FlockSurveillance/Theme/OverwatchChrome.swift")
        XCTAssertTrue(chrome.contains(".font(AppTypography.pageEyebrow)"))
        XCTAssertTrue(chrome.contains(".font(AppTypography.pageTitle)"))
        XCTAssertTrue(chrome.contains(".font(AppTypography.pageSubtitle)"))
        XCTAssertTrue(chrome.contains(".font(AppTypography.hudMono)"))
        XCTAssertFalse(chrome.contains(".font(.system(size:"))
        XCTAssertTrue(chrome.contains("AppIdentity.chromeMono"))
        XCTAssertTrue(chrome.contains("AppIdentity.displayName"))
    }

    func testMapFilterAndChipChromeUsesScalableStyles() throws {
        let map = try readProductSource("FlockSurveillance/Features/Map/MapRadarView.swift")
        XCTAssertTrue(map.contains("DataSourcePill()"))
        XCTAssertTrue(map.contains("Text(item.title)"))
        XCTAssertTrue(map.contains(".font(AppTypography.filterChip)"))
        XCTAssertTrue(map.contains(".font(AppTypography.hudMono)"))
        XCTAssertTrue(map.contains("OpenStreetMap pins tagged Flock-branded"))
        XCTAssertFalse(map.contains("\"Flock only\""))

        let textPointSizes = systemPointSizesOnText(in: map)
        XCTAssertTrue(
            textPointSizes.isEmpty,
            "MAP filter / chrome Text labels must not use .system(size:). Found: \(textPointSizes)"
        )

        // Icon-only tool rail stays compact but must keep VoiceOver labels.
        XCTAssertTrue(map.contains(".font(.system(size: 13, weight: .semibold))"))
        XCTAssertTrue(map.contains(".accessibilityLabel(label)"))
        XCTAssertTrue(map.contains("accessibilityLabel(\"AR Camera Sight\")") || map.contains("label: \"AR Camera Sight\""))
        XCTAssertTrue(map.contains("label: \"Report a pin\""))
    }

    func testRadarHUDCardUsesScalableStyles() throws {
        let hud = try readProductSource("FlockSurveillance/Features/Map/CameraAnnotationView.swift")
        XCTAssertTrue(hud.contains("DataSourcePill()"))
        XCTAssertTrue(hud.contains(".font(AppTypography.hudHeadline)"))
        XCTAssertTrue(hud.contains(".font(AppTypography.hudMetric)"))
        XCTAssertTrue(hud.contains(".font(AppTypography.hudInstrument)"))
        XCTAssertTrue(hud.contains(".font(AppTypography.rowSubtitle)"))
        XCTAssertFalse(hud.contains(".font(.system(size: 16, weight: .black, design: .rounded))"))
        XCTAssertFalse(hud.contains(".font(.system(size: 11, weight: .medium))"))
        XCTAssertFalse(hud.contains(".lineLimit(1)"))
    }

    func testHonestyCopyAndProductChromeUnchanged() {
        XCTAssertEqual(
            MapHonestyCopy.chipLine,
            "Not affiliated with Flock Safety · OSM / DeFlock community · Incomplete map."
        )
        XCTAssertEqual(CameraFilter.flockOnly.title, "Flock-branded pins")
        XCTAssertEqual(CameraFilter.all.title, "All ALPRs")
        XCTAssertEqual(AppIdentity.displayName, "Flock Surveillance")
        XCTAssertEqual(AppIdentity.chromeEyebrow("GEAR"), "FLOCK SURVEILLANCE · GEAR")
        XCTAssertEqual(AppIdentity.chromeEyebrow("MAP"), "FLOCK SURVEILLANCE · MAP")
        XCTAssertEqual(AppIdentity.urlScheme, "flocksurveillance")
        XCTAssertEqual(AppIdentity.appGroupID, "group.com.flocksurveillance.shared")
    }

    func testProjectYmlDoesNotBumpVersion() throws {
        let yaml = try readProductSource("project.yml")
        XCTAssertTrue(yaml.contains("MARKETING_VERSION: \"1.9.3\""))
        XCTAssertTrue(yaml.contains("CURRENT_PROJECT_VERSION: \"19\""))
        XCTAssertTrue(yaml.contains("iOS: \"17.0\""))
    }

    /// Point sizes applied to `Text` / `Label` within the next few modifier lines.
    private func systemPointSizesOnText(in source: String) -> [Int] {
        let lines = source.components(separatedBy: "\n")
        let regex = try! NSRegularExpression(pattern: #"\.font\(\.system\(size:\s*(\d+)"#)
        var sizes: [Int] = []
        for (index, line) in lines.enumerated() {
            let isCopy = line.contains("Text(") || line.contains("Label(")
            guard isCopy else { continue }
            let end = min(index + 5, lines.count - 1)
            let window = lines[index...end].joined(separator: "\n")
            let range = NSRange(window.startIndex..., in: window)
            for match in regex.matches(in: window, range: range) {
                guard let capture = Range(match.range(at: 1), in: window),
                      let size = Int(window[capture]) else { continue }
                sizes.append(size)
            }
        }
        return sizes
    }

    private func readProductSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
