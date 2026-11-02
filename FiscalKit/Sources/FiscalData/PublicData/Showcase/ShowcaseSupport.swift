#if DEBUG
    import FiscalDomain
    import Foundation

    public enum SupportScenario: Equatable, Sendable {
        case none
        case chosen(SupportChoice)

        public static let launchKey = "FiscalSupportScenario"

        public static func named(_ value: String?) -> SupportScenario? {
            guard let value else { return nil }
            if value == "none" { return SupportScenario.none }
            var people: [String] = []
            var causes: [Theme] = []
            for part in value.split(separator: ";") {
                let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
                guard pair.count == 2 else { return nil }
                let items = pair[1].split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                switch pair[0] {
                case "people": people = items
                case "causes": causes = items.compactMap(Theme.init(rawValue:))
                default: return nil
                }
            }
            let choice = SupportChoice(people: people, causes: causes)
            return choice.isEmpty ? nil : .chosen(choice)
        }

        public static func fromLaunchArguments(_ defaults: UserDefaults = .standard)
            -> SupportScenario?
        {
            named(defaults.string(forKey: launchKey))
        }

        public var support: SupportChoice? {
            switch self {
            case .none: nil
            case .chosen(let choice): choice
            }
        }
    }

    public actor ShowcaseSupportRepository: SupportRepository {
        private var stored: SupportChoice?

        public init(scenario: SupportScenario) {
            stored = scenario.support
        }

        public init(support: SupportChoice? = nil) {
            stored = support
        }

        public func support() -> SupportChoice? { stored }

        public func save(_ support: SupportChoice) { stored = support }

        public func reset() { stored = nil }
    }
#endif
