import FiscalDomain
import Foundation

extension FeedModel {
    struct Loaded: Sendable {
        var activities: [FollowingFeed.Activity] = []
        var actions: [String: ActionList] = [:]
        var speeches: [String: [Speech]] = [:]
        var missing: [PersonCard] = []
    }

    private struct PersonRead: Sendable {
        let person: PersonCard
        let activities: [FollowingFeed.Activity]
        let actions: ActionList?
        let speeches: [Speech]
        let failed: Bool
    }

    nonisolated static func read(
        _ people: [PersonCard], years: [Int], first: Bool, from service: any PublicDataService
    ) async -> Loaded {
        var loaded = Loaded()
        for start in stride(from: 0, to: people.count, by: concurrentReads) {
            let batch = people[start..<min(start + concurrentReads, people.count)]
            let results = await withTaskGroup(of: PersonRead.self) { group in
                for person in batch {
                    group.addTask {
                        await read(person, years: years, first: first, from: service)
                    }
                }
                var found: [PersonRead] = []
                for await result in group { found.append(result) }
                return found
            }
            for result in results {
                loaded.activities += result.activities
                if let list = result.actions { loaded.actions[result.person.slug] = list }
                if !result.speeches.isEmpty {
                    loaded.speeches[result.person.slug, default: []] += result.speeches
                }
                if result.failed { loaded.missing.append(result.person) }
            }
        }
        loaded.missing.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return loaded
    }

    nonisolated private static func read(
        _ person: PersonCard, years: [Int], first: Bool, from service: any PublicDataService
    ) async -> PersonRead {
        var failures = 0
        var activities: [FollowingFeed.Activity] = []
        var speeches: [Speech] = []
        func attempt<Value: Sendable>(_ load: () async throws -> Value) async -> Value? {
            do {
                return try await load()
            } catch PublicDataError.notFound {
                return nil
            } catch {
                failures += 1
                return nil
            }
        }
        let actions = first ? await attempt { try await service.actions(slug: person.slug) } : nil
        let checks = first ? await attempt { try await service.checks(slug: person.slug) } : nil
        for (index, year) in years.enumerated() {
            let votes = await attempt { try await service.votes(slug: person.slug, year: year) }
            let expenses = await attempt {
                try await service.expenses(slug: person.slug, year: year)
            }
            let said = await attempt { try await service.speeches(slug: person.slug, year: year) }
            speeches += said?.items ?? []
            activities.append(
                FollowingFeed.Activity(
                    person: person, votes: votes?.items ?? [], expenses: expenses,
                    expensesYear: year,
                    checks: index == 0 ? (checks.flatMap(\.self)?.items ?? []) : []))
        }
        return PersonRead(
            person: person, activities: activities, actions: actions.flatMap(\.self),
            speeches: speeches, failed: failures > 0)
    }
}
