import FiscalDomain
import Foundation
import Testing

@testable import FiscalData

private actor CompletenessLedger {
    private(set) var failures: [String] = []
    private(set) var checked = 0
    private(set) var voteIDs: Set<String> = []

    func pass() { checked += 1 }

    func fail(_ name: String, _ error: any Error) {
        checked += 1
        failures.append("\(name): \(String(reflecting: error))")
    }

    func missing(_ name: String) {
        checked += 1
        failures.append("\(name): missing")
    }

    func collect(_ ids: some Sequence<String>) { voteIDs.formUnion(ids) }
}

@Suite(
    .enabled(if: ProcessInfo.processInfo.environment["FISCAL_PUBLISHED_CONTRACT"] == "all"),
    .timeLimit(.minutes(60)))
struct PublishedCompletenessTests {
    private static let years = [2023, 2024, 2025, 2026]
    private static let width = 24

    private let client: PublicDataClient = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 768 << 20, diskCapacity: 0)
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.httpMaximumConnectionsPerHost = PublishedCompletenessTests.width
        return PublicDataClient(
            baseURL: URL(string: "https://fiscal.byescaleira.com/api").unsafelyUnwrapped,
            dataURL: URL(string: "https://dados.fiscal.byescaleira.com").unsafelyUnwrapped,
            session: URLSession(configuration: configuration))
    }()

    private func run<Item: Sendable>(
        _ items: [Item], _ body: @escaping @Sendable (Item) async -> Void
    ) async {
        await withTaskGroup(of: Void.self) { group in
            var iterator = items.makeIterator()
            for _ in 0..<Self.width {
                guard let item = iterator.next() else { break }
                group.addTask { await body(item) }
            }
            while await group.next() != nil {
                guard let item = iterator.next() else { continue }
                group.addTask { await body(item) }
            }
        }
    }

    private static func required<T: Sendable>(
        _ ledger: CompletenessLedger, _ name: String, _ call: () async throws -> T?
    ) async -> T? {
        do {
            guard let value = try await call() else {
                await ledger.missing(name)
                return nil
            }
            await ledger.pass()
            return value
        } catch {
            await ledger.fail(name, error)
            return nil
        }
    }

    private static func optional<T: Sendable>(
        _ ledger: CompletenessLedger, _ name: String, _ call: () async throws -> T?
    ) async -> T? {
        do {
            let value = try await call()
            await ledger.pass()
            return value
        } catch PublicDataError.notFound {
            await ledger.pass()
            return nil
        } catch {
            await ledger.fail(name, error)
            return nil
        }
    }

    @Test func everyPublishedRecordLoadsInTheApp() async {
        let ledger = CompletenessLedger()
        let client = client
        let people = await Self.required(ledger, "people") { try await client.people() } ?? []
        let places = await Self.required(ledger, "places") { try await client.places() } ?? []
        let ufs = Set(places.map(\.uf)).sorted()
        await run(ufs) { uf in
            _ = await Self.required(ledger, "representatives \(uf)") {
                try await client.representatives(uf: uf)
            }
        }
        await run(people) { person in
            let slug = person.slug
            _ = await Self.required(ledger, "profile \(slug)") {
                try await client.profile(slug: slug)
            }
            _ = await Self.optional(ledger, "actions \(slug)") {
                try await client.actions(slug: slug)
            }
            _ = await Self.optional(ledger, "context \(slug)") {
                try await client.context(slug: slug)
            }
            _ = await Self.optional(ledger, "checks \(slug)") {
                try await client.checks(slug: slug)
            }
            for year in Self.years {
                if let votes = await Self.optional(
                    ledger, "votes \(slug) \(year)",
                    { try await client.votes(slug: slug, year: year) })
                {
                    await ledger.collect(votes.items.map(\.voteId))
                }
                _ = await Self.optional(ledger, "proposals \(slug) \(year)") {
                    try await client.proposals(slug: slug, year: year)
                }
                _ = await Self.optional(ledger, "speeches \(slug) \(year)") {
                    try await client.speeches(slug: slug, year: year)
                }
                _ = await Self.optional(ledger, "expenses \(slug) \(year)") {
                    try await client.expenses(slug: slug, year: year)
                }
            }
        }
        let cities = places.filter { $0.code.count == 7 }
        await run(cities) { place in
            let code = place.code
            guard
                let city = await Self.required(
                    ledger, "city \(code) \(place.name)",
                    { try await client.cityRepresentatives(code: code) })
            else { return }
            for person in city.groups.filter({ $0.level == .city }).flatMap(\.people) {
                _ = await Self.required(ledger, "city profile \(person.slug) (\(code))") {
                    try await client.profile(slug: person.slug)
                }
            }
        }
        let recent =
            await Self.required(ledger, "recent votes") { try await client.recentVotes() } ?? []
        await ledger.collect(recent.map(\.id))
        let voteIDs = Array(await ledger.voteIDs)
        await run(voteIDs) { id in
            _ = await Self.required(ledger, "vote \(id)") { try await client.vote(id: id) }
        }
        let history = await Self.required(ledger, "election history") {
            try await client.electionHistory()
        }
        await run(history?.races.map(\.id) ?? []) { id in
            _ = await Self.required(ledger, "past race \(id)") { try await client.pastRace(id: id) }
        }
        let catalog = await Self.required(ledger, "indicators") { try await client.indicators() }
        await run(catalog?.items.map(\.id) ?? []) { id in
            _ = await Self.required(ledger, "indicator \(id)") {
                try await client.indicator(id: id)
            }
        }
        _ = await Self.required(ledger, "meta") { try await client.meta() }
        _ = await Self.required(ledger, "agenda") { try await client.agenda() }
        _ = await Self.required(ledger, "money") { try await client.money() }
        _ = await Self.required(ledger, "mandate cost") { try await client.mandateCost() }
        _ = await Self.required(ledger, "money places") { try await client.moneyPlaces() }
        _ = await Self.required(ledger, "today") { try await client.today() }
        _ = await Self.required(ledger, "highlights") { try await client.highlights() }
        _ = await Self.required(ledger, "weight method") { try await client.weightMethod() }
        _ = await Self.required(ledger, "facts") { try await client.facts() }
        _ = await Self.required(ledger, "timeline") { try await client.politicalTimeline() }
        _ = await Self.required(ledger, "study") { try await client.studyCatalog() }
        let failures = await ledger.failures
        let checked = await ledger.checked
        withKnownIssue("Coverage summary, reported on every run") {
            Issue.record(
                "COMPLETENESS checked=\(checked) people=\(people.count) cities=\(cities.count) votes=\(voteIDs.count) failures=\(failures.count)"
            )
        }
        for failure in failures.sorted().prefix(400) {
            Issue.record("COMPLETENESS FAIL \(failure)")
        }
        #expect(failures.isEmpty && !people.isEmpty && !cities.isEmpty)
    }
}
