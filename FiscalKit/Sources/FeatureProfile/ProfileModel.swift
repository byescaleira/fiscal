import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class ProfileModel {
    public let slug: String
    public let showsFactChecks = false
    public private(set) var profile: Profile?
    public private(set) var lens: Lens?
    public private(set) var votes: PublicList<PersonVote>?
    public private(set) var proposals: PublicList<Proposal>?
    public private(set) var speeches: PublicList<Speech>?
    public private(set) var expenses: ExpenseList?
    public private(set) var context: PersonContext?
    public var selectedIndicatorID: String?
    public private(set) var isFollowing = false
    public private(set) var phase: PublicDataPhase = .idle
    public var error: FiscalError?
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let follows: (any FollowRepository)?
    @ObservationIgnored private let lensRepository: (any LensRepository)?
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored let calendar: Calendar

    public init(
        slug: String, service: (any PublicDataService)?, follows: (any FollowRepository)? = nil,
        lens: (any LensRepository)? = nil, now: @escaping @Sendable () -> Date = { .now },
        calendar: Calendar = FiscalCalendar.current
    ) {
        self.slug = slug
        self.service = service
        self.follows = follows
        lensRepository = lens
        self.now = now
        self.calendar = calendar
    }

    public var isEmpty: Bool { profile == nil }

    public var canFollow: Bool { follows != nil && profile != nil }

    public var year: Int { calendar.component(.year, from: now()) }

    public var title: String { profile?.name ?? String(appLocalized: "Profile") }

    public var shareRoute: Route? {
        profile.map { .share(.person(slug: $0.slug)) }
    }

    public var subtitle: String? {
        guard let profile else { return nil }
        return "\(officeLine) · \(profile.party) · \(profile.status.title)"
    }

    public var officeLine: String {
        guard let profile else { return "" }
        return profile.uf == "br"
            ? profile.office.title : "\(profile.office.title) · \(profile.uf.uppercased())"
    }

    public var statusText: String? { profile?.status.title }

    public var isInOffice: Bool { profile?.status == .inOffice }

    public var mandateText: String? {
        guard let mandate = profile?.mandate else { return nil }
        switch (mandate.start, mandate.end) {
        case (let start?, let end?):
            return String(appLocalized: "Term \(String(start.year))–\(String(end.year))")
        case (let start?, nil):
            return String(appLocalized: "Term since \(String(start.year))")
        case (nil, let end?):
            return String(appLocalized: "Term until \(String(end.year))")
        case (nil, nil):
            return nil
        }
    }

    public var sources: [Source] { profile?.sources ?? [] }

    public var sourceText: String? { SourceFootnote.text(sources, calendar: calendar) }

    public func load() async {
        if profile == nil { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase) {
            guard let service else { throw PublicDataError.unavailable }
            profile = try await service.profile(slug: slug)
            isFollowing = (try? await follows?.isFollowing(slug: slug)) ?? false
            lens = try? await lensRepository?.lens()
        }
        await loadActivity()
    }

    public func toggleFollow() async {
        guard let follows, let card = profile?.card else { return }
        do {
            if isFollowing {
                try await follows.unfollow(slug: slug)
            } else {
                try await follows.follow(card, at: now())
            }
            isFollowing.toggle()
        } catch {
            self.error = .onSave
        }
    }

    private func loadActivity() async {
        guard let service, let profile else { return }
        let slug = slug
        let year = year
        let wanted = Set(profile.coverage.filter { $0.status == .available }.map(\.kind))
        async let votes = Self.fetch(wanted.contains("votes")) {
            try await service.votes(slug: slug, year: year)
        }
        async let proposals = Self.fetch(wanted.contains("proposals")) {
            try await service.proposals(slug: slug, year: year)
        }
        async let speeches = Self.fetch(wanted.contains("speeches")) {
            try await service.speeches(slug: slug, year: year)
        }
        async let expenses = Self.fetch(wanted.contains("expenses")) {
            try await service.expenses(slug: slug, year: year)
        }
        async let context = Self.fetch(true) {
            try await Self.context(for: profile, service: service)
        }
        let loaded = await (votes, proposals, speeches, expenses, context)
        self.votes = loaded.0
        self.proposals = loaded.1
        self.speeches = loaded.2
        self.expenses = loaded.3
        self.context = loaded.4 ?? nil
    }

    nonisolated private static func fetch<Value: Sendable>(
        _ wanted: Bool, _ work: @Sendable () async throws -> Value
    ) async -> Value? {
        guard wanted else { return nil }
        return try? await work()
    }
}
