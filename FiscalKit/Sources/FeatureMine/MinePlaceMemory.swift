import Foundation

@MainActor
public final class MinePlaceMemory {
    public static let key = "FiscalMinePlace"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var code: String? {
        get {
            let value = defaults.string(forKey: Self.key)?
                .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return value?.isEmpty == false ? value : nil
        }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }
    }
}
