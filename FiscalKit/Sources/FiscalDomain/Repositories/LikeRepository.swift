import Foundation

public protocol LikeRepository: Sendable {
    func liked() async throws -> [LikedItem]
    func like(_ item: LikedItem) async throws
    func unlike(id: String) async throws
    func reset() async throws
}
