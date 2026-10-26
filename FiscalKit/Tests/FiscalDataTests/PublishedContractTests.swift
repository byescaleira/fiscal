import FiscalDomain
import Foundation
import Testing

@testable import FiscalData

@Suite(.enabled(if: ProcessInfo.processInfo.environment["FISCAL_PUBLISHED_CONTRACT"] == "1"))
struct PublishedContractTests {
    private let client = PublicDataClient(
        baseURL: URL(string: "https://fiscal.byescaleira.com/api").unsafelyUnwrapped,
        dataURL: URL(string: "https://dados.fiscal.byescaleira.com").unsafelyUnwrapped,
        session: URLSession(configuration: .ephemeral))

    private func optionalList(_ name: String) -> Bool {
        ["votes ", "proposals ", "speeches ", "expenses "].contains { name.hasPrefix($0) }
    }

    @Test func everyPublishedFileDecodes() async {
        var failures: [String] = []
        func check<T>(_ name: String, _ call: () async throws -> T) async -> T? {
            do {
                return try await call()
            } catch PublicDataError.notFound where optionalList(name) {
                return nil
            } catch {
                failures.append("\(name): \(String(reflecting: error))")
                return nil
            }
        }
        _ = await check("meta") { try await client.meta() }
        let people = await check("people") { try await client.people() } ?? []
        _ = await check("places") { try await client.places() }
        _ = await check("representatives ms") { try await client.representatives(uf: "ms") }
        _ = await check("city 5002704") { try await client.cityRepresentatives(code: "5002704") }
        let sample = Dictionary(grouping: people, by: \.office).values.flatMap { $0.prefix(4) }
        for person in sample {
            _ = await check("profile \(person.slug)") {
                try await client.profile(slug: person.slug)
            }
            _ = await check("actions \(person.slug)") {
                try await client.actions(slug: person.slug)
            }
            _ = await check("context \(person.slug)") {
                try await client.context(slug: person.slug)
            }
            _ = await check("checks \(person.slug)") { try await client.checks(slug: person.slug) }
            for year in [2025, 2026] {
                _ = await check("votes \(person.slug) \(year)") {
                    try await client.votes(slug: person.slug, year: year)
                }
                _ = await check("proposals \(person.slug) \(year)") {
                    try await client.proposals(slug: person.slug, year: year)
                }
                _ = await check("speeches \(person.slug) \(year)") {
                    try await client.speeches(slug: person.slug, year: year)
                }
                _ = await check("expenses \(person.slug) \(year)") {
                    try await client.expenses(slug: person.slug, year: year)
                }
            }
        }
        let recent = await check("recent votes") { try await client.recentVotes() } ?? []
        for vote in recent {
            _ = await check("vote \(vote.id)") { try await client.vote(id: vote.id) }
        }
        _ = await check("agenda") { try await client.agenda() }
        _ = await check("money") { try await client.money() }
        _ = await check("mandate cost") { try await client.mandateCost() }
        _ = await check("money places") { try await client.moneyPlaces() }
        _ = await check("today") { try await client.today() }
        _ = await check("highlights") { try await client.highlights() }
        _ = await check("weight method") { try await client.weightMethod() }
        let catalog = await check("indicators") { try await client.indicators() }
        for entry in catalog??.items.prefix(3) ?? [] {
            _ = await check("indicator \(entry.id)") { try await client.indicator(id: entry.id) }
        }
        _ = await check("facts") { try await client.facts() }
        let elections = await check("election history") { try await client.electionHistory() }
        if elections.flatMap(\.self) == nil { failures.append("election history: missing") }
        _ = await check("timeline") { try await client.politicalTimeline() }
        _ = await check("study") { try await client.studyCatalog() }
        #expect(!people.isEmpty && !recent.isEmpty)
        for failure in failures { Issue.record("CONTRACT FAIL \(failure)") }
    }
}
