#if DEBUG
    import FiscalDomain
    import Foundation

    public enum LensScenario: Equatable, Sendable {
        case support([String])
        case none
        case setup

        public static let launchKey = "FiscalLensScenario"
        static let supportPrefix = "support:"

        public static func named(_ value: String?) -> LensScenario? {
            guard let value else { return nil }
            switch value {
            case "setup": return .setup
            case "none": return LensScenario.none
            default:
                guard value.hasPrefix(supportPrefix) else { return nil }
                let slugs = value.dropFirst(supportPrefix.count).split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                return slugs.isEmpty ? nil : .support(slugs)
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
            case .none: Lens.suggested(prefersNotToSay: true)
            case .support(let slugs): Lens.suggested(supported: slugs)
            }
        }
    }

    public actor ShowcaseLensRepository: LensRepository {
        private var stored: Lens?

        public init(scenario: LensScenario) {
            stored = scenario.lens
        }

        public init(lens: Lens?) {
            stored = lens
        }

        public func lens() -> Lens? { stored }

        public func save(_ lens: Lens) { stored = lens }

        public func reset() { stored = nil }
    }
#endif
