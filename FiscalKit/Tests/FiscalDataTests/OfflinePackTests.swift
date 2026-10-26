import FiscalDomain
import Foundation
import Testing

@testable import FiscalData

struct OfflinePackTests {
    private static let today = #"{ "date": "2026-10-26", "events": [], "sources": [] }"#
    private static let state =
        #"{ "uf": "sp", "name": "São Paulo", "sources": [], "groups": [{ "level": "state", "office": "federalDeputy", "title": "Deputados federais", "people": [{ "slug": "deputada", "name": "Deputada", "office": "federalDeputy", "uf": "sp", "party": "PT", "photo": null, "status": "inOffice" }] }, { "level": "state", "office": "senator", "title": "Senadores", "people": [{ "slug": "senadora", "name": "Senadora", "office": "senator", "uf": "sp", "party": "PL", "photo": null, "status": "inOffice" }] }, { "level": "state", "office": "governor", "title": "Governador", "people": [{ "slug": "governador", "name": "Governador", "office": "governor", "uf": "sp", "party": "REPUBLICANOS", "photo": null, "status": "inOffice" }] }] }"#

    private struct Harness {
        let host: String
        let directory: URL
        let store: OfflinePackStore
        let updater: OfflinePackUpdater
        let session: URLSession

        init() throws {
            host = PublicDataStub.makeHost()
            directory = FileManager.default.temporaryDirectory
                .appending(
                    path: "OfflinePackTests-\(UUID().uuidString)", directoryHint: .isDirectory)
            store = OfflinePackStore(directory: directory)
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [PublicDataStub.self]
            configuration.urlCache = nil
            session = URLSession(configuration: configuration)
            updater = OfflinePackUpdater(
                dataURL: try #require(URL(string: "https://\(host)")), session: session,
                store: store, now: { Date(timeIntervalSince1970: 1_793_000_000) })
        }

        func on(_ path: String, _ json: String, status: Int = 200, etag: String? = nil) {
            PublicDataStub.reply(
                .init(
                    status: status, body: Data(json.utf8),
                    headers: etag.map { ["ETag": $0] } ?? [:]),
                to: "/v2/\(path)", on: host)
        }

        func release(_ name: String) {
            on("release.json", #"{ "release": "\#(name)", "layout": "v2" }"#)
        }

        func publishBasics() {
            release("r1")
            on("today.json", OfflinePackTests.today, etag: "\"today-1\"")
            on("places/sp.json", OfflinePackTests.state, etag: "\"sp-1\"")
            for slug in ["senadora", "governador", "seguida", "apoiada"] {
                on("people/\(slug).json", #"{ "profile": null, "files": {} }"#, etag: "\"\(slug)\"")
            }
        }

        var seen: [PublicDataStub.Seen] { PublicDataStub.seen(on: host) }
        var paths: [String] { seen.map(\.path) }
    }

    @Test func plansTheRegionFromTheChosenPlace() {
        #expect(OfflinePackPlan.regionFiles(placeCode: nil).isEmpty)
        #expect(OfflinePackPlan.regionFiles(placeCode: "SP") == ["places/sp.json"])
        #expect(
            OfflinePackPlan.regionFiles(placeCode: "3550308")
                == ["places/sp.json", "places/city/3550308.json"])
        #expect(OfflinePackPlan.regionFiles(placeCode: "../etc").isEmpty)
    }

    @Test func picksTheExecutiveAndSenatorsBeforeAnyoneElse() throws {
        let place = try PublicDataCoding.decoder().decode(
            PlaceRepresentatives.self, from: Data(Self.state.utf8))
        #expect(OfflinePackPlan.representatives(in: [place]) == ["governador", "senadora"])
    }

    @Test func ordersPeopleAlphabeticallyWithoutRevealingSupportThenRepresentativesWithALimit() {
        let request = OfflinePackRequest(
            followed: ["seguida", "apoiada", "../segredo", "Maiuscula"], supported: ["apoiada"])
        #expect(
            OfflinePackPlan.people(for: request, representatives: ["governador", "seguida"])
                == ["apoiada", "seguida", "governador"])
        let crowd = OfflinePackRequest(followed: (0..<100).map { "pessoa-\($0)" })
        #expect(
            OfflinePackPlan.people(for: crowd, representatives: []).count
                == OfflinePackPlan.peopleLimit)
    }

    @Test func storesCompressedFilesOutsideBackupsAndReadsThemBack() async throws {
        let harness = try Harness()
        let json = Data(
            String(repeating: #"{ "slug": "pessoa", "name": "Pessoa" },"#, count: 200).utf8)
        try await harness.store.write(json, etag: "\"a\"", for: "index/people.json")
        #expect(await harness.store.data(for: "index/people.json") == json)
        let summary = await harness.store.summary()
        #expect(summary.files == 1)
        #expect(summary.originalBytes == json.count)
        #expect(summary.storedBytes < json.count)
        let values = try harness.directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
        let reopened = OfflinePackStore(directory: harness.directory)
        #expect(await reopened.data(for: "index/people.json") == json)
        await #expect(throws: PublicDataError.invalidData) {
            try await harness.store.write(json, etag: nil, for: "../fora.json")
        }
        await harness.store.erase()
        #expect(await harness.store.summary() == .empty)
        #expect(!FileManager.default.fileExists(atPath: harness.directory.path()))
    }

    @Test func downloadsTheMinimumSetForThePersonAndTheirRegion() async throws {
        let harness = try Harness()
        harness.publishBasics()
        let summary = try await harness.updater.refresh(
            OfflinePackRequest(followed: ["seguida"], supported: ["apoiada"], placeCode: "sp"))
        #expect(summary.people == 4)
        #expect(summary.files == 6)
        #expect(summary.updatedAt == Date(timeIntervalSince1970: 1_793_000_000))
        #expect(await harness.store.manifest.release == "r1")
        #expect(await harness.store.data(for: "people/apoiada.json") != nil)
        #expect(await harness.store.data(for: "people/deputada.json") == nil)
        let people = harness.paths.filter { $0.hasPrefix("/v2/people/") }
        #expect(
            people == [
                "/v2/people/apoiada.json", "/v2/people/seguida.json", "/v2/people/governador.json",
                "/v2/people/senadora.json",
            ])
    }

    @Test func skipsTheNetworkWhenTheReleaseDidNotChange() async throws {
        let harness = try Harness()
        harness.publishBasics()
        let request = OfflinePackRequest(followed: ["seguida"], placeCode: "sp")
        try await harness.updater.refresh(request)
        let before = harness.seen.count
        try await harness.updater.refresh(request)
        #expect(Array(harness.paths.dropFirst(before)) == ["/v2/release.json"])
    }

    @Test func revalidatesWithTheETagWhenTheReleaseChanges() async throws {
        let harness = try Harness()
        harness.publishBasics()
        let request = OfflinePackRequest(followed: ["seguida"], placeCode: "sp")
        try await harness.updater.refresh(request)
        let before = harness.seen.count
        harness.release("r2")
        harness.on("people/seguida.json", "", status: 304)
        harness.on("today.json", #"{ "date": "2026-10-27", "events": [], "sources": [] }"#)
        try await harness.updater.refresh(request)
        let again = harness.seen.dropFirst(before)
        let profile = try #require(again.first { $0.path == "/v2/people/seguida.json" })
        #expect(profile.ifNoneMatch == "\"seguida\"")
        let today = try #require(await harness.store.data(for: "today.json"))
        #expect(String(decoding: today, as: UTF8.self).contains("2026-10-27"))
        #expect(await harness.store.data(for: "people/seguida.json") != nil)
        #expect(await harness.store.manifest.release == "r2")
    }

    @Test func removesWhatIsNoLongerNeeded() async throws {
        let harness = try Harness()
        harness.publishBasics()
        try await harness.updater.refresh(
            OfflinePackRequest(followed: ["seguida"], supported: ["apoiada"]))
        #expect(await harness.store.data(for: "people/apoiada.json") != nil)
        let summary = try await harness.updater.refresh(
            OfflinePackRequest(followed: ["seguida"]))
        #expect(summary.people == 1)
        #expect(await harness.store.data(for: "people/apoiada.json") == nil)
        #expect(await harness.store.manifest.people == ["seguida"])
    }

    @Test func keepsThePackWhenTheConnectionDrops() async throws {
        let harness = try Harness()
        harness.publishBasics()
        let request = OfflinePackRequest(followed: ["seguida"], placeCode: "sp")
        let first = try await harness.updater.refresh(request)
        PublicDataStub.fallback(.init(failure: .notConnectedToInternet), on: harness.host)
        PublicDataStub.reply(
            .init(failure: .notConnectedToInternet), to: "/v2/release.json", on: harness.host)
        await #expect(throws: PublicDataError.offline) {
            try await harness.updater.refresh(request)
        }
        #expect(await harness.store.summary() == first)
        harness.release("r2")
        PublicDataStub.reply(
            .init(failure: .networkConnectionLost), to: "/v2/people/seguida.json",
            on: harness.host)
        await #expect(throws: PublicDataError.offline) {
            try await harness.updater.refresh(request)
        }
        #expect(await harness.store.data(for: "people/seguida.json") != nil)
        #expect(await harness.store.manifest.release == "r1")
    }

    @Test func savesACityOfficialThroughTheIndex() async throws {
        let harness = try Harness()
        harness.release("r1")
        let slug = "vereadora-xapuri-ac"
        let bucket = PublicDataLayout.cityPeopleIndex.bucket(slug)
        harness.on("index/city-people/\(bucket).json", #"{ "items": { "\#(slug)": "1200708" } }"#)
        harness.on("places/city/1200708.json", #"{ "place": null, "people": {} }"#)
        let summary = try await harness.updater.refresh(OfflinePackRequest(followed: [slug]))
        #expect(summary.people == 1)
        #expect(await harness.store.data(for: "places/city/1200708.json") != nil)
    }

    @Test func readsThePackWhenThereIsNoConnection() async throws {
        let harness = try Harness()
        harness.publishBasics()
        try await harness.updater.refresh(OfflinePackRequest())
        PublicDataStub.fallback(.init(failure: .notConnectedToInternet), on: harness.host)
        PublicDataStub.reply(
            .init(failure: .notConnectedToInternet), to: "/v2/release.json", on: harness.host)
        PublicDataStub.reply(
            .init(failure: .notConnectedToInternet), to: "/v2/today.json", on: harness.host)
        let api = PublicDataStub.makeHost()
        PublicDataStub.fallback(.init(failure: .notConnectedToInternet), on: api)
        let notice = OfflineNotice()
        let client = PublicDataClient(
            baseURL: try #require(URL(string: "https://\(api)/api")),
            dataURL: URL(string: "https://\(harness.host)"), session: harness.session,
            offline: harness.store, notice: notice)
        let today = try await client.today()
        #expect(today.events.isEmpty)
        #expect(notice.state == .offline(Date(timeIntervalSince1970: 1_793_000_000)))
        await #expect(throws: PublicDataError.offline) { try await client.money() }
        await #expect(throws: PublicDataError.offline) { try await client.profile(slug: "ninguem") }
    }

    @Test func showsTheOldestSavedDateUntilTheConnectionReturns() {
        let notice = OfflineNotice()
        let older = Date(timeIntervalSince1970: 1_000)
        let newer = Date(timeIntervalSince1970: 2_000)
        notice.markOffline(dataFrom: newer)
        notice.markOffline(dataFrom: older)
        notice.markOffline(dataFrom: newer)
        #expect(notice.state == .offline(older))
        notice.markOnline()
        #expect(notice.state == .online)
    }

    @Test func refreshesOnOpenOnlyAfterTheInterval() async throws {
        let harness = try Harness()
        harness.publishBasics()
        let coordinator = OfflinePackCoordinator(updater: harness.updater) { OfflinePackRequest() }
        await coordinator.refreshIfDue(every: 600)
        await coordinator.refreshIfDue(every: 600)
        #expect(harness.paths.filter { $0 == "/v2/release.json" }.count == 1)
        #expect(await coordinator.erase() == .empty)
    }
}
