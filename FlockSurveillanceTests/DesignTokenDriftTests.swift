import XCTest

/// Audit #10: design-system drift. Colors and type come from the shared tokens
/// (`Shared/Theme`), not hand-copied RGB or fixed point sizes.
final class DesignTokenDriftTests: XCTestCase {
    /// Literal colors: `Color` / `UIColor` built from components — red/green/blue in any color
    /// space (`Color(.displayP3, red:)`), hue/saturation/brightness, or white.
    private static let colorLiteralPattern =
        #"\b(Color|UIColor)\(\s*(\.[A-Za-z0-9]+\s*,\s*)?(red|hue|white|displayP3Red):"#
    /// Fixed point-size fonts: `.system(size:)` (with or without `Font.`), `.custom(_, size:)`,
    /// and `UIFont.systemFont(ofSize:)`.
    private static let fixedPointFontPattern =
        #"\.system\(\s*size:|\.custom\([^)]*size:|UIFont\.systemFont\(\s*ofSize:"#
    /// Magic corner radii: a numeric literal instead of `AppTheme.cornerRadius` / `buttonCornerRadius`.
    private static let magicRadiusPattern = #"cornerRadius:\s*[0-9]|\.cornerRadius\(\s*[0-9]"#

    private static func hits(_ pattern: String, in source: String) throws -> [Int] {
        let regex = try NSRegularExpression(pattern: pattern)
        let lines = source.components(separatedBy: "\n")
        return lines.enumerated().compactMap { index, line in
            regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) == nil ? nil : index + 1
        }
    }

    func testWidgetAndLiveActivityHaveNoColorLiterals() throws {
        // Positive control: every literal-color form is caught; tokens, density and system colors pass.
        let sample = """
        .foregroundStyle(Color(red: 1.0, green: 0.32, blue: 0.22))
        .activityBackgroundTint(Color(.sRGB, red: 0.03, green: 0.035, blue: 0.05))
        .foregroundStyle(Color(.displayP3, red: 1, green: 0.3, blue: 0.2))
        .foregroundStyle(Color(hue: 0.5, saturation: 0.8, brightness: 0.9))
        .background(Color(white: 0.1))
        .tint(Color(UIColor(red: 1, green: 0, blue: 0, alpha: 1)))
        .foregroundStyle(AppTheme.primary)
        .foregroundStyle(density.color)
        .foregroundStyle(.white.opacity(0.65))
        .containerBackground(for: .widget) { Color.clear }
        """
        XCTAssertEqual(try Self.hits(Self.colorLiteralPattern, in: sample), [1, 2, 3, 4, 5, 6])

        let root = Self.repoRoot
        let base = root.appendingPathComponent("NearbyCamerasWidget")
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil))
        var scanned: [String] = []
        var found: [String] = []
        for file in enumerator.compactMap({ $0 as? URL }) where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            scanned.append(file.lastPathComponent)
            found += try Self.hits(Self.colorLiteralPattern, in: source).map { "\(file.lastPathComponent):\($0)" }
        }
        XCTAssertTrue(scanned.contains("NearbyCamerasWidget.swift"))
        XCTAssertTrue(scanned.contains("DriveLiveActivityWidget.swift"))
        XCTAssertTrue(found.isEmpty, "Hand-copied RGB in the widget — use AppTheme:\n" + found.joined(separator: "\n"))

        let widget = try readProductSource("NearbyCamerasWidget/NearbyCamerasWidget.swift")
        XCTAssertTrue(widget.contains("AppTheme.primary"))
        XCTAssertTrue(widget.contains("AppTheme.accent"))
        XCTAssertTrue(widget.contains("AppTheme.background"))
        let activity = try readProductSource("NearbyCamerasWidget/DriveLiveActivityWidget.swift")
        XCTAssertTrue(activity.contains("AppTheme.primary"))
        XCTAssertTrue(activity.contains("AppTheme.accent"))
        XCTAssertTrue(activity.contains(".activityBackgroundTint(AppTheme.background)"))
    }

    func testSharingNetworkHasNoFixedPointFonts() throws {
        // Positive control: every fixed-size form is caught; roles and text-style fonts pass.
        let sample = """
        .font(.system(size: 13, weight: .bold))
        .font(AppTypography.rowTitle)
        static let hudMono = Font.system(.caption, design: .monospaced).weight(.black)
        .font( .system( size: 22 ))
        .font(Font.system(size: 13))
        .font(.custom("Menlo", size: 12))
        let label = UIFont.systemFont(ofSize: 12)
        .font(.custom("Menlo", size: 12, relativeTo: .caption))
        """
        XCTAssertEqual(try Self.hits(Self.fixedPointFontPattern, in: sample), [1, 4, 5, 6, 7, 8])

        let sharing = try readProductSource("FlockSurveillance/Features/Network/SharingNetworkView.swift")
        let found = try Self.hits(Self.fixedPointFontPattern, in: sharing)
        XCTAssertTrue(found.isEmpty, "SharingNetworkView fixed point sizes on lines \(found) — use AppTypography")

        // The four footer rows share one style.
        for row in ["officialMapsRow", "recordsWallRow", "midSouthSamplesRow", "retentionSamplesRow"] {
            let body = try XCTUnwrap(Self.declaration("private var \(row): some View", in: sharing), row)
            XCTAssertTrue(body.contains(".font(AppTypography.rowTitle)"), row)
            XCTAssertTrue(body.contains(".font(AppTypography.rowSubtitle)"), row)
            XCTAssertTrue(body.contains(".fixedSize(horizontal: false, vertical: true)"), row)
        }
        // Hub and breadcrumb chips use the shared chip style, not a hand-rolled capsule.
        XCTAssertNotNil(sharing.range(of: #"Text\(hub\.shortName\)\s*\.filterChipStyle\("#, options: .regularExpression))
        XCTAssertNotNil(sharing.range(of: #"Text\(title\)\s*\.filterChipStyle\(isOn: false\)"#, options: .regularExpression))
        XCTAssertFalse(sharing.contains(".clipShape(Capsule())"), "Chips come from FilterChipStyle")
        XCTAssertTrue(sharing.contains(".font(AppTypography.sheetTitle)"))
        XCTAssertTrue(sharing.contains(".font(AppTypography.eyebrow)"))
    }

    /// Sharing Network text follows Dynamic Type, so the chrome must stay reachable at large sizes:
    /// the pinned footer scrolls inside a height cap, the overlay can't scroll so it stops at AX2,
    /// and icon buttons scale their circle with the glyph.
    func testSharingNetworkChromeStaysReachableAtLargeText() throws {
        let sharing = try readProductSource("FlockSurveillance/Features/Network/SharingNetworkView.swift")
        let footer = try XCTUnwrap(Self.declaration("private func footer(maxHeight: CGFloat) -> some View", in: sharing))
        XCTAssertTrue(footer.contains("HeightCap(maxHeight: maxHeight)"))
        XCTAssertTrue(footer.contains("ViewThatFits(in: .vertical)"))
        XCTAssertTrue(footer.contains("ScrollView {"))
        XCTAssertTrue(sharing.contains("footer(maxHeight: geo.size.height * 0.45)"))
        XCTAssertTrue(sharing.contains(".dynamicTypeSize(...DynamicTypeSize.accessibility2)"))
        XCTAssertTrue(sharing.contains("@ScaledMetric(relativeTo: .subheadline) private var diameter: CGFloat = 40"))
        XCTAssertFalse(sharing.contains(".frame(width: 40, height: 40)"), "Fixed icon circles clip scaled glyphs")
    }

    func testThemeTokensLiveInShared() throws {
        let tokens = try readProductSource("Shared/Theme/AppThemeTokens.swift")
        XCTAssertTrue(tokens.contains("enum AppTheme {"))
        XCTAssertTrue(tokens.contains("static let buttonCornerRadius: CGFloat = 12"))
        let typography = try readProductSource("Shared/Theme/AppTypography.swift")
        XCTAssertTrue(typography.contains("enum AppTypography {"))

        let components = try readProductSource("FlockSurveillance/Theme/AppTheme.swift")
        XCTAssertFalse(components.contains("enum AppTheme {"), "AppTheme is defined once, in Shared/Theme")
        XCTAssertFalse(components.contains("enum AppTypography {"), "AppTypography is defined once, in Shared/Theme")

        // project.yml compiles Shared into both the app and the widget extension.
        let yaml = try readProductSource("project.yml")
        let sharedSource = try NSRegularExpression(pattern: #"^\s*-\s*path:\s*Shared\s*$"#, options: .anchorsMatchLines)
        for target in ["FlockSurveillance", "NearbyCamerasWidgetExtension"] {
            let block = try XCTUnwrap(Self.targetBlock(target, in: yaml), "target \(target) in project.yml")
            XCTAssertNotNil(
                sharedSource.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
                "\(target) must compile Shared/ (the shared theme tokens live there)"
            )
        }
    }

    func testCTAsUseButtonCornerRadius() throws {
        // Positive control: literal radii in any spelling are caught; tokens pass.
        let sample = """
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        RoundedRectangle(cornerRadius:12.0)
        .cornerRadius(14)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        """
        XCTAssertEqual(try Self.hits(Self.magicRadiusPattern, in: sample), [1, 2, 3])

        for file in [
            "FlockSurveillance/Features/Onboarding/OnboardingView.swift",
            "FlockSurveillance/Features/Map/ReportCameraSheet.swift"
        ] {
            let source = try readProductSource(file)
            let found = try Self.hits(Self.magicRadiusPattern, in: source)
            XCTAssertTrue(found.isEmpty, "\(file): magic radii on lines \(found) — use AppTheme radius tokens")
            XCTAssertTrue(source.contains("AppTheme.buttonCornerRadius"), file)
        }
    }

    /// Text of a `var`/`func` from its declaration line to the next `private` member.
    private static func declaration(_ signature: String, in source: String) -> String? {
        guard let start = source.range(of: signature) else { return nil }
        let rest = source[start.upperBound...]
        let end = rest.range(of: "\n    private ")?.lowerBound ?? rest.endIndex
        return String(rest[..<end])
    }

    /// A `targets:` entry of project.yml, from its two-space-indented name to the next
    /// top-level target or section.
    private static func targetBlock(_ name: String, in yaml: String) -> String? {
        guard let start = yaml.range(of: "\n  \(name):\n") else { return nil }
        let rest = yaml[start.upperBound...]
        let next = rest.range(of: #"\n(  [A-Za-z][^\n]*:|[A-Za-z][^\n]*:)\n"#, options: .regularExpression)
        return String(rest[..<(next?.lowerBound ?? rest.endIndex)])
    }

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private func readProductSource(_ relativePath: String) throws -> String {
        try String(contentsOf: Self.repoRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
