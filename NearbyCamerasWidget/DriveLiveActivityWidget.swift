import ActivityKit
import SwiftUI
import WidgetKit

struct DriveLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DriveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 6) {
                Text("FLOCK SURVEILLANCE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color(red: 0.95, green: 0.42, blue: 0.28))
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.nextLabel)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Next · \(context.state.distanceLabel)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.86))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(context.state.remaining)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                        Text(context.state.exposureLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .padding(14)
            .activityBackgroundTint(Color(red: 0.07, green: 0.09, blue: 0.12))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Next ALPR")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.distanceLabel)
                        .font(.caption.weight(.bold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.nextLabel)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(context.state.remaining) left · \(context.state.exposureLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "dot.radiowaves.left.and.right")
            } compactTrailing: {
                Text(context.state.distanceLabel)
                    .font(.caption2.weight(.bold))
            } minimal: {
                Image(systemName: "eye.fill")
            }
        }
    }
}
