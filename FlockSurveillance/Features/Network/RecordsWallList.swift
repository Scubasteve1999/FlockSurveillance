import SwiftUI

/// Sheet root for the bundled records-wall list.
struct RecordsWallList: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            RecordsWallListContent()
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

/// Every bundled records-wall row, grouped by kind of status.
struct RecordsWallListContent: View {
    @State private var store = RecordsWallStatusStore()

    var body: some View {
        Group {
            if let dataset = store.dataset {
                list(dataset)
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
        .navigationTitle(RecordsWallStatusCopy.listTitle)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .task {
            await store.loadIfNeeded()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("records-wall-list")
    }

    private func list(_ dataset: RecordsWallDataset) -> some View {
        let model = RecordsWallListModel(dataset: dataset)
        return List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.banner)
                        .font(AppTypography.footer)
                        .foregroundStyle(AppTheme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("records-wall-banner")
                    Text(RecordsWallStatusCopy.footnote)
                        .font(AppTypography.footer)
                        .foregroundStyle(AppTheme.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("records-wall-footnote")
                }
            }
            .listRowBackground(AppTheme.card)

            ForEach(model.groups) { group in
                Section {
                    ForEach(group.records) { record in
                        NavigationLink {
                            RecordsWallRecordDetail(record: record)
                        } label: {
                            row(record)
                        }
                        .listRowBackground(AppTheme.card)
                        .accessibilityIdentifier("records-wall-row-\(record.id)")
                    }
                } header: {
                    Text(group.title)
                        .font(AppTypography.sectionEyebrow)
                        .foregroundStyle(AppTheme.mutedForeground)
                        .textCase(nil)
                }
            }

            Section {
                RecordsWallMetaBlock(meta: dataset.meta)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
    }

    private func row(_ record: RecordsWallRecord) -> some View {
        let title = RecordsWallStatusCopy.title(for: record)
        return VStack(alignment: .leading, spacing: 4) {
            Text(record.displayName)
                .font(AppTypography.rowTitle)
                .foregroundStyle(AppTheme.foreground)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(record.placeLine)
                .font(AppTypography.rowSubtitle)
                .foregroundStyle(AppTheme.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
            Text(title)
                .font(AppTypography.rowSubtitle)
                .foregroundStyle(AppTheme.foreground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.displayName), \(record.placeLine), \(title)")
    }
}

/// One bundled row with its card, always-on footnote, and cost footnote.
struct RecordsWallRecordDetail: View {
    let record: RecordsWallRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.displayName)
                        .font(AppTypography.pageTitle)
                        .foregroundStyle(AppTheme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(record.placeLine)
                        .font(AppTypography.pageSubtitle)
                        .foregroundStyle(AppTheme.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(record.displayName), \(record.placeLine)")

                RecordsWallChipCard(presentation: RecordsWallStatusCopy.chip(for: record))

                Text(RecordsWallStatusCopy.footnote)
                    .font(AppTypography.footer)
                    .foregroundStyle(AppTheme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.background)
        .navigationTitle(RecordsWallStatusCopy.listTitle)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("records-wall-detail")
    }
}
