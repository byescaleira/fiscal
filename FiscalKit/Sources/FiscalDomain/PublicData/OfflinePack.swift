import Foundation
import Observation
import Synchronization

public struct OfflinePackRequest: Equatable, Sendable {
    public var followed: [String]
    public var placeCode: String?

    public init(followed: [String] = [], placeCode: String? = nil) {
        self.followed = followed
        self.placeCode = placeCode
    }
}

public struct OfflinePackSummary: Equatable, Sendable {
    public var storedBytes: Int
    public var originalBytes: Int
    public var files: Int
    public var people: Int
    public var updatedAt: Date?

    public init(
        storedBytes: Int = 0, originalBytes: Int = 0, files: Int = 0, people: Int = 0,
        updatedAt: Date? = nil
    ) {
        self.storedBytes = storedBytes
        self.originalBytes = originalBytes
        self.files = files
        self.people = people
        self.updatedAt = updatedAt
    }

    public static let empty = OfflinePackSummary()
    public static let limitBytes = 12 * 1_024 * 1_024

    public var isEmpty: Bool { files == 0 }
}

public protocol OfflinePackService: Sendable {
    func summary() async -> OfflinePackSummary
    func refresh() async throws -> OfflinePackSummary
    func erase() async -> OfflinePackSummary
}

@Observable
public final class OfflineNotice: Sendable {
    public enum State: Equatable, Sendable {
        case online
        case offline(Date?)
    }

    public static let shared = OfflineNotice()

    @ObservationIgnored private let storage = Mutex(State.online)

    public init() {}

    public var state: State {
        access(keyPath: \.state)
        return storage.withLock { $0 }
    }

    public func markOnline() {
        guard storage.withLock({ $0 }) != .online else { return }
        withMutation(keyPath: \.state) { storage.withLock { $0 = .online } }
    }

    public func markOffline(dataFrom date: Date?) {
        let next = storage.withLock { current -> State in
            guard case .offline(let shown) = current else { return .offline(date) }
            guard let shown else { return .offline(date) }
            guard let date else { return current }
            return .offline(min(shown, date))
        }
        guard storage.withLock({ $0 }) != next else { return }
        withMutation(keyPath: \.state) { storage.withLock { $0 = next } }
    }
}
