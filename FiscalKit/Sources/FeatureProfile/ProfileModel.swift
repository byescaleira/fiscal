import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class ProfileModel {
    public let slug: String
    public private(set) var profile: Profile?
    public private(set) var votes: PublicList<PersonVote>?
    public private(set) var proposals: PublicList<Proposal>?
    public private(set) var speeches: PublicList<Speech>?
    public private(set) var expenses: ExpenseList?
    public private(set) var actions: ActionList?
    public private(set) var weightMethod: WeightMethod?
    public private(set) var context: PersonContext?
    public var selectedIndicatorID: String?
    public private(set) var checks: FactCheckList?
    public private(set) var selectedExpenseYear: Int?
    public private(set) var hasFailedSource = false
    public internal(set) var currentChapter: ProfileChapter?
    public private(set) var hasJustFollowed = false
    public private(set) var phase: PublicDataPhase = .idle
    public var error: FiscalError?
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let follows: (any FollowRepository)?
    @ObservationIgnored private let requests = PublicDataRequests()
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored let calendar: Calendar

    public init(
        slug: String, service: (any PublicDataService)?, follows: (any FollowRepository)? = nil,
        now: @escaping @Sendable () -> Date = { .now },
        calendar: Calendar = GregorianCalendar.current
    ) {
        self.slug = slug
        self.service = service
        self.follows = follows
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
            ? profile.officeTitle : "\(profile.officeTitle) · \(profile.uf.uppercased())"
    }

    public var identityLine: String {
        guard let profile else { return "" }
        return "\(profile.party) · \(officeLine)"
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
        phase = await PublicDataPhase.settle(after: phase, in: requests) {
            guard let service else { throw PublicDataError.unavailable }
            return try await service.profile(slug: slug)
        } apply: { loaded in
            profile = loaded
        }
        await loadActivity()
    }

    public var followCard: PersonCard? { canFollow ? profile?.card : nil }

    public func followChanged(to isFollowing: Bool) {
        hasJustFollowed = isFollowing
    }

    public var expenseYears: [Int] {
        (profile?.years ?? []).filter { ($0.quotaCents ?? 0) > 0 }.map(\.year).sorted(by: >)
    }

    public var expenseYear: Int { selectedExpenseYear ?? expenseYears.first ?? year }

    public func selectExpenseYear(_ year: Int) async {
        guard let service, year != expenseYear else { return }
        selectedExpenseYear = year
        let slug = slug
        let loaded = await Self.fetch(true) { try await service.expenses(slug: slug, year: year) }
        guard selectedExpenseYear == year else { return }
        hasFailedSource = loaded.failed
        expenses = loaded.value
    }

    private func loadActivity() async {
        guard let service, let profile else { return }
        let slug = slug
        let year = year
        let expenseYear = expenseYear
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
            try await service.expenses(slug: slug, year: expenseYear)
        }
        async let actions = Self.fetch(true) { try await service.actions(slug: slug) }
        async let method = Self.fetch(true) { try await service.weightMethod() }

        async let context = Self.fetch(true) {
            try await Self.context(for: profile, service: service)
        }
        let loaded = await (votes, proposals, speeches, expenses, context)
        let extras = await (actions, method)
        self.votes = loaded.0.value
        self.proposals = loaded.1.value
        self.speeches = loaded.2.value
        self.expenses = loaded.3.value
        self.actions = extras.0.value ?? nil
        weightMethod = extras.1.value ?? nil
        self.context = loaded.4.value ?? nil
        hasFailedSource =
            loaded.0.failed || loaded.1.failed || loaded.2.failed || loaded.3.failed
            || loaded.4.failed || extras.0.failed
    }

    nonisolated private static func fetch<Value: Sendable>(
        _ wanted: Bool, _ work: @Sendable () async throws -> Value
    ) async -> (value: Value?, failed: Bool) {
        guard wanted else { return (nil, false) }
        do {
            return (try await work(), false)
        } catch PublicDataError.notFound {
            return (nil, false)
        } catch {
            return (nil, true)
        }
    }
}
