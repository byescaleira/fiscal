#if DEBUG
    import FiscalDomain
    import Foundation

    public enum LensScenario: Equatable, Sendable {
        case stance(PoliticalStance)
        case setup

        public static let launchKey = "FiscalLensScenario"

        public static func named(_ value: String?) -> LensScenario? {
            switch value {
            case nil: nil
            case "setup": .setup
            case "none": .stance(.preferNotToSay)
            case let name?: PoliticalStance(rawValue: name).map(LensScenario.stance)
            }
        }

        public static func fromLaunchArguments(_ defaults: UserDefaults = .standard)
            -> LensScenario?
        {
            named(defaults.string(forKey: launchKey))
        }

        public var lens: Lens? {
            switch self {
            case .setup: nil
            case .stance(let stance): LensPreset.suggested(for: stance).lens(stance: stance)
            }
        }
    }

    public actor ShowcaseLensRepository: LensRepository {
        private var stored: Lens?

        public init(scenario: LensScenario) {
            stored = scenario.lens
        }

        public func lens() -> Lens? { stored }

        public func save(_ lens: Lens) { stored = lens }

        public func reset() { stored = nil }
    }
#endif
