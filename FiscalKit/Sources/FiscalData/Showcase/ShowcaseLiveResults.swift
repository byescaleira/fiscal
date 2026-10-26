#if DEBUG
    import FiscalDomain
    import Foundation

    public actor ShowcaseLiveResults: LiveResultsService {
        private let scenario: RaceScenario
        private var step = 0

        public init(scenario: RaceScenario) {
            self.scenario = scenario
        }

        public static func fromLaunchArguments() -> ShowcaseLiveResults? {
            RaceScenario.named(UserDefaults.standard.string(forKey: "FiscalLiveScenario"))
                .map(ShowcaseLiveResults.init(scenario:))
        }

        public func races() async throws -> [Race] {
            defer { step += 1 }
            switch scenario {
            case .unavailable: throw FiscalError.onFetch
            case .offline where step > 0: throw FiscalError.onFetch
            default: return scenario.races(step: step)
            }
        }

        public func follow(raceID: String, pushToken: String, environment: PushEnvironment)
            async throws
        {}

        public func unfollow(pushToken: String) async throws {}
    }
#endif
