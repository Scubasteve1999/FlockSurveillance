import SwiftUI
import UIKit
import XCTest
@testable import FlockSurveillance

final class PinDensityTests: XCTestCase {
    func testLabelsAreTheOneCalmLadder() {
        XCTAssertEqual(PinDensity.allCases.map(\.label), ["Clear", "Light", "Moderate", "Heavy", "Saturated"])
        XCTAssertEqual(Set(PinDensity.allCases.map(\.label)).count, PinDensity.allCases.count)
    }

    func testAreaThresholds() {
        for scale in [PinDensity.Scale.inView, .nearPlace] {
            let expected: [(Int, PinDensity)] = [
                (0, .clear), (1, .light), (4, .light), (5, .moderate), (14, .moderate),
                (15, .heavy), (29, .heavy), (30, .saturated), (500, .saturated)
            ]
            for (count, level) in expected {
                XCTAssertEqual(PinDensity(count: count, scale: scale), level, "count \(count)")
            }
        }
    }

    func testRouteThresholds() {
        let expected: [(Int, PinDensity)] = [
            (0, .clear), (1, .light), (3, .light), (4, .moderate), (9, .moderate),
            (10, .heavy), (19, .heavy), (20, .saturated), (200, .saturated)
        ]
        for (count, level) in expected {
            XCTAssertEqual(PinDensity(count: count, scale: .route), level, "count \(count)")
        }
    }

    func testEveryScaleIsMonotonic() {
        for scale in [PinDensity.Scale.inView, .nearPlace, .route] {
            XCTAssertEqual(PinDensity(count: -1, scale: scale), .clear)
            for count in 0..<200 {
                XCTAssertLessThanOrEqual(
                    PinDensity(count: count, scale: scale),
                    PinDensity(count: count + 1, scale: scale)
                )
            }
        }
    }

    /// A warning word is never green: cool colors only on Clear/Light, and from Moderate up
    /// each level is warm and hotter (less green) than the one below it.
    func testColorMatchesSeverityOrder() {
        for level in PinDensity.allCases {
            let rgb = level.rgb
            if level <= .light {
                XCTAssertGreaterThan(rgb.green, rgb.red, "\(level.label) should be a cool color")
            } else {
                XCTAssertGreaterThan(rgb.red, rgb.green, "\(level.label) should be a warm color")
            }
        }
        let warm = PinDensity.allCases.filter { $0 >= .moderate }
        for (lower, higher) in zip(warm, warm.dropFirst()) {
            XCTAssertLessThan(higher.rgb.green, lower.rgb.green, "\(higher.label) must read hotter than \(lower.label)")
        }
        let colors = PinDensity.allCases.map(\.rgb)
        for (i, a) in colors.enumerated() {
            for b in colors[(i + 1)...] {
                XCTAssertNotEqual(a, b, "each level gets its own color")
            }
        }
    }

    func testFillRisesWithLevel() {
        let fills = PinDensity.allCases.map(\.fill)
        for (lower, higher) in zip(fills, fills.dropFirst()) {
            XCTAssertGreaterThan(higher, lower)
        }
        XCTAssertEqual(fills.last, 1.0)
    }

    func testAppThemeTokensShareThePalette() {
        XCTAssertEqual(rgb(AppTheme.densityLow), PinDensity.clear.rgb)
        XCTAssertEqual(rgb(AppTheme.accent), PinDensity.light.rgb)
        XCTAssertEqual(rgb(AppTheme.densityMedium), PinDensity.moderate.rgb)
        XCTAssertEqual(rgb(AppTheme.densityHigh), PinDensity.heavy.rgb)
        XCTAssertEqual(rgb(AppTheme.critical), PinDensity.saturated.rgb)
        // Zone is proximity, not a density word — tinted with the Flock-pin coral.
        XCTAssertEqual(rgb(AppTheme.zoneTint), rgb(AppTheme.primary))
    }

    private func rgb(_ color: Color) -> PinDensity.RGB {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        func round(_ v: CGFloat) -> Double { (Double(v) * 100).rounded() / 100 }
        return PinDensity.RGB(red: round(r), green: round(g), blue: round(b))
    }
}
