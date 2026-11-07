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
        _ subject: ShareSubject, follows: (any FollowRepository)? = nil
    ) -> ShareModel {
        ShareModel(
            subject: subject, service: ShowcasePublicData(scenario: .normal, now: now),
            races: ShowcaseLiveResults(scenario: .finished), follows: follows)
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
        model.style = .poster
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
        let published = try #require(content.published)
        let statement = ShareStatement(published)
        #expect(statement.figure == "87")
        #expect(statement.caption == "Bills")
        #expect(statement.person == face)
        let board = ShareBoard(published)
        #expect(board.texts.contains("87"))
    }

    @Test func theVideoSettlesOnTheRealNumbers() async throws {
        let subjects: [ShareSubject] = [
            .person(slug: "tabata-amaral"), .compare(slugs: ["kim-kataguiri", "erika-hilton"]),
            .vote(id: "camara-18732026"),
        ]
        for subject in subjects {
            let model = ShareFixtures.model(subject)
            await model.load()
            model.format = .stories
            for style in [ShareStyle.typographic, .data] {
                let card = try #require(model.card(style: style))
                let settled = try #require(
                    Pixels(card: card, code: model.code, progress: ShareMotion.settled))
                let last = try #require(Pixels(card: card, code: model.code, progress: 1))
                #expect(settled.differingRows(from: last) == 0, "\(subject) \(style)")
            }
        }
    }

    @Test func numbersRollAndTheFirstFrameHasNone() {
        #expect(ShareMotion.figureOpacity(0) == 0)
        #expect(ShareMotion.figureOpacity(ShareMotion.settled) == 1)
        #expect(ShareMotion.rolled("92%", progress: ShareMotion.settled) == "92%")
        #expect(ShareMotion.rolled("R$ 1,2 mi", progress: 1) == "R$ 1,2 mi")
        #expect(ShareMotion.rolled("92%", progress: ShareMotion.rollStart) == "0%")
        #expect(ShareMotion.rolled("412 × 61", progress: ShareMotion.rollStart) == "0 × 0")
        #expect(ShareMotion.rolled("1.234", progress: ShareMotion.rollStart) == "0")
        #expect(ShareMotion.rolled("06/01/2027", progress: ShareMotion.rollStart) == "06/01/2027")
        #expect(ShareMotion.stage(8, progress: ShareMotion.settled) == 1)
        #expect(ShareMotion.fill(0.5, progress: ShareMotion.settled) == 0.5)
        #expect(ShareMotion.fill(0.5, progress: 0) == 0)
    }

    @Test func theDuelIsOnlyForTwoSides() async throws {
        let compare = ShareFixtures.model(.compare(slugs: ["kim-kataguiri", "erika-hilton"]))
        await compare.load()
        let duel = try #require(compare.card(style: .data)?.duel)
        #expect(duel.left.name != duel.right.name)
        #expect(duel.criterion?.isEmpty == false)
        let person = ShareFixtures.model(.person(slug: "tabata-amaral"))
        await person.load()
        #expect(person.card(style: .data)?.duel == nil)
    }

    @Test func theFinalFrameIsStatic() {
        #expect(EnvironmentValues().shareProgress == 1)
    }
}
