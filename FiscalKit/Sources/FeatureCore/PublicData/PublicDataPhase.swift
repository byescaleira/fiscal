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
            return .loaded
        } catch is CancellationError {
            return previous == .loading ? .idle : previous
        } catch {
            return .failed(error as? PublicDataError ?? .unavailable)
        }
    }
}
