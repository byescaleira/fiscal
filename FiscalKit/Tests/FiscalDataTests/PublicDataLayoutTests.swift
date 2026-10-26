import FiscalDomain
import Foundation
import Testing

@testable import FiscalData

struct PublicDataLayoutTests {
    private static let city =
        #"{ "code": "1200708", "name": "Xapuri", "uf": "ac", "note": null, "sources": [], "groups": [{ "level": "city", "office": "mayor", "title": "Prefeitura", "people": [{ "slug": "maxsuel-maia-xapuri-ac", "name": "Maxsuel Maia", "office": "mayor", "uf": "ac", "party": "PP", "photo": null, "status": "inOffice" }] }] }"#

    private struct Harness {
        let data: String
        let api: String
        let client: PublicDataClient

        init() throws {
            data = PublicDataStub.makeHost()
            api = PublicDataStub.makeHost()
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [PublicDataStub.self]
            configuration.urlCache = URLCache(
                memoryCapacity: 1_024 * 1_024, diskCapacity: 0, directory: nil)
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            client = PublicDataClient(
                baseURL: try #require(URL(string: "https://\(api)/api")),
                dataURL: URL(string: "https://\(data)"),
                session: URLSession(configuration: configuration))
        }

        func onData(_ path: String, _ json: String, status: Int = 200) {
            PublicDataStub.reply(
                .init(status: status, body: Data(json.utf8)), to: "/v2/\(path)", on: data)
        }

        func onAPI(_ path: String, _ json: String) {
            PublicDataStub.reply(
                .init(status: 200, body: Data(json.utf8)), to: "/api/v1/\(path)", on: api)
        }

        func live() {
            onData("release.json", #"{ "release": "20261026T093000Z-camara", "layout": "v2" }"#)
        }

        var dataPaths: [String] { PublicDataStub.seen(on: data).map(\.path) }
        var apiPaths: [String] { PublicDataStub.seen(on: api).map(\.path) }
    }

    @Test func bucketsMatchTheServer() {
        #expect(PublicDataLayout.voteBundles.bucket("camara-2416587") == "111")
        #expect(PublicDataLayout.voteBundles.bucket("senado-7106") == "01d")
        #expect(PublicDataLayout.cityPeopleIndex.bucket("vereador-b") == "0e")
    }

    @Test func locatesEveryContractPath() {
        #expect(PublicDataLayout.locate("meta.json") == .file("meta.json"))
        #expect(PublicDataLayout.locate("votes/recent.json") == .file("votes/recent.json"))
        #expect(PublicDataLayout.locate("people/lula.json") == .profile("lula"))
        #expect(
            PublicDataLayout.locate("people/lula/votes-2026.json")
                == .member("people/lula.json", ["files", "votes-2026.json"]))
        #expect(
            PublicDataLayout.locate("places/city/1200708.json")
                == .member("places/city/1200708.json", ["place"]))
        #expect(PublicDataLayout.locate("places/ac.json") == .file("places/ac.json"))
        #expect(
            PublicDataLayout.locate("votes/senado-7106.json")
                == .member("votes/by-id/01d.json", ["items", "senado-7106"]))
    }

    @Test func readsTheGroupedFilesWhenTheReleaseIsLive() async throws {
        let harness = try Harness()
        harness.live()
        harness.onData("places/city/1200708.json", #"{ "place": \#(Self.city), "people": {} }"#)
        harness.onData(
            "people/lula.json",
            #"{ "profile": null, "files": { "votes-2026.json": { "items": [], "total": 0 } } }"#)
        let city = try #require(try await harness.client.cityRepresentatives(code: "1200708"))
        #expect(city.name == "Xapuri")
        let votes = try await harness.client.votes(slug: "lula", year: 2_026)
        #expect(votes.items.isEmpty)
        await #expect(throws: PublicDataError.notFound) {
            try await harness.client.proposals(slug: "lula", year: 2_026)
        }
        #expect(harness.apiPaths.isEmpty)
        #expect(harness.dataPaths.filter { $0 == "/v2/people/lula.json" }.count == 1)
    }

    @Test func findsACityOfficialThroughTheIndex() async throws {
        let harness = try Harness()
        harness.live()
        let slug = "maxsuel-maia-xapuri-ac"
        let bucket = PublicDataLayout.cityPeopleIndex.bucket(slug)
        harness.onData(
            "index/city-people/\(bucket).json", #"{ "items": { "\#(slug)": "1200708" } }"#)
        harness.onData(
            "places/city/1200708.json",
            #"{ "place": \#(Self.city), "people": { "\#(slug)": { "unexpected": true } } }"#)
        await #expect(throws: PublicDataError.invalidData) {
            try await harness.client.profile(slug: slug)
        }
        #expect(
            harness.dataPaths.suffix(3) == [
                "/v2/people/\(slug).json", "/v2/index/city-people/\(bucket).json",
                "/v2/places/city/1200708.json",
            ])
    }

    @Test func fallsBackToTheCurrentServerUntilTheReleaseIsLive() async throws {
        let harness = try Harness()
        harness.onData("release.json", "{}", status: 404)
        harness.onAPI("today.json", #"{ "date": "2026-10-26", "events": [], "sources": [] }"#)
        let today = try await harness.client.today()
        #expect(today.events.isEmpty)
        #expect(harness.apiPaths == ["/api/v1/today.json"])
        #expect(harness.dataPaths == ["/v2/release.json"])
    }

    @Test func fallsBackWhenTheCDNIsDown() async throws {
        let harness = try Harness()
        harness.live()
        PublicDataStub.reply(.init(status: 503), to: "/v2/today.json", on: harness.data)
        harness.onAPI("today.json", #"{ "date": "2026-10-26", "events": [], "sources": [] }"#)
        #expect(try await harness.client.today().events.isEmpty)
        #expect(harness.apiPaths == ["/api/v1/today.json"])
    }
}
