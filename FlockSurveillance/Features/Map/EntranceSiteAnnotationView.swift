import SwiftUI

struct EntranceSiteAnnotationView: View {
    let site: OliveBranchUniqueSite

    private var color: Color {
        switch site.quality {
        case .match: return AppTheme.entranceMatch
        case .nearMiss: return AppTheme.entranceNearMiss
        case .noPin: return AppTheme.entranceGap
        }
    }

    var body: some View {
        ZStack {
            Diamond()
                .fill(color.opacity(0.22))
                .frame(width: 36, height: 36)
            Diamond()
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay(
                    Diamond().stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                )
            Text(site.representative.id)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(AppTheme.background)
        }
        .shadow(color: color.opacity(0.45), radius: 4, y: 1)
        .accessibilityLabel(
            "\(site.displayRoad) city-limit crossing, \(site.quality.label.lowercased()). Reconstruction, not a confirmed camera."
        )
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
