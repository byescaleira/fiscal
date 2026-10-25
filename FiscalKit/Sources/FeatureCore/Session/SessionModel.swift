import FiscalDomain
import Observation

@MainActor @Observable
public final class SessionModel {
    public let repositories: Repositories
    public private(set) var generation = 0

    public init(repositories: Repositories) {
        self.repositories = repositories
    }

    public func reload() {
        generation += 1
    }
}
