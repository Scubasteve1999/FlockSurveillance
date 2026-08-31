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

    /// Same buckets as `AppTheme.densityLabel` — HUD words, not CLEAR/ELEV/ZONE.
    private var densityLabel: String {
        switch entry.count {
        case 0: return "Clear"
        case 1...4: return "Low"
        case 5...14: return "Moderate"
        case 15...29: return "Dense"
        default: return "Saturated"
        }
    }

    /// Same buckets as `AppTheme.densityColor`. Palette RGB stays local (widget target).
    private var densityColor: Color {
        switch entry.count {
        case 0...4: return Color(red: 0.22, green: 0.92, blue: 0.55)
        case 5...14: return Color(red: 1.0, green: 0.72, blue: 0.18)
        case 15...29: return Color(red: 1.0, green: 0.32, blue: 0.22)
        default: return Color(red: 1.0, green: 0.12, blue: 0.28)
        }
    }

    private var pinCountLabel: String {
        entry.count == 1 ? "1 pin" : "\(entry.count) pins"
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircular
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryInline:
            Text(entry.hasHome ? "\(pinCountLabel) · \(densityLabel)" : "Set Home in Settings")
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
                if entry.hasHome {
                    Text("\(entry.count)")
                        .font(.system(size: 18, weight: .black))
                }
            }
        }
        .accessibilityLabel(
            entry.hasHome
                ? "\(pinCountLabel) mapped near Home"
                : "Set Home in Settings"
        )
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "flocksurveillance://map"))
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("OVERWATCH")
                .font(.system(size: 10, weight: .black))
                .tracking(0.5)
            if entry.hasHome {
                Text("\(pinCountLabel.uppercased()) · \(densityLabel)")
                    .font(.system(size: 13, weight: .bold))
                if let nearest = entry.nearestMeters {
                    Text("LOCK \(format(nearest))")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .opacity(0.75)
                }
            } else {
                Text("Set Home in Settings")
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
                if entry.hasHome {
                    Text(densityLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(densityColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(densityColor.opacity(0.15))
                        .overlay(
                            Capsule().stroke(densityColor.opacity(0.35), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                }
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
                Text("Set Home")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Set Home in Settings.")
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
