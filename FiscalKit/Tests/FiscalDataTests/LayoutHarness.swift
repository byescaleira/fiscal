import Foundation
import Testing

@testable import FiscalData

struct LayoutHarness {
    let data: String
    let client: PublicDataClient

    init() throws {
        data = PublicDataStub.makeHost()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PublicDataStub.self]
        configuration.urlCache = URLCache(
            memoryCapacity: 1_024 * 1_024, diskCapacity: 0, directory: nil)
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        client = PublicDataClient(
            dataURL: try #require(URL(string: "https://\(data)")),
            session: URLSession(configuration: configuration))
    }

    func onData(_ path: String, _ json: String, status: Int = 200) {
        PublicDataStub.reply(
            .init(status: status, body: Data(json.utf8)), to: "/v2/\(path)", on: data)
    }

    func onData(_ path: String, _ reply: PublicDataStub.Reply) {
        PublicDataStub.reply(reply, to: "/v2/\(path)", on: data)
    }

    var dataPaths: [String] { PublicDataStub.seen(on: data).map(\.path) }
}
