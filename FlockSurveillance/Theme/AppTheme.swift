import SwiftUI

/// Colors and metrics (`AppTheme`) and fonts (`AppTypography`) live in `Shared/Theme` so the
/// widget and Live Activity compile the same tokens. This file holds the app-only components.

struct SectionCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(AppTheme.cardPadding)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [AppTheme.cardTop, AppTheme.cardBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(AppTypography.badge)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .overlay(
                Capsule().stroke(color.opacity(0.35), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

/// Gates MapKit-backed content on a live, non-degenerate size.
///
/// MapKit hangs if inserted at zero size (CAMetalLayer width=0), so wrap map content in
/// this inside a `GeometryReader` and pass `geo.size` — it shows a spinner until the
/// container has a real frame, which `GeometryReader` guarantees to re-report reactively.
struct MapKitSizeGate<Content: View>: View {
    let size: CGSize
    @ViewBuilder var content: () -> Content

    var body: some View {
        if size.width > 1, size.height > 1 {
            content()
        } else {
            ProgressView()
                .tint(AppTheme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct DataSourcePill: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "map.fill")
                .font(AppTypography.chipIcon)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(MapHonestyCopy.chipLine)
                    .font(AppTypography.chip)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .accessibilityLabel(MapHonestyCopy.accessibilityLabel)
                Link(MapHonestyCopy.osmAttribution, destination: MapHonestyCopy.osmCopyrightURL)
                    .font(AppTypography.chip)
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .foregroundStyle(AppTheme.mutedForeground)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        // .contain so VoiceOver reaches the OSM copyright link inside the pill.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map-honesty-chip")
    }
}

// MARK: - Overwatch CTAs

/// Coral → critical fill CTA used for primary drive / route actions.
struct OverwatchPrimaryButton<Label: View>: View {
    var verticalPadding: CGFloat = 12
    var useGradient: Bool = false
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity)
                .padding(.vertical, verticalPadding)
                .foregroundStyle(AppTheme.background)
                .background {
                    if useGradient {
                        LinearGradient(
                            colors: [AppTheme.primary, AppTheme.critical],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        AppTheme.primary
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
                .shadow(color: useGradient ? AppTheme.primary.opacity(0.45) : .clear, radius: 12, y: 0)
        }
        .buttonStyle(.plain)
    }
}

/// Card-top bordered CTA for secondary actions (Hide, share, Work→Home).
struct OverwatchSecondaryButton<Label: View>: View {
    var verticalPadding: CGFloat = 12
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity)
                .padding(.vertical, verticalPadding)
                .foregroundStyle(AppTheme.foreground)
                .background(AppTheme.cardTop.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
