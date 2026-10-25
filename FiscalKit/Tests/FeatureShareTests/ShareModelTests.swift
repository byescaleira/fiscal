import FeatureCore
import FiscalData
import FiscalDomain
import FiscalResource
import Foundation
import Testing

@testable import FeatureShare

@MainActor
struct ShareModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private var subjects: [ShareSubject] {
        [
            .person(slug: "tabata-amaral"), .person(slug: "tarcisio-de-freitas"),
            .vote(id: "camara-18732026"), .expenses(slug: "nikolas-ferreira", year: 2026),
            .compare(slugs: ["kim-kataguiri", "erika-hilton"]), .representatives(uf: "sp"),
            .race(id: "presidente-br"),
        ]
    }

    private func model(
        _ subject: ShareSubject, scenario: PublicDataScenario = .normal,
        lens: (any LensRepository)? = nil
    ) -> ShareModel {
        ShareModel(
            subject: subject, service: ShowcasePublicData(scenario: scenario, now: now),
            races: ShowcaseLiveResults(scenario: .finished), lens: lens)
    }

    @Test func everyCardCarriesTheArtCreditInEveryFormat() async throws {
        for subject in subjects {
            let model = model(subject)
            await model.load()
            #expect(model.phase == .loaded, "\(subject)")
            let work = try #require(model.artwork?.work)
            for format in ShareFormat.allCases {
                model.format = format
                let card = try #require(model.card)
                let credit = try #require(card.artwork?.credit)
                #expect(card.texts.contains(credit))
                for part in [work.artist, work.title, work.year] {
                    #expect(credit.contains(part))
                }
                #expect(card.texts.contains(ShareCardBuilder.host))
                #expect(!card.content.source.isEmpty)
            }
        }
    }

    @Test func theCardNeverCarriesTheStance() async throws {
        var contents: [ShareSubject: ShareCardContent] = [:]
        for stance in PoliticalStance.allCases {
            let repositories = try FiscalDatabase.open(inMemory: true).repositories
            try await repositories.lens.save(
                Lens(
                    themes: [.health, .taxes, .security], stance: stance,
                    artCollection: "brasil-agora"))
            for subject in subjects {
                let model = model(subject, lens: repositories.lens)
                await model.load()
                #expect(model.badgeStance == stance)
                let card = try #require(model.card)
                let text = card.texts.joined(separator: "\n")
                #expect(!text.contains(stance.badge))
                #expect(!text.contains("Lens"))
                #expect(!card.accessibilityLabel.contains(stance.badge))
                #expect(!model.shareMessage.contains(stance.badge))
                if let previous = contents[subject] {
                    #expect(previous == card.content)
                }
                contents[subject] = card.content
            }
        }
    }

    @Test func theLensOnlyChangesTheArt() async throws {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        try await repositories.lens.save(
            Lens(
                themes: [.health, .taxes, .security], stance: .left,
                artCollection: "acervo-historico"))
        let adapted = model(.person(slug: "lula"), lens: repositories.lens)
        await adapted.load()
        let plain = model(.person(slug: "lula"))
        await plain.load()
        #expect(adapted.content == plain.content)
        #expect(adapted.artwork?.work.collection == "acervo-historico")
        #expect(adapted.collections.first?.id == "acervo-historico")
        #expect(plain.artwork?.work.collection == ShareModel.neutralCollection)
        #expect(plain.badgeStance == nil)
        #expect(adapted.isArtAdapted)
    }

    @Test func pickingAnotherWorkKeepsTheCreditInStep() async throws {
        let model = model(.vote(id: "camara-18732026"))
        await model.load()
        let other = try #require(model.works.last)
        model.select(other)
        #expect(model.isSelected(other))
        #expect(model.card?.artwork?.work == other)
        #expect(model.card?.texts.contains(ShareArtwork(work: other, palette: []).credit) == true)
    }

    @Test func theImageCarriesNoPortraitSoNoIllustrationMark() async throws {
        let person = model(.person(slug: "erika-hilton"))
        await person.load()
        let card = try #require(person.card)
        #expect(!card.texts.contains(String(appLocalized: "Illustration by Fiscal")))
        #expect(card.poster.person?.slug == "erika-hilton")
        let race = model(.race(id: "presidente-br"))
        await race.load()
        #expect(race.code != nil)
    }

    @Test func reportsWhyTheCardDidNotLoad() async {
        let offline = model(.person(slug: "lula"), scenario: .offline)
        await offline.load()
        #expect(offline.phase == .failed(.offline))
        let empty = model(.person(slug: "lula"), scenario: .empty)
        await empty.load()
        #expect(empty.phase == .failed(.notFound))
        let missing = ShareModel(subject: .vote(id: "x"), service: nil)
        await missing.load()
        #expect(missing.phase == .failed(.unavailable))
        let noRaces = ShareModel(subject: .race(id: "presidente-br"), service: nil)
        await noRaces.load()
        #expect(noRaces.phase == .failed(.unavailable))
        let unknownRace = model(.race(id: "nowhere"))
        await unknownRace.load()
        #expect(unknownRace.phase == .failed(.notFound))
    }

    @Test func longNamesStillLoad() async {
        let model = model(
            .person(slug: "maria-da-conceicao-albuquerque"), scenario: .longNames)
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.card?.content.faces.first?.name.count ?? 0 > 30)
    }
}
