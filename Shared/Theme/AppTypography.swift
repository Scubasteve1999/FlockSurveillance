import SwiftUI

/// Dynamic Type–friendly fonts for app chrome, sheets and rows. Shared with the widget target.
/// Use these (or `Font.system(_:design:weight:)`) instead of raw point sizes
/// for user-facing copy so Larger Content Size stays readable.
enum AppTypography {
    /// Mono page eyebrow — `FLOCK SURVEILLANCE · {TAB}` (~12pt at default).
    static let pageEyebrow = Font.system(.caption, design: .monospaced).weight(.black)
    /// Page title (~28pt at default, matches locked 28 `.black`).
    static let pageTitle = Font.title.weight(.black)
    /// Page subtitle (~15pt at default).
    static let pageSubtitle = Font.subheadline.weight(.medium)
    /// Sheet / detail title — county, partner agency (~22pt at default).
    static let sheetTitle = Font.title2.weight(.bold)

    /// Section eyebrows — PREFERENCES, ALERTS, ABOUT (~11pt at default).
    static let sectionEyebrow = Font.caption2.weight(.semibold)
    /// Tracked uppercase labels inside cards and map overlays — SHARING NETWORK, SOURCE,
    /// LINK TO … (~12pt at default). Not the mono coral `pageEyebrow`, and not a Settings
    /// list header (`sectionEyebrow`).
    static let eyebrow = Font.caption.weight(.bold)
    /// Row titles — toggles, list rows, tappable footer rows (~15pt at default).
    static let rowTitle = Font.subheadline.weight(.semibold)
    /// Row subtitles, status lines, row chevrons (~12pt at default).
    static let rowSubtitle = Font.caption.weight(.medium)
    /// Footer / about / honesty-adjacent body (~13pt at default).
    static let footer = Font.footnote.weight(.medium)
    /// CTA and inline button labels.
    static let button = Font.subheadline.weight(.semibold)

    /// MAP honesty chip + `DataSourcePill`.
    static let chip = Font.caption.weight(.medium)
    static let chipIcon = Font.caption.weight(.semibold)
    /// Filter chip titles — map filters (All ALPRs, Flock-branded pins, Traffic cams, Metros,
    /// Gates) and Sharing Network hub / breadcrumb chips.
    static let filterChip = Font.footnote.weight(.semibold)
    /// Compact mono HUD labels (boot banner).
    static let hudMono = Font.system(.caption, design: .monospaced).weight(.black)
    static let hudMonoSmall = Font.system(.caption2, design: .monospaced).weight(.bold)
    /// Radar HUD coverage instrument line.
    static let hudInstrument = Font.system(.caption, design: .monospaced).weight(.semibold)

    /// Density / status badges.
    static let badge = Font.caption2.weight(.semibold)
    /// Radar HUD headline.
    static let hudHeadline = Font.system(.headline, design: .rounded).weight(.black)
    /// Radar HUD nearest-distance metric.
    static let hudMetric = Font.system(.title2, design: .rounded).weight(.black)
    /// Stat numerals (contribution counts).
    static let statValue = Font.title3.weight(.bold)
}
