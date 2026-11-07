import Testing

@testable import FeatureShare

@MainActor
struct ShareFlowStyleTests {
    @Test func defaultStyleFollowsTheSubject() async throws {
        let person = ShareFixtures.model(.person(slug: "tabata-amaral"))
        await person.load()
        #expect(person.style == .typographic)
        #expect(person.styles == [.typographic, .data, .poster])
        let compare = ShareFixtures.model(.compare(slugs: ["kim-kataguiri", "erika-hilton"]))
        await compare.load()
        #expect(compare.style == .data)
        #expect(compare.styles == [.data, .typographic, .poster])
        let investigation = ShareFixtures.model(.investigation(ShareFixtures.investigation))
        await investigation.load()
        #expect(investigation.style == .typographic)
    }

    @Test func aChosenStyleSurvivesAReload() async {
        let model = ShareFixtures.model(.person(slug: "tabata-amaral"))
        await model.load()
        model.style = .data
        await model.load()
        #expect(model.style == .data)
    }

    @Test func storyColorsFollowTheStyle() async throws {
        let model = ShareFixtures.model(.person(slug: "tabata-amaral"))
        await model.load()
        for style in ShareStyle.allCases {
            let colors = try #require(model.card(style: style)?.storyColors)
            #expect(colors.top == style.storyField)
            #expect(colors.bottom == style.storyField)
        }
        #expect(ShareStyle.typographic.storyField != ShareStyle.data.storyField)
    }

    @Test func theCardTakesThePartiesOfTheSubject() async throws {
        let person = ShareFixtures.model(.person(slug: "tabata-amaral"))
        await person.load()
        let face = try #require(person.content?.faces.first)
        #expect(person.content?.stageParties == [face.party])
        let compare = ShareFixtures.model(.compare(slugs: ["kim-kataguiri", "erika-hilton"]))
        await compare.load()
        #expect(compare.content?.stageParties.count == 2)
        let place = ShareFixtures.model(.representatives(uf: "sp"))
        await place.load()
        #expect(place.content?.stageParties.isEmpty == true)
    }

    @Test func theFreeZoneShowsFacesOrSharesAndNeverANumber() async throws {
        let person = ShareFixtures.model(.person(slug: "tabata-amaral"))
        await person.load()
        let face = try #require(person.content?.faces.first)
        #expect(person.content?.zoneContent == .faces([face]))
        let vote = ShareFixtures.model(.vote(id: "camara-18732026"))
        await vote.load()
        guard case .shares(let segments)? = vote.content?.zoneContent else {
            Issue.record("expected the vote shares")
            return
        }
        #expect(segments.count == 3)
        let place = ShareFixtures.model(.representatives(uf: "sp"))
        await place.load()
        #expect(place.content?.zoneContent == ShareZoneContent.none)
    }
}
