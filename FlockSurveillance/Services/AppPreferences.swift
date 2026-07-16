import Foundation

enum AppPreferenceKey {
    static let hapticsEnabled = "prefs.hapticsEnabled"
    static let showHeatDefault = "prefs.showHeatDefault"
    static let showSensorAtlas = "prefs.showSensorAtlas"
    /// User turned Traffic cams off while inside a covered metro — don't auto-on again.
    static let sensorAtlasAutoSuppressed = "prefs.sensorAtlasAutoSuppressed"
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

    static var sensorAtlasAutoSuppressed: Bool {
        get { UserDefaults.standard.bool(forKey: AppPreferenceKey.sensorAtlasAutoSuppressed) }
        set { UserDefaults.standard.set(newValue, forKey: AppPreferenceKey.sensorAtlasAutoSuppressed) }
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
