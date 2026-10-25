import Foundation

public enum WidgetState<Value: Hashable & Sendable>: Hashable, Sendable {
    case ready(Value)
    case empty
    case needsPlace
    case unavailable(offline: Bool)

    public var value: Value? {
        if case .ready(let value) = self { return value }
        return nil
    }
}

public struct VoteDeck: Hashable, Sendable {
    public static let earlierLimit = 3

    public let headline: VoteBoard
    public let earlier: [VoteBoard]

    public init(headline: VoteBoard, earlier: [VoteBoard]) {
        self.headline = headline
        self.earlier = earlier
    }

    public init?(votes: [VoteSummary]) {
        let ordered = Self.ordered(votes)
        guard let headline = ordered.first(where: \.nominal) ?? ordered.first else { return nil }
        self.headline = VoteBoard(headline)
        earlier = ordered.filter { $0.id != headline.id }.prefix(Self.earlierLimit)
            .map(VoteBoard.init)
    }

    public static func ordered(_ votes: [VoteSummary]) -> [VoteSummary] {
        votes.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return (lhs.time ?? "") > (rhs.time ?? "")
        }
    }
}

public struct WidgetFeed: Sendable {
    private let service: any PublicDataService

    public init(service: any PublicDataService) {
        self.service = service
    }

    public func votes() async -> WidgetState<VoteDeck> {
        do {
            let votes = try await service.recentVotes()
            return VoteDeck(votes: votes).map(WidgetState.ready) ?? .empty
        } catch {
            return Self.failure(error)
        }
    }

    public func representatives(uf: String?) async -> WidgetState<RepresentativesDigest> {
        guard let uf = uf.flatMap(HomePlace.uf(fromPlaceCode:)) else { return .needsPlace }
        do {
            let digest = RepresentativesDigest(try await service.representatives(uf: uf))
            return digest.isEmpty ? .empty : .ready(digest)
        } catch {
            return Self.failure(error)
        }
    }

    static func failure<Value>(_ error: any Error) -> WidgetState<Value> {
        .unavailable(offline: (error as? PublicDataError) == .offline)
    }
}

public enum WidgetSchedule {
    public static let sessionHours = 9..<21
    public static let morningHour = 8

    public static func nextVotesRefresh(after now: Date, calendar: Calendar) -> Date {
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)
        let isWeekday = (2...6).contains(weekday)
        if isWeekday, sessionHours.contains(hour) {
            return now.addingTimeInterval(3_600)
        }
        let next = calendar.nextDate(
            after: now, matching: DateComponents(hour: morningHour, minute: 0),
            matchingPolicy: .nextTime)
        return next ?? now.addingTimeInterval(6 * 3_600)
    }

    public static func nextRepresentativesRefresh(after now: Date) -> Date {
        now.addingTimeInterval(12 * 3_600)
    }

    public static func retry(after now: Date) -> Date {
        now.addingTimeInterval(3_600)
    }
}
