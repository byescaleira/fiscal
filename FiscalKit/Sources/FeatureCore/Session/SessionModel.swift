import FiscalDomain
import Observation

@MainActor @Observable
public final class SessionModel {
    public static let coalescing: Duration = .milliseconds(120)

    public let repositories: Repositories
    public private(set) var generation = 0
    @ObservationIgnored private let changes: any StorageChangeFeed
    @ObservationIgnored private let coalescing: Duration

    public init(
        repositories: Repositories, changes: any StorageChangeFeed = SilentChangeFeed(),
        coalescing: Duration = SessionModel.coalescing
    ) {
        self.repositories = repositories
        self.changes = changes
        self.coalescing = coalescing
    }

    public func start() async {
        var pending: Task<Void, Never>?
        defer { pending?.cancel() }
        for await _ in changes.changes() {
            pending?.cancel()
            pending = Task { [coalescing] in
                try? await Task.sleep(for: coalescing)
                guard !Task.isCancelled else { return }
                self.reload()
            }
        }
    }

    public func reload() {
        generation += 1
    }
}
