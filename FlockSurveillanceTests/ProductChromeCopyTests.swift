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

    func testMapWatchToggleUsesCalmPinPulseLabel() throws {
        let hud = try readProductSource("FlockSurveillance/Features/Map/CameraAnnotationView.swift")
        XCTAssertTrue(hud.contains(".accessibilityLabel(\"Pin pulse\")"))
        XCTAssertTrue(hud.contains(".accessibilityHint(\"Pulses nearby mapped pins on the map.\")"))
        XCTAssertFalse(hud.contains("overwatch mode"))
        XCTAssertFalse(hud.contains("OVERWATCH ·"))
    }

    // MARK: - Banned spy / threat framing

    /// Calm, factual copy only: the app knows phone GPS near mapped OSM pins, nothing more.
    /// Case-insensitive, word-boundary.
    private static let bannedFramingPattern =
        #"(?i)\b(overwatch|watchedness|watched|threat|classified|dossier|hot zone|safest|radar|tracker|speed camera|arm|scan|lock)\b"#

    /// Exact literals allowed to contain a banned word. Justify every entry.
    private static let bannedFramingAllowlist: [(file: String, literal: String)] = [
        // Accessibility identifier for UI tests; never displayed or spoken by VoiceOver.
        ("FlockSurveillance/Features/Network/RecordsWallStatusChip.swift", "records-wall-tracker")
    ]

    /// Proper nouns stripped (case-sensitive) before matching.
    private static let bannedFramingAllowedPhrases = [
        // Apple's name for the iOS system surface where Live Activities appear.
        "Lock Screen"
    ]

    func testNoBannedFramingInSwiftStringLiterals() throws {
        let regex = try NSRegularExpression(pattern: Self.bannedFramingPattern)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        var hits: [String] = []
        var scannedFiles = 0

        for directory in ["FlockSurveillance", "NearbyCamerasWidget", "Shared"] {
            let base = root.appendingPathComponent(directory)
            let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil))
            let files = enumerator.compactMap { $0 as? URL }
                .filter { $0.pathExtension == "swift" }
                .sorted { $0.path < $1.path }
            for file in files {
                scannedFiles += 1
                let relative = String(file.path.dropFirst(root.path.count + 1))
                let source = try String(contentsOf: file, encoding: .utf8)
                for literal in Self.stringLiterals(in: source) {
                    if Self.bannedFramingAllowlist.contains(where: { $0.file == relative && $0.literal == literal.text }) {
                        continue
                    }
                    let text = Self.bannedFramingAllowedPhrases.reduce(literal.text) {
                        $0.replacingOccurrences(of: $1, with: " ")
                    }
                    let range = NSRange(text.startIndex..., in: text)
                    guard let match = regex.firstMatch(in: text, range: range),
                          let wordRange = Range(match.range, in: text)
                    else { continue }
                    hits.append("\(relative):\(literal.line): \"\(text[wordRange])\" in \"\(literal.text.prefix(90))\"")
                }
            }
        }

        XCTAssertGreaterThan(scannedFiles, 50, "Source walk found too few files — check repo-relative paths")
        XCTAssertTrue(
            hits.isEmpty,
            "Banned spy/threat framing in string literals (reword, or allowlist with a reason):\n"
                + hits.joined(separator: "\n")
        )
    }

    func testBannedFramingScannerFindsLiteralsAndSkipsCode() {
        let sample = """
        // Overwatch in a comment is fine
        let mode = OverwatchMode() /* threat in block comment */
        Text("THREAT BOARD")
        Text("Pins: \\(isOn ? "Radar on" : "off") nearby")
        let multi = \"\"\"
            calm line
            CLASSIFIED line
            \"\"\"
        """
        let literals = Self.stringLiterals(in: sample)
        XCTAssertEqual(literals.map(\.text), ["THREAT BOARD", "Radar on", "off", "Pins:   nearby", "    calm line\n    CLASSIFIED line\n    "])
        XCTAssertEqual(literals.first?.line, 3)
        XCTAssertEqual(literals.first { $0.text == "Radar on" }?.line, 4)
        XCTAssertFalse(literals.contains { $0.text.contains("Overwatch") || $0.text.contains("threat in") })
    }

    // MARK: - One density scale

    /// Words from the retired ladders: AppTheme (Low / Dense), Place Score ("Mapped" as a grade),
    /// Route ("Elevated") and the map chip (LOW / MOD / DENSE / ZONE and its "… PINS" titles).
    /// `PinDensity` is the only scale; "PIN ZONE" is proximity copy and stays allowed.
    private static let retiredDensityLiterals: Set<String> = [
        "Elevated", "Mapped", "MAPPED", "Low", "Dense",
        "LOW", "MOD", "DENSE", "ZONE",
        "CLEAR PINS", "LOW PINS", "MODERATE PINS", "DENSE PINS"
    ]

    private static func retiredDensityHits(in source: String) throws -> [String] {
        let elevated = try NSRegularExpression(pattern: #"(?i)\belevated\b"#)
        return stringLiterals(in: source).compactMap { literal in
            let text = literal.text.trimmingCharacters(in: .whitespaces)
            let range = NSRange(text.startIndex..., in: text)
            if retiredDensityLiterals.contains(text) || elevated.firstMatch(in: text, range: range) != nil {
                return "\(literal.line): \"\(text)\""
            }
            return nil
        }
    }

    func testRetiredDensityLabelsAreGone() throws {
        // The scanner itself must catch the old ladders and pass the current one.
        let sample = """
        case 4...9: return "Elevated"
        StatusBadge(text: "MOD", color: c)
        Text("PIN ZONE"); Text("Moderate"); Text("Mapped OSM pins")
        """
        XCTAssertEqual(try Self.retiredDensityHits(in: sample).count, 2)

        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        var hits: [String] = []
        for directory in ["FlockSurveillance", "NearbyCamerasWidget", "Shared"] {
            let base = root.appendingPathComponent(directory)
            let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil))
            for file in enumerator.compactMap({ $0 as? URL }) where file.pathExtension == "swift" {
                let relative = String(file.path.dropFirst(root.path.count + 1))
                let source = try String(contentsOf: file, encoding: .utf8)
                hits += try Self.retiredDensityHits(in: source).map { "\(relative):\($0)" }
                XCTAssertFalse(source.contains("AppTheme.densityLabel"), relative)
                XCTAssertFalse(source.contains("AppTheme.densityColor"), relative)
            }
        }
        XCTAssertTrue(hits.isEmpty, "Retired density labels — use PinDensity:\n" + hits.joined(separator: "\n"))

        // SurveillanceLevel is internal intensity only: no words, no colors.
        let level = try readProductSource("FlockSurveillance/Services/SurveillanceLevel.swift")
        XCTAssertTrue(Self.stringLiterals(in: level).isEmpty, "SurveillanceLevel must not carry user-facing copy")
        XCTAssertFalse(level.contains("var chip"))
        XCTAssertFalse(level.contains("var title"))
        XCTAssertFalse(level.contains("var color"))
    }

    private struct SourceLiteral {
        let line: Int
        let text: String
    }

    /// Minimal Swift lexer: string literals (single- and multi-line) outside comments, recursing
    /// into `\( … )` interpolations so nested literals are scanned and interpolated code is not.
    private static func stringLiterals(in source: String) -> [SourceLiteral] {
        let bytes = Array(source.utf8)
        var index = 0
        var line = 1
        var literals: [SourceLiteral] = []
        scanCode(bytes, &index, &line, &literals, untilCloseParen: false)
        return literals
    }

    private static func scanCode(
        _ b: [UInt8], _ i: inout Int, _ line: inout Int, _ out: inout [SourceLiteral], untilCloseParen: Bool
    ) {
        var depth = 0
        while i < b.count {
            let c = b[i]
            let next: UInt8 = i + 1 < b.count ? b[i + 1] : 0
            if c == UInt8(ascii: "\n") {
                line += 1
            } else if c == UInt8(ascii: "/"), next == UInt8(ascii: "/") {
                while i < b.count, b[i] != UInt8(ascii: "\n") { i += 1 }
                continue
            } else if c == UInt8(ascii: "/"), next == UInt8(ascii: "*") {
                i += 2
                while i + 1 < b.count, !(b[i] == UInt8(ascii: "*") && b[i + 1] == UInt8(ascii: "/")) {
                    if b[i] == UInt8(ascii: "\n") { line += 1 }
                    i += 1
                }
                i += 2
                continue
            } else if c == UInt8(ascii: "\"") {
                scanLiteral(b, &i, &line, &out)
                continue
            } else if untilCloseParen, c == UInt8(ascii: "(") {
                depth += 1
            } else if untilCloseParen, c == UInt8(ascii: ")") {
                if depth == 0 {
                    i += 1
                    return
                }
                depth -= 1
            }
            i += 1
        }
    }

    private static func scanLiteral(_ b: [UInt8], _ i: inout Int, _ line: inout Int, _ out: inout [SourceLiteral]) {
        let quote = UInt8(ascii: "\"")
        let multiline = i + 2 < b.count && b[i + 1] == quote && b[i + 2] == quote
        let startLine = line
        i += multiline ? 3 : 1
        if multiline, i < b.count, b[i] == UInt8(ascii: "\n") {
            line += 1
            i += 1
        }
        var text: [UInt8] = []
        while i < b.count {
            let c = b[i]
            if c == UInt8(ascii: "\\"), i + 1 < b.count {
                let escaped = b[i + 1]
                i += 2
                if escaped == UInt8(ascii: "(") {
                    scanCode(b, &i, &line, &out, untilCloseParen: true)
                    text.append(UInt8(ascii: " "))
                } else if [UInt8(ascii: "n"), UInt8(ascii: "t"), UInt8(ascii: "r")].contains(escaped) {
                    text.append(UInt8(ascii: " "))
                } else {
                    if escaped == UInt8(ascii: "\n") { line += 1 }
                    text.append(escaped)
                }
                continue
            }
            if multiline {
                if c == quote, i + 2 < b.count, b[i + 1] == quote, b[i + 2] == quote {
                    i += 3
                    break
                }
            } else if c == quote || c == UInt8(ascii: "\n") {
                if c == quote { i += 1 }
                break
            }
            if c == UInt8(ascii: "\n") { line += 1 }
            text.append(c)
            i += 1
        }
        out.append(SourceLiteral(line: startLine, text: String(decoding: text, as: UTF8.self)))
    }

    private func readProductSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
