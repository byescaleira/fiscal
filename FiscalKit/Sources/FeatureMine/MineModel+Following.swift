import FeatureCore
import FiscalDomain
import Foundation
import WidgetKit

extension MineModel {
    nonisolated static let concurrentReads = 6
    static let widgetKind = "fiscal.representatives"

    struct LoadedActivity: Sendable {
        let activities: [FollowingFeed.Activity]
        let missing: [PersonCard]
    }

    nonisolated static let suggestionLimit = 8
    nonisolated static let suggestionOrder: [Office] = [
        .president, .governor, .senator, .mayor, .federalDeputy, .stateDeputy, .vicePresident,
        .viceGovernor, .viceMayor, .cityCouncilor,
    ]

    public var suggestions: [PersonCard] {
        let followedSlugs = Set(followed.map(\.card.slug))
        var included = Set<String>()
        let representatives = groups.flatMap(\.people).enumerated().sorted { lhs, rhs in
            (Self.rank(lhs.element.office), lhs.offset) < (
                Self.rank(rhs.element.office), rhs.offset
            )
        }
        .map(\.element)
        let pool = (supportedCards + representatives).filter {
            !followedSlugs.contains($0.slug) && included.insert($0.slug).inserted
        }
        return Array(pool.prefix(Self.suggestionLimit))
    }

    nonisolated static func rank(_ office: Office) -> Int {
        suggestionOrder.firstIndex(of: office) ?? suggestionOrder.count
    }

    public var newCount: Int {
        _ = seenVersion
        return FollowingFeed.newCount(updates, seen: lastSeen)
    }

    public func isNew(_ update: FollowingUpdate) -> Bool {
        _ = seenVersion
        return lastSeen(update.person.slug).map { update.isNew(since: $0) } ?? false
    }

    public var hasNoUpdates: Bool { updatesPhase == .loaded && updates.isEmpty }

    public func loadSupported(_ slugs: [String]) async {
        supportedCards = await SupportedPeople.cards(for: slugs, service: service, follows: follows)
    }

    public func loadUpdates() async {
        let people = followed.map(\.card)
        guard !people.isEmpty else {
            updates = []
            missing = []
            updatesPhase = .idle
            publishSnapshot()
            return
        }
        if updates.isEmpty { updatesPhase = .loading }
        let today = CalendarDay(now())
        updatesPhase = await PublicDataPhase.settle(after: updatesPhase, in: updateRequests) {
            guard let service else { throw PublicDataError.unavailable }
            return await Self.activities(for: people, service: service, year: today.year)
        } apply: { loaded in
            updates = FollowingFeed.build(loaded.activities, today: today)
            missing = loaded.missing
            publishSnapshot()
        }
    }

    public func markSeen() {
        let slugs = followed.map(\.card.slug)
        guard !slugs.isEmpty else { return }
        seenStore.markSeen(slugs, at: now())
        seenStore.forget(keeping: Set(slugs))
        seenVersion += 1
    }

    func lastSeen(_ slug: String) -> Date? {
        seenStore.seen(slug) ?? followed.first { $0.card.slug == slug }?.followedAt
    }

    private func publishSnapshot() {
        guard publishesSnapshot else { return }
        let snapshot = FollowingSnapshot.make(
            followed: followed.map(\.card), updates: updates, at: now())
        try? snapshot.write()
        WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
    }

    nonisolated static func activities(
        for people: [PersonCard], service: any PublicDataService, year: Int
    ) async -> LoadedActivity {
        var activities: [FollowingFeed.Activity] = []
        var missing: [PersonCard] = []
        for start in stride(from: 0, to: people.count, by: concurrentReads) {
            let batch = people[start..<min(start + concurrentReads, people.count)]
            let results = await withTaskGroup(of: (PersonCard, FollowingFeed.Activity?).self) {
                group in
                for person in batch {
                    group.addTask {
                        (person, await activity(of: person, service: service, year: year))
                    }
                }
                var found: [(PersonCard, FollowingFeed.Activity?)] = []
                for await result in group { found.append(result) }
                return found
            }
            for (person, activity) in results {
                if let activity { activities.append(activity) } else { missing.append(person) }
            }
        }
        missing.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return LoadedActivity(activities: activities, missing: missing)
    }

    nonisolated private static func activity(
        of person: PersonCard, service: any PublicDataService, year: Int
    ) async -> FollowingFeed.Activity? {
        async let votes = read { try await service.votes(slug: person.slug, year: year) }
        async let expenses = read { try await service.expenses(slug: person.slug, year: year) }
        async let checks = read { try await service.checks(slug: person.slug) }
        let (voteList, expenseList, checkList) = await (votes, expenses, checks)
        guard !voteList.failed || !expenseList.failed || !checkList.failed else { return nil }
        return FollowingFeed.Activity(
            person: person, votes: voteList.value?.items ?? [], expenses: expenseList.value,
            expensesYear: year, checks: checkList.value??.items ?? [])
    }

    nonisolated private static func read<Value: Sendable>(
        _ load: @Sendable () async throws -> Value
    ) async -> (value: Value?, failed: Bool) {
        do {
            return (try await load(), false)
        } catch PublicDataError.notFound {
            return (nil, false)
        } catch {
            return (nil, true)
        }
    }
}
