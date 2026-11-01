import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import SwiftUI
import Testing

@testable import FeatureShare

enum ShareFixtures {
    static let now = Date(timeIntervalSince1970: 1_792_917_720)

    static let investigation = InvestigationSummary(
        id: "case", question: "Who attended the most?", conclusion: "Ana attended 92% of sessions.",
        numbers: [.init(value: "92%", label: "Attendance"), .init(value: "87", label: "Bills")],
        faces: [.init(slug: "ana-souza", name: "Ana Souza", party: "PSD")], compared: nil,
        uncertainty: "Sessions of 2026 only.", sources: ["Chamber"], updatedAt: now)

    static func person(_ slug: String, _ name: String) -> FollowedPerson {
        FollowedPerson(
            card: PersonCard(
                slug: slug, name: name, office: .federalDeputy, uf: "sp", party: "PSD", photo: nil,
                status: .inOffice),
            followedAt: now)
    }

    @MainActor
    static func follows(_ people: [FollowedPerson]) async throws -> any FollowRepository {
        let repository = try FiscalDatabase.open(inMemory: true).repositories.follows
        for person in people { try await repository.follow(person.card, at: person.followedAt) }
        return repository
    }

    @MainActor
    static func subjects() async throws -> [ShareSubject] {
        let service = ShowcasePublicData(scenario: .normal, now: now)
        let highlight = try #require(try await service.highlights()?.items.first?.id)
        return [
            .person(slug: "tabata-amaral"), .person(slug: "tarcisio-de-freitas"),
            .vote(id: "camara-18732026"), .expenses(slug: "nikolas-ferreira", year: 2026),
            .compare(slugs: ["kim-kataguiri", "erika-hilton"]), .representatives(uf: "sp"),
            .race(id: "presidente-br"), .highlight(id: highlight),
            .investigation(investigation), .following,
        ]
    }

    @MainActor
    static func model(
        _ subject: ShareSubject, lens: (any LensRepository)? = nil,
        follows: (any FollowRepository)? = nil
    ) -> ShareModel {
        ShareModel(
            subject: subject, service: ShowcasePublicData(scenario: .normal, now: now),
            races: ShowcaseLiveResults(scenario: .finished), lens: lens, follows: follows)
    }
}

@MainActor
struct ShareStyleTests {
    @Test func everySubjectFitsEveryStyleAndFormat() async throws {
        let follows = try await ShareFixtures.follows([
            ShareFixtures.person("ana-souza", "Ana Souza"),
            ShareFixtures.person("bia-lima", "Bia Lima"),
        ])
        for subject in try await ShareFixtures.subjects() {
            let model = ShareFixtures.model(subject, follows: follows)
            await model.load()
            #expect(model.phase == .loaded, "\(subject)")
            for style in ShareStyle.allCases {
                model.style = style
                for format in FeatureShare.ShareFormat.allCases {
                    model.format = format
                    let card = try #require(model.card, "\(subject)")
                    #expect(card.style == style)
                    #expect(card.texts.contains(ShareCardBuilder.host))
                    #expect(card.texts.contains(card.brand))
                    #expect(card.texts.contains(card.content.source))
                    let image = try #require(
                        ShareRenderer.render(card, code: model.code, scale: 1),
                        "\(subject) \(style) \(format)")
                    #expect(!image.png.isEmpty)
                }
            }
        }
    }

    @Test func onlyThePosterCarriesTheArt() async throws {
        let model = ShareFixtures.model(.person(slug: "tabata-amaral"))
        await model.load()
        #expect(model.usesArt)
        #expect(model.card?.artwork != nil)
        for style in [ShareStyle.typographic, .data] {
            model.style = style
            #expect(!model.usesArt)
            #expect(model.card?.artwork == nil)
        }
    }

    @Test func theStatementLeadsWithTheFirstFigureShown() throws {
        let face = ShareFace(slug: "ana", name: "Ana", party: "PSD", detail: "SP")
        let content = ShareCardContent(
            eyebrow: "E", headline: nil, faces: [face],
            body: .person([
                ShareMetric(label: "Votes", value: PublicFormat.missing),
                ShareMetric(label: "Bills", value: "87"),
            ]),
            source: "Source", stamp: "S", link: URL(fileURLWithPath: "/"))
        let statement = ShareStatement(content)
        #expect(statement.figure == "87")
        #expect(statement.caption == "Bills")
        #expect(statement.person == face)
        let board = ShareBoard(content)
        #expect(board.texts.contains(PublicFormat.missing))
        #expect(board.texts.contains("87"))
    }

    @Test func numbersCountUpToTheExactFinalText() {
        #expect(ShareMotion.countUp("92%", progress: 1) == "92%")
        #expect(ShareMotion.countUp("R$ 1,2 mi", progress: 1) == "R$ 1,2 mi")
        #expect(ShareMotion.countUp("92%", progress: 0) == "0%")
        #expect(ShareMotion.countUp("1.234", progress: 0) == "0")
        #expect(ShareMotion.countUp("R$ 1,2 mi", progress: 0) == "R$ 0,0 mi")
        #expect(ShareMotion.countUp("412 × 61", progress: 0) == "0 × 0")
        #expect(ShareMotion.countUp(PublicFormat.missing, progress: 0) == PublicFormat.missing)
        #expect(ShareMotion.fill(0.5, progress: 1) == 0.5)
        #expect(ShareMotion.fill(0.5, progress: 0) == 0)
        #expect(ShareMotion.fill(2, progress: 1) == 1)
        #expect(ShareMotion.eased(0.5) > 0.5)
    }

    @Test func theFinalFrameIsStatic() {
        #expect(EnvironmentValues().shareProgress == 1)
    }
}
