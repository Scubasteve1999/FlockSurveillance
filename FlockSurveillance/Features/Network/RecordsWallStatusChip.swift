import SwiftUI

/// Portal, search detail, and records-request status for one agency. Separate
/// from the official camera-map card and from agency portal shares.
struct RecordsWallChipCard: View {
    let presentation: RecordsWallChipPresentation

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(presentation.title)
                    .font(AppTypography.rowTitle)
                    .foregroundStyle(AppTheme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("records-wall-title")

                VStack(alignment: .leading, spacing: 4) {
                    detailLine(presentation.portalLine)
                    detailLine(presentation.searchesLine)
                    detailLine(presentation.foiaLine)
                }
                .accessibilityIdentifier("records-wall-lines")

                if let note = presentation.costNote {
                    Text(note)
                        .font(AppTypography.footer)
                        .foregroundStyle(AppTheme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("records-wall-cost-note")
                }

                if let footnote = presentation.costFootnote {
                    Text(footnote)
                        .font(AppTypography.footer)
                        .foregroundStyle(AppTheme.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("records-wall-cost-footnote")
                }

                if let scope = presentation.scopeNote {
                    Text(scope)
                        .font(AppTypography.footer)
                        .foregroundStyle(AppTheme.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("records-wall-scope")
                }

                if let portal = presentation.portalURL {
                    linkRow("Open portal", url: portal, identifier: "records-wall-portal-link")
                }

                if let sourceLine = presentation.sourceLine, let url = presentation.sourceURL {
                    linkRow(sourceLine, url: url, identifier: "records-wall-source")
                }

                if let url = presentation.secondarySourceURL {
                    linkRow("Second source", url: url, identifier: "records-wall-source-secondary")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("records-wall-chip")
    }

    private func detailLine(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.footer)
            .foregroundStyle(AppTheme.foreground)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func linkRow(_ title: String, url: URL, identifier: String) -> some View {
        Link(destination: url) {
            Text(title)
                .font(AppTypography.button)
                .foregroundStyle(AppTheme.accent)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .accessibilityIdentifier(identifier)
    }
}

/// Texas-only aggregate strip and tracker footnote. Never a national rate.
struct RecordsWallMetaBlock: View {
    let meta: RecordsWallMeta?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let aggregate = meta?.texasAggregate {
                SectionCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(RecordsWallStatusCopy.texasAggregateLabel)
                            .font(AppTypography.sectionEyebrow)
                            .foregroundStyle(AppTheme.mutedForeground)
                        Text(RecordsWallStatusCopy.texasAggregateText(aggregate))
                            .font(AppTypography.footer)
                            .foregroundStyle(AppTheme.foreground)
                            .fixedSize(horizontal: false, vertical: true)
                        if let url = URL(string: aggregate.sourceURL), url.scheme?.lowercased() == "https" {
                            Link(destination: url) {
                                Text("Source · checked \(OfficialMapDateDisplay.render(aggregate.asOf).text)")
                                    .font(AppTypography.button)
                                    .foregroundStyle(AppTheme.accent)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("records-wall-texas-aggregate")
            }

            if let tracker = meta?.tracker {
                VStack(alignment: .leading, spacing: 4) {
                    Text(RecordsWallStatusCopy.trackerText(tracker))
                        .font(AppTypography.footer)
                        .foregroundStyle(AppTheme.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                    if let url = URL(string: tracker.url), url.scheme?.lowercased() == "https" {
                        Link(destination: url) {
                            Text("Open tracker")
                                .font(AppTypography.button)
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.cardPadding)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("records-wall-tracker")
            }
        }
    }
}
