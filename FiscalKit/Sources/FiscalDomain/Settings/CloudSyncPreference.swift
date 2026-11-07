import Foundation

public enum CloudSyncPreference {
    public static let key = "fiscal.settings.cloudSync"
    public static let defaultValue = true

    public static func isOn(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }

    public static func set(_ isOn: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(isOn, forKey: key)
    }
}
