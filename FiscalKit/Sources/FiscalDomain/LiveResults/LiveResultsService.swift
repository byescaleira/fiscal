import Foundation

public enum PushEnvironment: String, Codable, Sendable {
    case development, production
}

public protocol LiveResultsService: Sendable {
    func races() async throws -> [Race]
    func follow(raceID: String, pushToken: String, environment: PushEnvironment) async throws
    func unfollow(pushToken: String) async throws
}
