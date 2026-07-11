import CoreLocation
import SwiftUI

/// Status sheet for a tracked OSM camera report (pending pin or contributions list).
struct PendingReportDetailSheet: View {
    let report: PendingReport
    var onCheckAgain: (() -> Void)?
    var onDismissPin: (() -> Void)?
    var onFocusMap: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(ReportStore.self) private var reportStore
    @State private var isChecking = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(report.kind.rawValue)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppTheme.foreground)

                    Text(report.statusSubtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.mutedForeground)

                    SectionCard {
                        VStack(alignment: .leading, spacing: 12) {
                            statusRow("Status", report.status.displayLabel)
                            statusRow(
                                "Submitted",
                                report.createdAt.formatted(date: .abbreviated, time: .shortened)
                            )
                            if let noteID = report.osmNoteID {
                                statusRow("OSM note", "#\(noteID)")
                            }
                            if let landed = report.landedCameraID {
                                statusRow("Mapped as", landed)
                            }
                            statusRow(
                                "Location",
                                String(format: "%.5f, %.5f", report.latitude, report.longitude)
                            )
                        }
                    }

                    if let url = report.osmNoteURL {
                        Link(destination: url) {
                            Label("Open note on OpenStreetMap", systemImage: "arrow.up.right.square")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(AppTheme.card.opacity(0.9))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                    if report.status == .open || report.status == .pending {
                        Button {
                            checkAgain()
                        } label: {
                            HStack {
                                if isChecking {
                                    ProgressView().tint(AppTheme.background)
                                }
                                Text(isChecking ? "Checking…" : "Check again")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(AppTheme.background)
                            .background(AppTheme.primary.opacity(isChecking ? 0.6 : 1))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isChecking)

                        if report.showsOnMap {
                            Button {
                                onDismissPin?()
                                reportStore.dismissFromMap(report)
                                dismiss()
                            } label: {
                                Text("Hide pending pin")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppTheme.mutedForeground)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let onFocusMap {
                        Button {
                            onFocusMap()
                            dismiss()
                        } label: {
                            Text("Show on map")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func statusRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.foreground)
                .multilineTextAlignment(.trailing)
        }
    }

    private func checkAgain() {
        isChecking = true
        onCheckAgain?()
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            isChecking = false
        }
    }
}
