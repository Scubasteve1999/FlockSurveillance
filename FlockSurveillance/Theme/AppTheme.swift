import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.06, green: 0.07, blue: 0.09)
    static let foreground = Color(red: 0.94, green: 0.95, blue: 0.97)
    static let primary = Color(red: 0.95, green: 0.42, blue: 0.28)
    static let accent = Color(red: 0.35, green: 0.78, blue: 0.86)
    static let mutedForeground = Color(red: 0.62, green: 0.66, blue: 0.72)
    static let border = Color.white.opacity(0.12)
    static let card = Color(red: 0.11, green: 0.13, blue: 0.16)
    static let cardTop = Color(red: 0.14, green: 0.16, blue: 0.20)
    static let cardBottom = Color(red: 0.09, green: 0.10, blue: 0.13)

    static let densityLow = Color(red: 0.35, green: 0.78, blue: 0.55)
    static let densityMedium = Color(red: 0.95, green: 0.72, blue: 0.28)
    static let densityHigh = Color(red: 0.95, green: 0.42, blue: 0.28)

    static let flockMarker = Color(red: 0.95, green: 0.42, blue: 0.28)
    static let otherMarker = Color(red: 0.35, green: 0.78, blue: 0.86)

    static let cornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 16

    static func densityColor(count: Int) -> Color {
        switch count {
        case 0...4: return densityLow
        case 5...14: return densityMedium
        default: return densityHigh
        }
    }

    static func densityLabel(count: Int) -> String {
        switch count {
        case 0: return "Clear"
        case 1...4: return "Low"
        case 5...14: return "Moderate"
        default: return "Dense"
        }
    }
}

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
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .overlay(
                Capsule().stroke(color.opacity(0.35), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

struct DataSourcePill: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "map.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("OpenStreetMap · community mapped")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(AppTheme.mutedForeground)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.card.opacity(0.9))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
    }
}
