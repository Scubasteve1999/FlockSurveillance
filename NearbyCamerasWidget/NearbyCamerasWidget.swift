import AppIntents
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
    @Environment(\.widgetFamily) private var family

    private var levelChip: String {
        switch entry.count {
        case 0: return "CLEAR"
        case 1...4: return "LOW"
        case 5...14: return "ELEV"
        case 15...29: return "HIGH"
        default: return "HOT"
        }
    }

    private var levelColor: Color {
        switch entry.count {
        case 0: return Color(red: 0.22, green: 0.92, blue: 0.55)
        case 1...4: return Color(red: 0.18, green: 0.92, blue: 0.88)
        case 5...14: return Color(red: 1.0, green: 0.72, blue: 0.18)
        case 15...29: return Color(red: 1.0, green: 0.32, blue: 0.22)
        default: return Color(red: 1.0, green: 0.12, blue: 0.28)
        }
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircular
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryInline:
            Text(entry.hasHome ? "\(entry.count) pins · \(levelChip)" : "Set Home · Overwatch")
                .widgetURL(URL(string: "flocksurveillance://map"))
        default:
            systemView
        }
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(entry.hasHome ? "\(entry.count)" : "—")
                    .font(.system(size: 18, weight: .black))
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "flocksurveillance://map"))
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("OVERWATCH")
                .font(.system(size: 10, weight: .black))
                .tracking(0.5)
            if entry.hasHome {
                Text("\(entry.count) PINS · \(levelChip)")
                    .font(.system(size: 13, weight: .bold))
                if let nearest = entry.nearestMeters {
                    Text("LOCK \(format(nearest))")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .opacity(0.75)
                }
            } else {
                Text("Set Home in GEAR")
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "flocksurveillance://map"))
    }

    private var systemView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("OVERWATCH")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color(red: 1.0, green: 0.32, blue: 0.22))
                Spacer()
                Text(levelChip)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(levelColor)
            }

            if entry.hasHome {
                Text("\(entry.count)")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("MAPPED PINS NEAR HOME")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                if let nearest = entry.nearestMeters {
                    Text("LOCK \(format(nearest).uppercased())")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 0.18, green: 0.92, blue: 0.88))
                }
                if let updatedAt = entry.updatedAt {
                    HStack(spacing: 6) {
                        Text(relative(updatedAt))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                        Button(intent: RefreshNearbyIntent()) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(red: 0.18, green: 0.92, blue: 0.88))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("STANDBY")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text("Set Home in GEAR to arm the grid.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.09, blue: 0.12),
                    Color(red: 0.03, green: 0.035, blue: 0.05)
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
        if seconds < 60 { return "NOW" }
        if seconds < 3600 { return "\(Int(seconds / 60))M AGO" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))H AGO" }
        return "\(Int(seconds / 86_400))D AGO"
    }
}

struct NearbyCamerasWidget: Widget {
    let kind = "NearbyCamerasWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NearbyCamerasProvider()) { entry in
            NearbyCamerasWidgetView(entry: entry)
        }
        .configurationDisplayName("Overwatch · Home")
        .description("Mapped ALPR pins within 1 mile of Home — community data, not a vendor feed.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}
