import CoreLocation
import SwiftUI

struct ReportCameraSheet: View {
    let coordinate: CLLocationCoordinate2D
    var existingCameraID: String?
    var initialKind: OSMReportKind = .newCamera

    @Environment(\.dismiss) private var dismiss

    @State private var kind: OSMReportKind
    @State private var direction = ""
    @State private var mountType = ""
    @State private var operatorGuess = ""
    @State private var notes = ""
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var didSubmit = false

    private let directions = ["", "N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    private let mounts = ["", "Pole", "Traffic light", "Street lamp", "Overpass", "Building", "Trailer"]

    init(coordinate: CLLocationCoordinate2D, existingCameraID: String? = nil, initialKind: OSMReportKind = .newCamera) {
        self.coordinate = coordinate
        self.existingCameraID = existingCameraID
        self.initialKind = initialKind
        _kind = State(initialValue: initialKind)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if didSubmit {
                        successView
                    } else {
                        formView
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background.ignoresSafeArea())
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var formView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Report a Camera")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.foreground)

            Text("Sends an anonymous note to OpenStreetMap so community mappers can verify and tag it. No account needed.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)

            SectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    if existingCameraID != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Report type")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.foreground)
                            Picker("Report type", selection: $kind) {
                                ForEach([OSMReportKind.wrongInfo, OSMReportKind.removed]) { item in
                                    Text(item.rawValue).tag(item)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    fieldLabel("Location")
                    Text(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)

                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Camera facing (optional)")
                        Picker("Direction", selection: $direction) {
                            ForEach(directions, id: \.self) { item in
                                Text(item.isEmpty ? "Unknown" : item).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Mounted on (optional)")
                        Picker("Mount", selection: $mountType) {
                            ForEach(mounts, id: \.self) { item in
                                Text(item.isEmpty ? "Unknown" : item).tag(item)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppTheme.accent)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Operator or brand guess (optional)")
                        TextField("e.g. Flock Safety, Motorola", text: $operatorGuess)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(AppTheme.background.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(AppTheme.foreground)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Details (optional)")
                        TextField("What did you see?", text: $notes, axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(AppTheme.background.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(AppTheme.foreground)
                    }
                }
            }

            if let submitError {
                Text(submitError)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.densityHigh)
            }

            Button {
                submit()
            } label: {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .tint(AppTheme.background)
                    }
                    Text(isSubmitting ? "Submitting…" : "Submit to OpenStreetMap")
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(AppTheme.background)
                .background(AppTheme.primary.opacity(isSubmitting ? 0.6 : 1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)

            Text("Notes are public on openstreetmap.org and reviewed by volunteer mappers.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
        }
    }

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(AppTheme.densityLow)
                .padding(.top, 24)

            Text("Report sent")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.foreground)

            Text("Your note is now visible to OpenStreetMap mappers. Once verified and tagged, the camera will appear here and in DeFlock.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(AppTheme.background)
                    .background(AppTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(AppTheme.mutedForeground)
    }

    private func submit() {
        isSubmitting = true
        submitError = nil
        let report = OSMCameraReport(
            kind: kind,
            coordinate: coordinate,
            existingCameraID: existingCameraID,
            direction: direction.isEmpty ? nil : direction,
            mountType: mountType.isEmpty ? nil : mountType,
            operatorGuess: operatorGuess.isEmpty ? nil : operatorGuess,
            notes: notes.isEmpty ? nil : notes
        )
        Task {
            do {
                try await OSMReportService.shared.submit(report)
                isSubmitting = false
                withAnimation(.easeInOut(duration: 0.25)) {
                    didSubmit = true
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                isSubmitting = false
                submitError = error.localizedDescription
            }
        }
    }
}
