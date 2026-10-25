import Foundation

public struct RemoteFlag: Hashable, Sendable, Codable {
    public let isOn: Bool
    public let rollout: Int

    public init(isOn: Bool, rollout: Int = 100) {
        self.isOn = isOn
        self.rollout = min(max(rollout, 0), 100)
    }
}

public protocol RemoteFlagSource: Sendable {
    func fetch() async throws -> [String: RemoteFlag]
}
