import Foundation

public protocol SupportRepository: Sendable {
    func support() async throws -> SupportChoice?
    func save(_ support: SupportChoice) async throws
    func reset() async throws
}
