import FiscalDomain
import Foundation
import Testing

@testable import FiscalData

struct PublicDataClientTests {
    private struct Harness {
        let host: String
        let client: PublicDataClient
        let cache: URLCache

        init() throws {
            host = PublicDataStub.makeHost()
            cache = URLCache(memoryCapacity: 4 * 1_024 * 1_024, diskCapacity: 0, directory: nil)
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [PublicDataStub.self]
            configuration.urlCache = cache
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            client = PublicDataClient(
                baseURL: try #require(URL(string: "https://\(host)/api")),
                session: URLSession(configuration: configuration))
        }

        func reply(_ path: String, _ json: String, headers: [String: String] = [:]) {
            PublicDataStub.reply(
                .init(status: 200, body: Data(json.utf8), headers: headers), to: "/api/v1/\(path)",
                on: host)
        }

        func everything(_ reply: PublicDataStub.Reply) {
            PublicDataStub.fallback(reply, on: host)
        }

        var paths: [String] { PublicDataStub.seen(on: host).map(\.path) }
    }

    @Test func requestsEveryFileAtTheContractPath() async throws {
        let harness = try Harness()
        harness.everything(.init(status: 200, body: Data("{}".utf8)))
        let client = harness.client
        _ = try? await client.meta()
        _ = try? await client.people()
        _ = try? await client.places()
        _ = try? await client.representatives(uf: "SP")
        _ = try? await client.profile(slug: "tabata-amaral")
        _ = try? await client.votes(slug: "tabata-amaral", year: 2_026)
        _ = try? await client.proposals(slug: "tabata-amaral", year: 2_026)
        _ = try? await client.speeches(slug: "tabata-amaral", year: 2_026)
        _ = try? await client.expenses(slug: "tabata-amaral", year: 2_026)
        _ = try? await client.recentVotes()
        _ = try? await client.vote(id: "camara-2416587")
        _ = try? await client.agenda()
        _ = try? await client.money()
        _ = try? await client.today()
        #expect(
            harness.paths == [
                "/api/v1/meta.json", "/api/v1/index/people.json", "/api/v1/index/places.json",
                "/api/v1/places/sp.json", "/api/v1/people/tabata-amaral.json",
                "/api/v1/people/tabata-amaral/votes-2026.json",
                "/api/v1/people/tabata-amaral/proposals-2026.json",
                "/api/v1/people/tabata-amaral/speeches-2026.json",
                "/api/v1/people/tabata-amaral/expenses-2026.json", "/api/v1/votes/recent.json",
                "/api/v1/votes/camara-2416587.json", "/api/v1/agenda/today.json",
                "/api/v1/money/overview.json", "/api/v1/today.json",
            ])
    }

    @Test func decodesTheSearchIndex() async throws {
        let harness = try Harness()
        harness.reply(
            "index/people.json",
            #"[{ "slug": "kim-kataguiri", "name": "Kim Kataguiri", "office": "federalDeputy", "uf": "sp", "party": "UNIÃO", "photo": null, "status": "inOffice" }]"#
        )
        let people = try await harness.client.people()
        #expect(people.map(\.slug) == ["kim-kataguiri"])
        #expect(people.first?.party == "UNIÃO")
    }

    @Test func decodesTheRecentVotes() async throws {
        let harness = try Harness()
        harness.reply(
            "votes/recent.json",
            #"[{ "id": "senado-7042", "house": "senado", "date": "2026-10-22", "time": null, "proposition": "PEC 14/2026", "kind": null, "summary": "Altera a Constituição.", "plainSummary": null, "themes": ["saude"], "result": null, "approved": null, "nominal": false, "yes": null, "no": null, "others": null }]"#
        )
        let votes = try await harness.client.recentVotes()
        #expect(votes.first?.house == .senado)
        #expect(votes.first?.tally.total == nil)
    }

    @Test func tellsMissingFilesFromRejectionsAndOutages() async throws {
        let harness = try Harness()
        harness.everything(.init(status: 404))
        await #expect(throws: PublicDataError.notFound) {
            try await harness.client.profile(slug: "nobody")
        }
        harness.everything(.init(status: 403))
        await #expect(throws: PublicDataError.rejected(403)) { try await harness.client.money() }
        harness.everything(.init(status: 429))
        await #expect(throws: PublicDataError.unavailable) { try await harness.client.money() }
        harness.everything(.init(status: 503))
        await #expect(throws: PublicDataError.unavailable) { try await harness.client.today() }
        harness.everything(.init(failure: .notConnectedToInternet))
        await #expect(throws: PublicDataError.offline) { try await harness.client.today() }
        harness.everything(.init(status: 200, body: Data("not json".utf8)))
        await #expect(throws: PublicDataError.invalidData) { try await harness.client.today() }
    }

    @Test func revalidatesWithTheETagAndKeepsTheCachedCopy() async throws {
        let harness = try Harness()
        let digest =
            #"{ "date": "2026-10-25", "events": [], "sources": [{ "id": "camara", "name": "Câmara", "url": null, "updatedAt": null }] }"#
        harness.reply(
            "today.json", digest, headers: ["ETag": "\"v1\"", "Content-Type": "application/json"])
        let first = try await harness.client.today()
        PublicDataStub.reply(
            .init(status: 304, headers: ["ETag": "\"v1\""]), to: "/api/v1/today.json",
            on: harness.host)
        let second = try await harness.client.today()
        #expect(first == second)
        let seen = PublicDataStub.seen(on: harness.host)
        #expect(seen.map(\.ifNoneMatch) == [nil, "\"v1\""])
    }

    @Test func fallsBackToTheCachedCopyWhenOffline() async throws {
        let harness = try Harness()
        harness.reply(
            "votes/recent.json", "[]",
            headers: ["ETag": "\"v2\"", "Content-Type": "application/json"])
        #expect(try await harness.client.recentVotes().isEmpty)
        PublicDataStub.reply(
            .init(failure: .notConnectedToInternet), to: "/api/v1/votes/recent.json",
            on: harness.host)
        #expect(try await harness.client.recentVotes().isEmpty)
        PublicDataStub.reply(.init(status: 502), to: "/api/v1/votes/recent.json", on: harness.host)
        #expect(try await harness.client.recentVotes().isEmpty)
    }

    @Test func buildsURLsUnderTheVersionFolder() throws {
        let client = PublicDataClient(
            baseURL: try #require(URL(string: "https://fiscal.byescaleira.com/api")))
        #expect(
            client.url(for: PublicDataPath.profile(slug: "lula")).absoluteString
                == "https://fiscal.byescaleira.com/api/v1/people/lula.json")
    }
}
