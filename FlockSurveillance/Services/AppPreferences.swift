import Foundation

enum AppPreferenceKey {
    static let hapticsEnabled = "prefs.hapticsEnabled"
    static let showHeatDefault = "prefs.showHeatDefault"
    static let showSensorAtlas = "prefs.showSensorAtlas"
    /// Metro names where the user manually turned Traffic cams off (per-city suppress).
    static let sensorAtlasSuppressedMetros = "prefs.sensorAtlasSuppressedMetros"
    /// Legacy global suppress flag — migrated once into `sensorAtlasSuppressedMetros`.
    static let sensorAtlasAutoSuppressedLegacy = "prefs.sensorAtlasAutoSuppressed"
    static let defaultFilter = "prefs.defaultFilter"
    static let watchModeEnabled = "prefs.watchModeEnabled"
    static let alertsEnabled = "prefs.alertsEnabled"
    static let alertsFlockOnly = "prefs.alertsFlockOnly"
    static let quietHoursEnabled = "prefs.quietHoursEnabled"
    static let quietStartHour = "prefs.quietStartHour"
    static let quietEndHour = "prefs.quietEndHour"
    static let hasAutoShownPlaceScore = "prefs.hasAutoShownPlaceScore"
}

enum AppPreferences {
    static var hapticsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: AppPreferenceKey.hapticsEnabled) == nil { return true }
            return UserDefaults.standard.bool(forKey: AppPreferenceKey.hapticsEnabled)
        }
        set { UserDefaults.standard.set(newValue, forKey: AppPreferenceKey.hapticsEnabled) }
    }

    static var showHeatDefault: Bool {
        get {
            if UserDefaults.standard.object(forKey: AppPreferenceKey.showHeatDefault) == nil { return true }
            return UserDefaults.standard.bool(forKey: AppPreferenceKey.showHeatDefault)
        }
        set { UserDefaults.standard.set(newValue, forKey: AppPreferenceKey.showHeatDefault) }
    }

    /// Sensor Atlas (municipal traffic cams) layer. Off by default unless auto-enabled in-metro.
    static var showSensorAtlas: Bool {
        get { UserDefaults.standard.bool(forKey: AppPreferenceKey.showSensorAtlas) }
        set { UserDefaults.standard.set(newValue, forKey: AppPreferenceKey.showSensorAtlas) }
    }

    /// Metros where Traffic cams auto-enable is suppressed after a manual off.
    static var sensorAtlasSuppressedMetros: Set<String> {
        get {
            migrateLegacySensorAtlasSuppressIfNeeded()
            let names = UserDefaults.standard.stringArray(
                forKey: AppPreferenceKey.sensorAtlasSuppressedMetros
            ) ?? []
            return Set(names)
        }
        set {
            UserDefaults.standard.set(
                Array(newValue).sorted(),
                forKey: AppPreferenceKey.sensorAtlasSuppressedMetros
            )
        }
    }

    /// One-shot: old global bool → suppress every known metro name.
    private static func migrateLegacySensorAtlasSuppressIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: AppPreferenceKey.sensorAtlasAutoSuppressedLegacy) != nil else {
            return
        }
        if defaults.bool(forKey: AppPreferenceKey.sensorAtlasAutoSuppressedLegacy) {
            let all = Set(SensorAtlasCoverage.metros.map(\.name))
            let existing = Set(
                defaults.stringArray(forKey: AppPreferenceKey.sensorAtlasSuppressedMetros) ?? []
            )
            defaults.set(Array(existing.union(all)).sorted(), forKey: AppPreferenceKey.sensorAtlasSuppressedMetros)
        }
        defaults.removeObject(forKey: AppPreferenceKey.sensorAtlasAutoSuppressedLegacy)
    }

    static var defaultFilter: CameraFilter {
        get {
            let raw = UserDefaults.standard.string(forKey: AppPreferenceKey.defaultFilter) ?? CameraFilter.all.rawValue
            return CameraFilter(rawValue: raw) ?? .all
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: AppPreferenceKey.defaultFilter) }
    }

    static var alertsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: AppPreferenceKey.alertsEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: AppPreferenceKey.alertsEnabled) }
    }

    static var alertsFlockOnly: Bool {
        get { UserDefaults.standard.bool(forKey: AppPreferenceKey.alertsFlockOnly) }
        set { UserDefaults.standard.set(newValue, forKey: AppPreferenceKey.alertsFlockOnly) }
    }

    static var quietHoursEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: AppPreferenceKey.quietHoursEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: AppPreferenceKey.quietHoursEnabled) }
    }

    static var quietStartHour: Int {
        get {
            if UserDefaults.standard.object(forKey: AppPreferenceKey.quietStartHour) == nil { return 22 }
            return UserDefaults.standard.integer(forKey: AppPreferenceKey.quietStartHour)
        }
        set { UserDefaults.standard.set(newValue, forKey: AppPreferenceKey.quietStartHour) }
    }

    static var quietEndHour: Int {
        get {
            if UserDefaults.standard.object(forKey: AppPreferenceKey.quietEndHour) == nil { return 7 }
            return UserDefaults.standard.integer(forKey: AppPreferenceKey.quietEndHour)
        }
        set { UserDefaults.standard.set(newValue, forKey: AppPreferenceKey.quietEndHour) }
    }

    static var hasAutoShownPlaceScore: Bool {
        get { UserDefaults.standard.bool(forKey: AppPreferenceKey.hasAutoShownPlaceScore) }
        set { UserDefaults.standard.set(newValue, forKey: AppPreferenceKey.hasAutoShownPlaceScore) }
    }
}
