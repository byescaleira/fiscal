import FiscalDomain
import Foundation

public enum PublicDataPhase: Equatable, Sendable {
    case idle, loading, loaded
    case failed(PublicDataError)

    public var error: PublicDataError? {
        if case .failed(let error) = self { return error }
        return nil
    }

    public var isLoading: Bool { self == .loading }

    @MainActor
    public static func settle(
        after previous: PublicDataPhase, _ work: @MainActor () async throws -> Void
    ) async -> PublicDataPhase {
        do {
            try await work()
            try Task.checkCancellation()
            return .loaded
        } catch {
            return failure(error, after: previous)
        }
    }

    @MainActor
    public static func settle<Value>(
        after previous: PublicDataPhase, in requests: PublicDataRequests,
        fetch: @MainActor () async throws -> Value, apply: @MainActor (Value) -> Void
    ) async -> PublicDataPhase {
        let request = requests.begin()
        let phase: PublicDataPhase
        do {
            let value = try await fetch()
            try Task.checkCancellation()
            guard requests.isLatest(request) else { return requests.latestPhase }
            apply(value)
            phase = .loaded
        } catch {
            guard requests.isLatest(request) else { return requests.latestPhase }
            phase = failure(error, after: previous)
        }
        requests.finish(request, with: phase)
        return phase
    }

    static func failure(_ error: any Error, after previous: PublicDataPhase) -> PublicDataPhase {
        if error is CancellationError { return previous == .loading ? .idle : previous }
        return .failed(error as? PublicDataError ?? .unavailable)
    }
}

@MainActor
public final class PublicDataRequests {
    private var latest = 0
    private var settled: (request: Int, phase: PublicDataPhase)?

    public init() {}

    func begin() -> Int {
        latest += 1
        return latest
    }

    func isLatest(_ request: Int) -> Bool {
        request == latest
    }

    func finish(_ request: Int, with phase: PublicDataPhase) {
        settled = (request, phase)
    }

    var latestPhase: PublicDataPhase {
        guard let settled, settled.request == latest else { return .loading }
        return settled.phase
    }
}
