import Foundation

public protocol LensRepository: Sendable {
    func lens() async throws -> Lens?
    func save(_ lens: Lens) async throws
    func reset() async throws
}
