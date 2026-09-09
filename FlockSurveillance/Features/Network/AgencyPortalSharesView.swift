import SwiftUI

/// Honesty card for one agency's bundled portal share list.
///
/// Shows organizations that agency has *listed* on a public transparency
/// portal — not everyone who can see a plate, and not a live vendor search.
struct AgencyPortalSharesCard: View {
    let agency: AgencyPortalShareAgency

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissSearch) private var dismissSearch
    @State private var query = ""
    @State private var selectedCategory: AgencyPortalShareCategory?

    private var filteredShares: [AgencyPortalShare] {
        agency.shares(matching: query, category: selectedCategory)
    }

    private var placeholder: String? {
        AgencyPortalSharesCopy.listPlaceholder(
            totalShares: agency.shares.count,
            filteredCount: filteredShares.count
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    headerBlock
                }
                .listRowBackground(AppTheme.card)

                Section {
                    incompletenessBanner
                }
                .listRowBackground(AppTheme.card)

                if let reason = AgencyPortalSharesCopy.incompleteDisclaimer(for: agency) {
                    Section {
                        Text(reason)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("portal-shares-ocr-disclaimer")
                    } header: {
                        Text("Snapshot limits")
                            .foregroundStyle(AppTheme.mutedForeground)
                    }
                    .listRowBackground(AppTheme.card)
                }

                if agency.presentCategories.contains(.federal) {
                    Section {
                        Text(AgencyPortalSharesCopy.federalExplainer)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("portal-shares-federal-explainer")
                    } header: {
                        Text("Federal access")
                            .foregroundStyle(AppTheme.mutedForeground)
                    }
                    .listRowBackground(AppTheme.card)
                }

                if !agency.presentCategories.isEmpty {
                    Section {
                        categoryChips
                    } header: {
                        Text("Listed categories")
                            .foregroundStyle(AppTheme.mutedForeground)
                    }
                    .listRowBackground(AppTheme.card)
                }

                Section {
                    if let placeholder {
                        Text(placeholder)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground)
                            .accessibilityIdentifier("portal-shares-empty")
                    } else {
                        ForEach(filteredShares) { share in
                            shareRow(share)
                                .listRowBackground(AppTheme.card)
                        }
                    }
                } header: {
                    Text(listHeader)
                        .foregroundStyle(AppTheme.mutedForeground)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle(agency.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Organization name")
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismissSearch()
                        KeyboardDismiss.resign()
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.accent)
                }
            }
            .onDisappear { KeyboardDismiss.resign() }
        }
        .preferredColorScheme(.dark)
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(agency.displayName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("portal-shares-title")

            Text(AgencyPortalSharesCopy.caption)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("portal-shares-caption")

            Text("\(AgencyPortalSharesCopy.asOfPrefix) \(agency.asOfDate)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.foreground)
                .accessibilityIdentifier("portal-shares-as-of")

            if let url = agency.sourceLink {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Text(agency.sourceTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .accessibilityIdentifier("portal-shares-source-link")
            }
        }
        .padding(.vertical, 4)
    }

    private var incompletenessBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT THIS CARD SHOWS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(AppTheme.mutedForeground)

            ForEach(Array(AgencyPortalSharesCopy.requiredBannerLines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .top, spacing: 8) {
                    Text(bannerLetter(index))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 16, alignment: .leading)
                    Text(line)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("portal-shares-honesty-banner")
        .accessibilityElement(children: .combine)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(
                    label: "All",
                    count: agency.shares.count,
                    selected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }
                ForEach(agency.presentCategories, id: \.self) { category in
                    let count = agency.shares.filter { $0.category == category }.count
                    categoryChip(
                        label: category.chipLabel,
                        count: count,
                        selected: selectedCategory == category
                    ) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
        }
        .accessibilityIdentifier("portal-shares-category-chips")
    }

    private func categoryChip(
        label: String,
        count: Int,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text("\(label) · \(count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? AppTheme.background : AppTheme.foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? AppTheme.accent : AppTheme.card.opacity(0.92))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.border, lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(count)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func shareRow(_ share: AgencyPortalShare) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(share.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.foreground)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            StatusBadge(text: share.category.chipLabel, color: chipColor(share.category))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(share.name), \(share.category.chipLabel)")
    }

    private var listHeader: String {
        if agency.shares.isEmpty {
            return "Listed shares"
        }
        let shown = filteredShares.count
        let total = agency.shares.count
        if shown == total {
            return "Listed shares · \(total)"
        }
        return "Listed shares · \(shown) of \(total)"
    }

    private func bannerLetter(_ index: Int) -> String {
        let letters = ["A", "B", "C"]
        guard letters.indices.contains(index) else { return "·" }
        return letters[index]
    }

    /// Calm chips only — no coral / critical federal panic tint.
    private func chipColor(_ category: AgencyPortalShareCategory) -> Color {
        switch category {
        case .localLE: return AppTheme.accent
        case .outOfStateLE: return AppTheme.sharingBidirectional
        case .federal, .private, .unknown: return AppTheme.mutedForeground
        }
    }
}
