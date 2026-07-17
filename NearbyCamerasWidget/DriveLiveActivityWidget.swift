import ActivityKit
import SwiftUI
import WidgetKit

struct DriveLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DriveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("OVERWATCH · DRIVE")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(Color(red: 1.0, green: 0.32, blue: 0.22))
                    Spacer()
                    Text(context.state.exposureLabel.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))
                }
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.state.nextLabel)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("LOCK \(context.state.distanceLabel)")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(red: 0.18, green: 0.92, blue: 0.88))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(context.state.remaining)")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("GRID AHEAD")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
            .padding(14)
            .activityBackgroundTint(Color(red: 0.03, green: 0.035, blue: 0.05))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("LOCK")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.distanceLabel)
                        .font(.caption.weight(.black))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.nextLabel)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer()
                        Text("\(context.state.remaining) AHEAD · \(context.state.exposureLabel)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(Color(red: 1.0, green: 0.32, blue: 0.22))
            } compactTrailing: {
                Text(context.state.distanceLabel)
                    .font(.caption2.weight(.black))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "eye.fill")
                    .foregroundStyle(Color(red: 1.0, green: 0.32, blue: 0.22))
            }
        }
    }
}
