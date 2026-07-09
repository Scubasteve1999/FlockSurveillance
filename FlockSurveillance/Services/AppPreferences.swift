import Foundation

enum AppPreferenceKey {
    static let hapticsEnabled = "prefs.hapticsEnabled"
    static let showHeatDefault = "prefs.showHeatDefault"
    static let defaultFilter = "prefs.defaultFilter"
    static let watchModeEnabled = "prefs.watchModeEnabled"
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

    static var defaultFilter: CameraFilter {
        get {
            let raw = UserDefaults.standard.string(forKey: AppPreferenceKey.defaultFilter) ?? CameraFilter.all.rawValue
            return CameraFilter(rawValue: raw) ?? .all
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: AppPreferenceKey.defaultFilter) }
    }
}
