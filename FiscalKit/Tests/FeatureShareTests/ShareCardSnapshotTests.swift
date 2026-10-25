import CoreGraphics
import FeatureCore
import FiscalData
import FiscalDomain
import FiscalResource
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import FeatureShare

enum ShareSnapshotFolder {
    static let path = ProcessInfo.processInfo.environment["FISCAL_SHARE_SNAPSHOTS"]
    static let prefix =
        ProcessInfo.processInfo.environment["FISCAL_SHARE_SNAPSHOTS_PREFIX"] ?? "after"
}

@MainActor
struct ShareCardSnapshotTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private var subjects: [(String, ShareSubject)] {
        [
            ("person", .person(slug: "tabata-amaral")),
            ("person-executive", .person(slug: "tarcisio-de-freitas")),
            ("vote", .vote(id: "camara-18732026")),
            ("expenses", .expenses(slug: "nikolas-ferreira", year: 2026)),
            ("compare", .compare(slugs: ["kim-kataguiri", "erika-hilton"])),
            ("representatives", .representatives(uf: "sp")),
            ("race", .race(id: "presidente-br")),
        ]
    }

    @Test(.enabled(if: ShareSnapshotFolder.path != nil)) func rendersEveryCardToDisk() async throws
    {
        let folder = URL(fileURLWithPath: try #require(ShareSnapshotFolder.path), isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, subject) in subjects {
            let model = ShareModel(
                subject: subject, service: ShowcasePublicData(scenario: .normal, now: now),
                races: ShowcaseLiveResults(scenario: .finished))
            await model.load()
            for format in ShareFormat.allCases {
                model.format = format
                try write(
                    model,
                    to: folder.appending(
                        path: "\(ShareSnapshotFolder.prefix)-\(name)-\(format).png"))
            }
            if name == "person" || name == "vote" {
                let historical = try #require(
                    model.works.first { $0.collection == "acervo-historico" })
                model.select(historical)
                for format in ShareFormat.allCases {
                    model.format = format
                    try write(
                        model,
                        to: folder.appending(
                            path: "\(ShareSnapshotFolder.prefix)-\(name)-\(format)-historical.png")
                    )
                }
            }
        }
    }

    private func write(_ model: ShareModel, to url: URL) throws {
        let card = try #require(model.card)
        let image = try #require(ShareRenderer.render(card, code: model.code, scale: 3))
        let destination = try #require(
            CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }
}
