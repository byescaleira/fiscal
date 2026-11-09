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
        _ subject: ShareSubject, scenario: PublicDataScenario = .normal
    ) -> ShareModel {
        ShareModel(
            subject: subject, service: ShowcasePublicData(scenario: scenario, now: now),
            races: ShowcaseLiveResults(scenario: .finished))
    }

    @Test func everyArtCardCarriesTheCreditInEveryFormat() async throws {
        for subject in subjects {
            let model = model(subject)
            await model.load()
            model.style = .poster
            #expect(model.phase == .loaded, "\(subject)")
            let work = try #require(model.artwork?.work)
            for format in FeatureShare.ShareFormat.allCases {
                model.format = format
                let card = try #require(model.card)
                #expect(card.texts.contains(ShareCardBuilder.host))
                #expect(!card.content.source.isEmpty)
                let credit = try #require(card.artwork?.credit, "\(subject)")
                #expect(card.texts.contains(credit))
                for part in [work.artist, work.title, work.year] {
                    #expect(credit.contains(part))
                }
            }
        }
    }

    @Test func theGalleryOpensInTheDefaultOrder() async throws {
        let model = model(.person(slug: "lula"))
        await model.load()
        let catalog = try #require(model.catalog)
        #expect(model.collections == catalog.collections)
        #expect(ShareModel.defaultCollection == "brasil-agora")
        #expect(model.artwork?.work.collection == ShareModel.defaultCollection)
        #expect(model.currentCollectionID == ShareModel.defaultCollection)
    }

    @Test func pickingAnotherWorkKeepsTheCreditInStep() async throws {
        let model = model(.vote(id: "camara-18732026"))
        await model.load()
        model.style = .poster
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

    @Test func theModelRendersTheCardAndPicksTheArtShelf() async throws {
        let model = model(.vote(id: "camara-18732026"))
        await model.load()
        #expect(model.rendered == nil)
        model.render(scale: 1)
        let rendered = try #require(model.rendered)
        #expect(!rendered.file.png.isEmpty)
        #expect(rendered.file.fileName == ShareRenderer.fileName(for: try #require(model.content)))
        let other = try #require(
            model.collections.first { $0.id != model.currentCollectionID })
        model.show(other.id)
        #expect(model.currentCollectionID == other.id)
        #expect(model.currentWorks.allSatisfy { $0.collection == other.id })
        #expect(model.selectedCredit?.contains(model.selectedWork?.artist ?? "-") == true)
    }

    @Test func followingCardListsUpToSixAlphabetically() async throws {
        let names = ["Zeca", "Bia", "Ana", "Hugo", "Davi", "Caio", "Eva", "Gil"]
        let follows = try await ShareFixtures.follows(
            names.map { ShareFixtures.person($0.lowercased(), $0) })
        let model = ShareFixtures.model(.following, follows: follows)
        await model.load()
        #expect(model.phase == .loaded)
        let content = try #require(model.content)
        guard case .following(let faces) = content.body else {
            Issue.record("Wrong body")
            return
        }
        #expect(faces.map(\.name) == ["Ana", "Bia", "Caio", "Davi", "Eva", "Gil"])
        #expect(faces.allSatisfy { !$0.party.isEmpty && !$0.detail.isEmpty })
        let text = (model.card?.texts ?? []).joined(separator: " ")
        for name in ["Hugo", "Zeca"] {
            #expect(!text.contains(name))
            #expect(!model.caption.contains(name))
        }
        #expect(content.stamp.contains("·SEG·LISTA·"))
    }

    @Test func followingNeedsSomeoneToShow() async throws {
        let empty = ShareFixtures.model(.following, follows: try await ShareFixtures.follows([]))
        await empty.load()
        #expect(empty.phase == .failed(.notFound))
        let missing = ShareFixtures.model(.following)
        await missing.load()
        #expect(missing.phase == .failed(.unavailable))
    }

    @Test func longNamesStillLoad() async {
        let model = model(
            .person(slug: "maria-da-conceicao-albuquerque"), scenario: .longNames)
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.card?.content.faces.first?.name.count ?? 0 > 30)
    }

    @Test func theCardShowsTheMedianInsteadOfAVerdict() async throws {
        let service = ShowcasePublicData(scenario: .normal, now: ShareFixtures.now)
        let profile = try await service.profile(slug: "tabata-amaral")
        let classification = try #require(profile.classification)
        let model = ShareModel(subject: .person(slug: "tabata-amaral"), service: service)
        await model.load()
        let content = try #require(model.content)
        guard case .person(let metrics) = content.body else {
            Issue.record("expected a person card")
            return
        }
        #expect(metrics.first?.peer == classification.medianText(.presence))
        let bands: [PeerClassification.Band] = [.better, .worse, .more, .less, .average]
        for style in ShareStyle.allCases {
            let texts = try #require(model.card(style: style)).texts + [model.caption]
            for band in bands {
                #expect(!texts.contains { $0.contains(band.title) }, "\(style) \(band)")
            }
        }
    }
}
