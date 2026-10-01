import SwiftUI

/// Official camera-map status for one agency. Own card, separate from sharing
/// access and retention quotes. Community pins stay on their own line.
struct OfficialMapStatusSurface: View {
    let agencyName: String
    let state: String

    @State private var store = OfficialMapStatusStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let dataset = store.dataset {
                banner(dataset)
                if let record = dataset.record(matchingAgencyName: agencyName, state: state) {
                    chipCard(OfficialMapStatusCopy.chip(for: record))
                } else {
                    unknownLine
                }
            } else if store.loadError != nil {
                unknownLine
            }

            Text(OfficialMapStatusCopy.footnote)
                .font(AppTypography.footer)
                .foregroundStyle(AppTheme.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("official-map-status-footnote")

            communityCard
        }
        .task {
            await store.loadIfNeeded()
        }
        .accessibilityIdentifier("official-map-status")
    }

    private func banner(_ dataset: OfficialMapDataset) -> some View {
        Text(
            OfficialMapStatusCopy.incompletenessBanner(
                agencyCount: dataset.records.count,
                datasetAsOf: dataset.datasetAsOf
            )
        )
        .font(AppTypography.footer)
        .foregroundStyle(AppTheme.mutedForeground)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("official-map-status-banner")
    }

    private var unknownLine: some View {
        Text(OfficialMapStatusCopy.unknownLine)
            .font(AppTypography.rowSubtitle)
            .foregroundStyle(AppTheme.mutedForeground)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("official-map-status-unknown")
    }

    private func chipCard(_ presentation: OfficialMapChipPresentation) -> some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(presentation.title)
                    .font(AppTypography.rowTitle)
                    .foregroundStyle(AppTheme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("official-map-status-title")

                if !presentation.subline.isEmpty {
                    Text(presentation.subline)
                        .font(AppTypography.footer)
                        .foregroundStyle(AppTheme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("official-map-status-subline")
                }

                if let updated = presentation.agencyUpdatedLine {
                    Text(updated)
                        .font(AppTypography.footer)
                        .foregroundStyle(AppTheme.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("official-map-status-agency-updated")
                }

                if let scope = presentation.scopeNote {
                    Text(scope)
                        .font(AppTypography.footer)
                        .foregroundStyle(AppTheme.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("official-map-status-scope")
                }

                if let sourceLine = presentation.sourceLine, let url = presentation.sourceURL {
                    Link(destination: url) {
                        Text(sourceLine)
                            .font(AppTypography.button)
                            .foregroundStyle(AppTheme.accent)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    .accessibilityIdentifier("official-map-status-source")
                }
            }
        }
        .accessibilityIdentifier("official-map-status-chip")
    }

    private var communityCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(OfficialMapStatusCopy.communityTitle)
                    .font(AppTypography.rowTitle)
                    .foregroundStyle(AppTheme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                Text(OfficialMapStatusCopy.communityBody)
                    .font(AppTypography.footer)
                    .foregroundStyle(AppTheme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("official-map-status-community")
    }
}
