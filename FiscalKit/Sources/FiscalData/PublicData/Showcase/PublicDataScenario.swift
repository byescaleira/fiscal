#if DEBUG
    import Foundation

    public enum PublicDataScenario: String, CaseIterable, Sendable {
        case normal, empty, offline, longNames, unavailable

        public static let launchKey = "FiscalDataScenario"

        public static func named(_ value: String?) -> PublicDataScenario? {
            value.flatMap(PublicDataScenario.init(rawValue:))
        }

        public static func fromLaunchArguments(_ defaults: UserDefaults = .standard)
            -> PublicDataScenario?
        {
            named(defaults.string(forKey: launchKey))
        }
    }
#endif
