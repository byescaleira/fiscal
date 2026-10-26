import Foundation
import Testing

@testable import FiscalData

struct LayoutHarness {
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

    func onData(_ path: String, _ reply: PublicDataStub.Reply) {
        PublicDataStub.reply(reply, to: "/v2/\(path)", on: data)
    }

    func onAPI(_ path: String, _ json: String) {
        PublicDataStub.reply(
            .init(status: 200, body: Data(json.utf8)), to: "/api/v1/\(path)", on: api)
    }

    func onAPI(_ path: String, _ reply: PublicDataStub.Reply) {
        PublicDataStub.reply(reply, to: "/api/v1/\(path)", on: api)
    }

    func live() {
        onData("release.json", #"{ "release": "20261026T093000Z-camara", "layout": "v2" }"#)
    }

    func live(first: [String], onMissing: [String]) {
        let list = { (paths: [String]) in paths.map { "\"\($0)\"" }.joined(separator: ", ") }
        onData(
            "release.json",
            #"{ "release": "20261026T093000Z-camara", "layout": "v2", "origin": { "first": [\#(list(first))], "onMissing": [\#(list(onMissing))] } }"#
        )
    }

    var dataPaths: [String] { PublicDataStub.seen(on: data).map(\.path) }
    var apiPaths: [String] { PublicDataStub.seen(on: api).map(\.path) }
}
