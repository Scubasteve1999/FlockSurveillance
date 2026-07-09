import SwiftUI
import WidgetKit

struct NearbyCamerasEntry: TimelineEntry {
    let date: Date
    let count: Int
    let nearestMeters: Double?
    let hasHome: Bool
    let updatedAt: Date?
}

struct NearbyCamerasProvider: TimelineProvider {
    func placeholder(in context: Context) -> NearbyCamerasEntry {
        NearbyCamerasEntry(date: .now, count: 12, nearestMeters: 240, hasHome: true, updatedAt: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (NearbyCamerasEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NearbyCamerasEntry>) -> Void) {
        let entry = currentEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> NearbyCamerasEntry {
        let defaults = UserDefaults(suiteName: "group.com.flocksurveillance.shared")
        let hasHome = defaults?.object(forKey: "homeLatitude") != nil
        let count = defaults?.integer(forKey: "nearbyCount") ?? 0
        let nearest = defaults?.double(forKey: "nearestMeters") ?? -1
        let updated = defaults?.object(forKey: "updatedAt") as? TimeInterval
        return NearbyCamerasEntry(
            date: .now,
            count: count,
            nearestMeters: nearest >= 0 ? nearest : nil,
            hasHome: hasHome,
            updatedAt: updated.map { Date(timeIntervalSince1970: $0) }
        )
    }
}

struct NearbyCamerasWidgetView: View {
    var entry: NearbyCamerasEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FLOCK SURVEILLANCE")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color(red: 0.95, green: 0.42, blue: 0.28))

            if entry.hasHome {
                Text("\(entry.count)")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                Text("ALPRs within 1 mi of Home")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                if let nearest = entry.nearestMeters {
                    Text("Nearest \(format(nearest))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.86))
                }
                if let updatedAt = entry.updatedAt {
                    Text(relative(updatedAt))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
            } else {
                Text("Open the app")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Text("Set Home in Settings to track nearby ALPRs.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.13, blue: 0.16),
                    Color(red: 0.06, green: 0.07, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .widgetURL(URL(string: "flocksurveillance://map"))
    }

    private func format(_ meters: Double) -> String {
        let miles = meters / 1609.34
        if miles >= 0.1 {
            return String(format: "%.1f mi", miles)
        }
        return String(format: "%.0f ft", meters * 3.28084)
    }

    private func relative(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "Updated just now" }
        if seconds < 3600 { return "Updated \(Int(seconds / 60))m ago" }
        if seconds < 86_400 { return "Updated \(Int(seconds / 3600))h ago" }
        return "Updated \(Int(seconds / 86_400))d ago"
    }
}

@main
struct NearbyCamerasWidget: Widget {
    let kind = "NearbyCamerasWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NearbyCamerasProvider()) { entry in
            NearbyCamerasWidgetView(entry: entry)
        }
        .configurationDisplayName("Nearby ALPRs")
        .description("Shows how many community-mapped ALPRs are within 1 mile of Home.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
