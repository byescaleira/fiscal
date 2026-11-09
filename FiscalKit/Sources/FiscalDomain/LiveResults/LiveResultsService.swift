import Foundation

public protocol LiveResultsService: Sendable {
    func races() async throws -> [Race]
}

public enum LiveResultsError: Error, Equatable, Sendable {
    case rejected(Int)
    case unavailable
}
