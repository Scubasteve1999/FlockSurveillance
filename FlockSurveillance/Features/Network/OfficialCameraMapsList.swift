import SwiftUI

/// Sheet root for the bundled official camera-map list.
struct OfficialCameraMapsList: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            OfficialCameraMapsListContent()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                            .foregroundStyle(AppTheme.accent)
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}

/// Every bundled official-map record, grouped by status.
struct OfficialCameraMapsListContent: View {
    @State private var store = OfficialMapStatusStore()

    var body: some View {
        Group {
            if let dataset = store.dataset {
                list(OfficialMapStatusListModel(dataset: dataset))
            } else if let error = store.loadError {
                Text(error)
                    .font(AppTypography.footer)
                    .foregroundStyle(AppTheme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(AppTheme.cardPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(AppTheme.background)
            } else {
                ProgressView()
                    .tint(AppTheme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.background)
            }
        }
        .navigationTitle(OfficialMapStatusCopy.listTitle)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .task {
            await store.loadIfNeeded()
        }
        .accessibilityIdentifier("official-camera-maps-list")
    }

    private func list(_ model: OfficialMapStatusListModel) -> some View {
        List {
            Section {
                Text(model.banner)
                    .font(AppTypography.footer)
                    .foregroundStyle(AppTheme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("official-camera-maps-banner")
            }
            .listRowBackground(AppTheme.card)

            ForEach(model.groups) { group in
                section(group)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
    }

    @ViewBuilder
    private func section(_ group: OfficialMapStatusGroup) -> some View {
        if let title = group.title {
            Section {
                rows(group)
            } header: {
                Text(title)
                    .font(AppTypography.sectionEyebrow)
                    .foregroundStyle(AppTheme.mutedForeground)
                    .textCase(nil)
            }
        } else {
            Section {
                rows(group)
            }
        }
    }

    @ViewBuilder
    private func rows(_ group: OfficialMapStatusGroup) -> some View {
        ForEach(group.records) { record in
            NavigationLink {
                OfficialMapRecordDetail(record: record)
            } label: {
                row(record)
            }
            .listRowBackground(AppTheme.card)
            .accessibilityIdentifier("official-camera-map-row-\(record.id)")
        }
    }

    private func row(_ record: OfficialMapRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.agency)
                .font(AppTypography.rowTitle)
                .foregroundStyle(AppTheme.foreground)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(OfficialMapStatusListModel.placeLine(for: record))
                .font(AppTypography.rowSubtitle)
                .foregroundStyle(AppTheme.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
            Text(OfficialMapStatusListModel.rowTitle(for: record))
                .font(AppTypography.rowSubtitle)
                .foregroundStyle(AppTheme.foreground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: record))
    }

    private func accessibilityLabel(for record: OfficialMapRecord) -> String {
        let title = OfficialMapStatusListModel.rowTitle(for: record)
        return "\(record.agency), \(OfficialMapStatusListModel.placeLine(for: record)), \(title)"
    }
}

/// One bundled record. Reuses the official-map chip for scope, dates, and source.
struct OfficialMapRecordDetail: View {
    let record: OfficialMapRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.agency)
                        .font(AppTypography.pageTitle)
                        .foregroundStyle(AppTheme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(OfficialMapStatusListModel.placeLine(for: record))
                        .font(AppTypography.pageSubtitle)
                        .foregroundStyle(AppTheme.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(record.agency), \(OfficialMapStatusListModel.placeLine(for: record))")

                OfficialMapStatusChipCard(presentation: OfficialMapStatusCopy.chip(for: record))

                Text(OfficialMapStatusCopy.footnote)
                    .font(AppTypography.footer)
                    .foregroundStyle(AppTheme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.background)
        .navigationTitle(OfficialMapStatusCopy.listTitle)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("official-camera-map-detail")
    }
}
