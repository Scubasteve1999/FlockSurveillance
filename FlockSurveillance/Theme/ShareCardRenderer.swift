import CoreLocation
import SwiftUI
import UIKit

/// Renders war-room share images for Place Score and drive reports.
@MainActor
enum ShareCardRenderer {
    static func placeScoreImage(_ score: PlaceScore) -> UIImage? {
        let view = PlaceScoreShareCard(score: score)
        return render(view)
    }

    static func driveReportImage(
        cameraCount: Int,
        exposureLabel: String,
        distanceMiles: Double,
        originLabel: String,
        destinationLabel: String
    ) -> UIImage? {
        let view = DriveReportShareCard(
            cameraCount: cameraCount,
            exposureLabel: exposureLabel,
            distanceMiles: distanceMiles,
            originLabel: originLabel,
            destinationLabel: destinationLabel
        )
        return render(view)
    }

    private static func render<V: View>(_ view: V) -> UIImage? {
        let sized = view.frame(width: 390, height: 520)
        // Fresh renderer each attempt — reusing one ImageRenderer after a nil
        // uiImage does not re-layout.
        for _ in 0..<2 {
            let renderer = ImageRenderer(content: sized)
            renderer.scale = 3
            renderer.proposedSize = ProposedViewSize(width: 390, height: 520)
            if let image = renderer.uiImage {
                return image
            }
        }
        return nil
    }
}

// MARK: - Place Score war room

private struct PlaceScoreShareCard: View {
    let score: PlaceScore

    private var level: SurveillanceLevel {
        SurveillanceLevel.compute(
            visibleCount: score.cameraCount,
            nearestMeters: nil,
            inWatchedZone: score.cameraCount >= 5
        )
    }

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.025, blue: 0.04)

            // Ops grid
            Canvas { context, size in
                let step: CGFloat = 28
                var path = Path()
                for x in stride(from: 0, through: size.width, by: step) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: 0, through: size.height, by: step) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(
                    path,
                    with: .color(Color.white.opacity(0.04)),
                    lineWidth: 0.5
                )
            }

            // Hot corner wash
            RadialGradient(
                colors: [
                    level.color.opacity(0.35),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 280
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("FLOCK SURVEILLANCE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(AppTheme.primary)
                    Spacer()
                    Text("CLASSIFIED · PUBLIC DATA")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.mutedForeground)
                }

                Rectangle()
                    .fill(AppTheme.primary.opacity(0.7))
                    .frame(height: 2)

                Text("OVERWATCH // PLACE SCORE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.accent)

                Text(score.headline.uppercased())
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)

                HStack(alignment: .center, spacing: 18) {
                    ZStack {
                        WatchednessDial(
                            grade: score.grade,
                            cameraCount: score.cameraCount,
                            size: 148,
                            animate: false
                        )
                        // Outer threat ring
                        Circle()
                            .stroke(level.color.opacity(0.55), lineWidth: 2)
                            .frame(width: 168, height: 168)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        warBadge(level.chip, color: level.color)
                        warBadge(level.title, color: AppTheme.foreground.opacity(0.9))
                        Text(score.cameraCountLabel.uppercased())
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.accent)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)

                VStack(spacing: 0) {
                    instrumentRow("RADIUS", score.radiusMilesLabel)
                    divider
                    instrumentRow("FLOCK SHARE", "\(score.flockPercent)%")
                    divider
                    instrumentRow("DENSITY", String(format: "%.1f / SQ MI", score.densityPerSquareMile))
                    divider
                    instrumentRow("GRADE", score.grade.uppercased())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )

                Spacer(minLength: 0)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HOW WATCHED IS YOUR LIFE RIGHT NOW?")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundStyle(AppTheme.accent)
                        Text("OSM · COMMUNITY MAPPED · NOT A VENDOR FEED")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AppTheme.mutedForeground)
                    }
                    Spacer()
                    Text("flocksurveillance.com")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(24)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(AppTheme.border.opacity(0.6))
            .frame(height: 1)
    }

    private func instrumentRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.mutedForeground)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 8)
    }

    private func warBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(color.opacity(0.45), lineWidth: 1)
            )
    }
}

// MARK: - Drive report war room

private struct DriveReportShareCard: View {
    let cameraCount: Int
    let exposureLabel: String
    let distanceMiles: Double
    let originLabel: String
    let destinationLabel: String

    private var level: SurveillanceLevel {
        SurveillanceLevel.compute(
            visibleCount: cameraCount,
            nearestMeters: nil,
            inWatchedZone: false
        )
    }

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.025, blue: 0.04)

            Canvas { context, size in
                let step: CGFloat = 28
                var path = Path()
                for x in stride(from: 0, through: size.width, by: step) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: 0, through: size.height, by: step) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(
                    path,
                    with: .color(Color.white.opacity(0.04)),
                    lineWidth: 0.5
                )
            }

            LinearGradient(
                colors: [level.color.opacity(0.22), .clear],
                startPoint: .top,
                endPoint: .center
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("FLOCK SURVEILLANCE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(AppTheme.primary)
                    Spacer()
                    Text("ROUTE DOSSIER")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.mutedForeground)
                }

                Rectangle()
                    .fill(AppTheme.accent.opacity(0.7))
                    .frame(height: 2)

                Text("OVERWATCH // SAFEST DRIVE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.accent)

                Text(exposureLabel.uppercased())
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(level.color)
                    .shadow(color: level.color.opacity(0.45), radius: 10, y: 0)

                Text(level.title)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.foreground)

                VStack(spacing: 0) {
                    instrumentRow("ORIGIN", originLabel)
                    divider
                    instrumentRow("DESTINATION", destinationLabel)
                    divider
                    instrumentRow("MAPPED PINS", "\(cameraCount)")
                    divider
                    instrumentRow("DISTANCE", String(format: "%.1f MI", distanceMiles))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )

                // Exposure meter
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppTheme.border.opacity(0.5))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppTheme.densityLow,
                                        AppTheme.densityMedium,
                                        AppTheme.primary,
                                        AppTheme.critical
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(12, geo.size.width * level.dialFill))
                    }
                }
                .frame(height: 6)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text("FEWER CAMERAS. SAME DESTINATION.")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundStyle(AppTheme.accent)
                    Text("flocksurveillance.com · OSM community data")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.mutedForeground)
                }
            }
            .padding(24)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(AppTheme.border.opacity(0.6))
            .frame(height: 1)
    }

    private func instrumentRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.mutedForeground)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 8)
    }
}
