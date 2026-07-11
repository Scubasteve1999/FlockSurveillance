import CoreLocation
import SwiftUI
import UIKit

/// Renders Instagram-ready share images for Place Score and drive reports.
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

private struct PlaceScoreShareCard: View {
    let score: PlaceScore

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.12),
                    Color(red: 0.14, green: 0.08, blue: 0.07),
                    Color(red: 0.06, green: 0.07, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 18) {
                Text("FLOCK SURVEILLANCE")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Color(red: 0.95, green: 0.42, blue: 0.28))

                Text(score.headline)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    WatchednessDial(
                        grade: score.grade,
                        cameraCount: score.cameraCount,
                        size: 180,
                        animate: false
                    )
                    Spacer()
                }
                .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 10) {
                    row("Within", score.radiusMilesLabel)
                    row("Flock share", "\(score.flockPercent)%")
                    row("Density", String(format: "%.1f / sq mi", score.densityPerSquareMile))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer()

                Text("How watched is your life right now?")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.86))

                Text("flocksurveillance.com")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(28)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

private struct DriveReportShareCard: View {
    let cameraCount: Int
    let exposureLabel: String
    let distanceMiles: Double
    let originLabel: String
    let destinationLabel: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.12),
                    Color(red: 0.10, green: 0.12, blue: 0.16),
                    Color(red: 0.06, green: 0.07, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 18) {
                Text("FLOCK SURVEILLANCE")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Color(red: 0.95, green: 0.42, blue: 0.28))

                Text("Safest drive")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                Text(exposureLabel.uppercased())
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.86))

                VStack(alignment: .leading, spacing: 10) {
                    row("From", originLabel)
                    row("To", destinationLabel)
                    row("Cameras on route", "\(cameraCount)")
                    row("Distance", String(format: "%.1f mi", distanceMiles))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer()

                Text("Fewer cameras. Same destination.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.86))

                Text("flocksurveillance.com")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(28)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
    }
}
