import FeatureCore
import FiscalData
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import Foundation
import SwiftUI
import Testing

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
            ("investigation", .investigation(ShareFixtures.investigation)),
            ("following", .following),
        ]
    }

    @Test(.enabled(if: ShareSnapshotFolder.path != nil)) func rendersEveryCardToDisk() async throws
    {
        EmphasisFont.register()
        let previousLanguage = LanguageSetting.shared.language
        FiscalLanguage.install()
        defer { LanguageSetting.shared.language = previousLanguage }
        let folder = URL(fileURLWithPath: try #require(ShareSnapshotFolder.path), isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let follows = try await ShareFixtures.follows([
            ShareFixtures.person("ana-souza", "Ana Souza"),
            ShareFixtures.person("bia-lima", "Bia Lima"),
            ShareFixtures.person("caio-reis", "Caio Reis"),
        ])
        let service = ShowcasePublicData(scenario: .normal, now: now)
        let highlight = try #require(try await service.highlights()?.items.first?.id)
        for (name, subject) in subjects + [("highlight", .highlight(id: highlight))] {
            let model = ShareModel(
                subject: subject, service: service,
                races: ShowcaseLiveResults(scenario: .finished), follows: follows)
            await model.load()
            for style in ShareStyle.allCases {
                model.style = style
                for format in FeatureShare.ShareFormat.allCases {
                    model.format = format
                    try write(
                        model,
                        to: folder.appending(
                            path: "\(ShareSnapshotFolder.prefix)-\(name)-\(style)-\(format).png"))
                }
            }
            if name == "person" || name == "vote" || name == "compare" {
                model.format = .stories
                for style in ShareStyle.allCases {
                    model.style = style
                    let card = try #require(model.card)
                    for percent in [0, 10, 20, 30, 40, 55] {
                        let frame = ShareRenderer.frame(
                            card, code: model.code, progress: Double(percent) / 100)
                        let renderer = ImageRenderer(
                            content: frame.frame(
                                width: card.format.size.width, height: card.format.size.height))
                        let image = try #require(renderer.uiImage?.pngData())
                        try image.write(
                            to: folder.appending(
                                path: "motion-\(name)-\(style)-\(1000 + percent).png"))
                    }
                }
            }
            model.style = .poster
            if name == "person" || name == "vote" {
                let historical = try #require(
                    model.works.first { $0.collection == "acervo-historico" })
                model.select(historical)
                for format in FeatureShare.ShareFormat.allCases {
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
        try image.png.write(to: url)
    }
}
