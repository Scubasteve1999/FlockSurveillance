import SwiftUI

/// List of bundled retention-delta samples — public policy quotes vs a dated vendor pitch.
struct RetentionDeltaSamplesList: View {
    let store: RetentionDeltaStore

    @Environment(\.dismiss) private var dismiss
    @State private var selectedAgency: RetentionDeltaAgency?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(RetentionDeltaCopy.caption)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("retention-delta-list-caption")
                }
                .listRowBackground(AppTheme.card)

                Section {
                    incompletenessBanner
                }
                .listRowBackground(AppTheme.card)

                Section {
                    if let placeholder = RetentionDeltaCopy.listPlaceholder(totalAgencies: store.agencies.count) {
                        Text(placeholder)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground)
                            .accessibilityIdentifier("retention-delta-empty")
                    } else {
                        ForEach(store.agencies) { agency in
                            Button {
                                selectedAgency = agency
                            } label: {
                                agencyRow(agency)
                            }
                            .listRowBackground(AppTheme.card)
                            .accessibilityIdentifier("retention-delta-row-\(agency.id)")
                        }
                    }
                } header: {
                    Text("Bundled agencies")
                        .foregroundStyle(AppTheme.mutedForeground)
                }

                Section {
                    Text(RetentionDeltaCopy.notAffiliated)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.mutedForeground)
                }
                .listRowBackground(AppTheme.card)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle(RetentionDeltaCopy.samplesTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .sheet(item: $selectedAgency) { agency in
                RetentionDeltaCard(agency: agency)
                    .presentationDetents([.large])
                    .presentationBackground(AppTheme.background)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func agencyRow(_ agency: RetentionDeltaAgency) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(agency.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.foreground)
                    .multilineTextAlignment(.leading)
                Text(agency.regionLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
            }
            Spacer(minLength: 8)
            StatusBadge(
                text: rowBadge(agency.deltaLabel),
                color: badgeColor(agency.deltaLabel)
            )
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(agency.displayName), \(rowBadge(agency.deltaLabel))")
    }

    private var incompletenessBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT THIS LIST SHOWS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(AppTheme.mutedForeground)

            ForEach(Array(RetentionDeltaCopy.requiredBannerLines.enumerated()), id: \.offset) { index, line in
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
        .accessibilityIdentifier("retention-delta-list-honesty-banner")
        .accessibilityElement(children: .combine)
    }

    private func rowBadge(_ label: RetentionDeltaLabel) -> String {
        switch label {
        case .statedGtVendorPitch: return "Stated > pitch"
        case .statedEq: return "Stated = pitch"
        case .statuteOnly: return "Statute only"
        case .unknown: return "Unknown"
        case .conflict: return "Conflict"
        }
    }

    private func badgeColor(_ label: RetentionDeltaLabel) -> Color {
        switch label {
        case .conflict, .unknown: return AppTheme.mutedForeground
        case .statedGtVendorPitch, .statedEq, .statuteOnly: return AppTheme.accent
        }
    }

    private func bannerLetter(_ index: Int) -> String {
        let letters = ["A", "B", "C"]
        guard letters.indices.contains(index) else { return "·" }
        return letters[index]
    }
}

/// Honesty card for one agency's bundled retention quotes vs a dated vendor pitch.
///
/// Not configured days. Not a live vendor search. Not a plate-read claim.
struct RetentionDeltaCard: View {
    let agency: RetentionDeltaAgency

    @Environment(\.dismiss) private var dismiss

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

                if let reason = RetentionDeltaCopy.incompleteDisclaimer(for: agency) {
                    Section {
                        Text(reason)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("retention-delta-incomplete")
                    } header: {
                        Text("Snapshot limits")
                            .foregroundStyle(AppTheme.mutedForeground)
                    }
                    .listRowBackground(AppTheme.card)
                }

                Section {
                    chipRow
                } header: {
                    Text("Quoted windows")
                        .foregroundStyle(AppTheme.mutedForeground)
                }
                .listRowBackground(AppTheme.card)

                Section {
                    Text(
                        RetentionDeltaCopy.honestyLine(
                            for: agency.deltaLabel,
                            vendorDays: agency.vendorDefault.days
                        )
                    )
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("retention-delta-honesty-line")

                    if let notes = agency.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    Text("What the quotes say")
                        .foregroundStyle(AppTheme.mutedForeground)
                }
                .listRowBackground(AppTheme.card)

                if !agency.sourceChips.isEmpty {
                    Section {
                        ForEach(agency.sourceChips) { chip in
                            sourceRow(chip)
                        }
                    } header: {
                        Text("Dated sources")
                            .foregroundStyle(AppTheme.mutedForeground)
                    }
                    .listRowBackground(AppTheme.card)
                }

                Section {
                    Text(RetentionDeltaCopy.unknownNextTap)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("retention-delta-unknown-next")

                    Text(RetentionDeltaCopy.notAffiliated)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.mutedForeground)
                }
                .listRowBackground(AppTheme.card)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle(agency.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(agency.displayName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("retention-delta-title")

            Text(RetentionDeltaCopy.caption)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("retention-delta-caption")

            Text("\(agency.regionLabel) · \(RetentionDeltaCopy.asOfPrefix) \(agency.vendorDefault.asOf)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.foreground)
                .accessibilityIdentifier("retention-delta-as-of")
        }
        .padding(.vertical, 4)
    }

    private var incompletenessBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT THIS CARD SHOWS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(AppTheme.mutedForeground)

            ForEach(Array(RetentionDeltaCopy.requiredBannerLines.enumerated()), id: \.offset) { index, line in
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
        .accessibilityIdentifier("retention-delta-honesty-banner")
        .accessibilityElement(children: .combine)
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(agency.presentChipKinds, id: \.self) { kind in
                    StatusBadge(
                        text: agency.chipCaption(for: kind),
                        color: chipColor(kind)
                    )
                }
            }
        }
        .accessibilityIdentifier("retention-delta-chips")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(chipAccessibilityLabel)
    }

    private func sourceRow(_ chip: RetentionSourceChip) -> some View {
        Group {
            if let url = chip.link {
                Link(destination: url) {
                    sourceLabel(chip)
                }
                .accessibilityIdentifier("retention-delta-source-\(chip.id)")
            } else {
                sourceLabel(chip)
            }
        }
    }

    private func sourceLabel(_ chip: RetentionSourceChip) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(chip.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(chip.link == nil ? AppTheme.foreground : AppTheme.accent)
                    .multilineTextAlignment(.leading)
                Text("\(RetentionDeltaCopy.asOfPrefix) \(chip.asOfDate)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)
            }
            Spacer(minLength: 8)
            if chip.link != nil {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .padding(.vertical, 4)
    }

    private var chipAccessibilityLabel: String {
        agency.presentChipKinds.map { agency.chipCaption(for: $0) }.joined(separator: ", ")
    }

    /// Calm chips only — no coral / critical panic tint.
    private func chipColor(_ kind: RetentionChipKind) -> Color {
        switch kind {
        case .vendorDefault: return AppTheme.mutedForeground
        case .localPolicy: return AppTheme.accent
        case .statuteCap: return AppTheme.sharingBidirectional
        case .unknown: return AppTheme.mutedForeground
        }
    }

    private func bannerLetter(_ index: Int) -> String {
        let letters = ["A", "B", "C"]
        guard letters.indices.contains(index) else { return "·" }
        return letters[index]
    }
}
