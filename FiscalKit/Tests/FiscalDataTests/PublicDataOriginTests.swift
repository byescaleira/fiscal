import FiscalDomain
import Foundation
import Testing

@testable import FiscalData

struct PublicDataOriginTests {
    private static func digest(_ date: String) -> String {
        #"{ "date": "\#(date)", "events": [], "sources": [] }"#
    }

    private static func tagged(_ date: String) -> PublicDataStub.Reply {
        PublicDataStub.Reply(
            body: Data(digest(date).utf8),
            headers: ["ETag": "\"\(date)\"", "Content-Type": "application/json"])
    }

    private static let city =
        #"{ "code": "1200708", "name": "Xapuri", "uf": "ac", "note": null, "sources": [], "groups": [] }"#

    @Test func readsFirstOnlyTheListedFilesAndCoversMissingByPrefix() {
        let origin = PublicDataOrigin(
            first: ["today.json", "votes/recent.json"], onMissing: ["votes/"])
        #expect(origin.readsFirst("today.json"))
        #expect(origin.readsFirst("votes/recent.json"))
        #expect(!origin.readsFirst("agenda/today.json"))
        #expect(!origin.readsFirst("votes/recent.json.bak"))
        #expect(origin.coversMissing("votes/camara-2416587.json"))
        #expect(!origin.coversMissing("people/lula.json"))
        #expect(!origin.coversMissing("index/votes/recent.json"))
    }

    @Test func theOriginGetsAShortTimeout() {
        #expect(PublicDataClient.OriginRead.strict.timeout == 6)
        #expect(PublicDataClient.OriginRead.network.timeout == 20)
    }

    @Test func readsTheHotFilesFromTheOriginFirst() async throws {
        let harness = try LayoutHarness()
        harness.live(first: ["today.json"], onMissing: [])
        harness.onAPI("today.json", Self.digest("2026-10-26"))
        harness.onData("today.json", Self.digest("2026-10-25"))
        #expect(try await harness.client.today().date == CalendarDay("2026-10-26"))
        #expect(harness.apiPaths == ["/api/v1/today.json"])
        #expect(harness.dataPaths == ["/v2/release.json"])
    }

    @Test func readsTheOtherFilesFromPages() async throws {
        let harness = try LayoutHarness()
        harness.live(first: ["today.json"], onMissing: [])
        harness.onData("agenda/today.json", #"{ "date": "2026-10-26", "houses": [] }"#)
        #expect(try await harness.client.agenda().houses.isEmpty)
        #expect(harness.apiPaths.isEmpty)
    }

    @Test(arguments: [
        PublicDataStub.Reply(status: 503), PublicDataStub.Reply(failure: .cannotConnectToHost),
    ])
    func fallsBackToPagesInsteadOfTheCachedOriginCopy(outage: PublicDataStub.Reply)
        async throws
    {
        let harness = try LayoutHarness()
        harness.live(first: ["today.json"], onMissing: [])
        harness.onAPI("today.json", Self.tagged("2026-10-24"))
        #expect(try await harness.client.today().date == CalendarDay("2026-10-24"))
        harness.onAPI("today.json", outage)
        harness.onData("today.json", Self.digest("2026-10-26"))
        #expect(try await harness.client.today().date == CalendarDay("2026-10-26"))
        #expect(harness.apiPaths == ["/api/v1/today.json", "/api/v1/today.json"])
        #expect(harness.dataPaths.last == "/v2/today.json")
    }

    @Test func usesTheCachedOriginCopyOnlyAfterPagesFails() async throws {
        let harness = try LayoutHarness()
        harness.live(first: ["today.json"], onMissing: [])
        harness.onAPI("today.json", Self.tagged("2026-10-24"))
        #expect(try await harness.client.today().date == CalendarDay("2026-10-24"))
        harness.onAPI("today.json", .init(status: 502))
        harness.onData("today.json", .init(status: 503))
        #expect(try await harness.client.today().date == CalendarDay("2026-10-24"))
        #expect(harness.apiPaths.count == 2)
        #expect(harness.dataPaths.last == "/v2/today.json")
    }

    @Test func failsWhenTheOriginAndPagesAreDownWithoutACopy() async throws {
        let harness = try LayoutHarness()
        harness.live(first: ["today.json"], onMissing: [])
        harness.onAPI("today.json", .init(status: 503))
        harness.onData("today.json", .init(status: 503))
        await #expect(throws: PublicDataError.unavailable) { try await harness.client.today() }
        #expect(harness.apiPaths == ["/api/v1/today.json"])
    }

    @Test func readsAFileMissingOnPagesFromTheOrigin() async throws {
        let harness = try LayoutHarness()
        harness.live(first: [], onMissing: ["places/city/"])
        harness.onData("places/city/1200708.json", "{}", status: 404)
        harness.onAPI("places/city/1200708.json", Self.city)
        let city = try #require(try await harness.client.cityRepresentatives(code: "1200708"))
        #expect(city.name == "Xapuri")
        #expect(harness.apiPaths == ["/api/v1/places/city/1200708.json"])
        #expect(harness.dataPaths.last == "/v2/places/city/1200708.json")
    }

    @Test func leavesAFileMissingOnPagesOutsideTheCoveredPrefixes() async throws {
        let harness = try LayoutHarness()
        harness.live(first: [], onMissing: ["votes/"])
        harness.onData("places/city/1200708.json", "{}", status: 404)
        harness.onAPI("places/city/1200708.json", Self.city)
        #expect(try await harness.client.cityRepresentatives(code: "1200708") == nil)
        #expect(harness.apiPaths.isEmpty)
    }
}
