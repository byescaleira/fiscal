import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureSearch

@MainActor
struct CompareModelTests {
    private let showcase = ShowcasePublicData(
        scenario: .normal, now: Date(timeIntervalSince1970: 1_792_917_720))

    @Test func comparesOnlyTwoOrThreePeople() async {
        #expect(CompareModel(slugs: []).isEmpty)
        #expect(CompareModel(slugs: ["tabata-amaral"]).phase == .loaded)
        let many = CompareModel(slugs: ["a", "b", "b", "c", "d"])
        #expect(many.slugs == ["a", "b", "c"])
        let model = CompareModel(slugs: ["tabata-amaral", "kim-kataguiri"], service: showcase)
        #expect(model.isEmpty)
        await model.load()
        #expect(!model.isEmpty)
        #expect(model.share == .share(.compare(slugs: ["tabata-amaral", "kim-kataguiri"])))
    }

    @Test func showsTheSameProfileNumbersInAlphabeticalColumns() async {
        let model = CompareModel(slugs: ["tabata-amaral", "kim-kataguiri"], service: showcase)
        await model.load()
        let table = model.table
        #expect(table.columns.map(\.name) == ["Kim Kataguiri", "Tabata Amaral"])
        #expect(table.groups.map(\.id) == ["office", "money", "election", "themes"])
        #expect(
            Array(table.metricIDs.prefix(8)) == [
                "attendance", "votes", "proposals", "laws", "quota", "assets", "campaign",
                "electionVotes",
            ])
        #expect(
            table.groups.allSatisfy { group in
                group.metrics.allSatisfy { $0.values.count == 2 }
            })
        #expect(model.sourceLine != nil)
    }

    @Test func barsAreProportionalWithoutAWinner() {
        #expect(CompareTable.fractions([50, 100, nil]) == [0.5, 1, nil])
        #expect(CompareTable.fractions([0, 0]) == [0, 0])
        #expect(CompareTable.fractions([nil, nil]) == [nil, nil])
    }

    @Test func missingDataIsADashAndNamedInTheFooter() async {
        let model = CompareModel(
            slugs: ["tarcisio-de-freitas", "jeronimo-rodrigues"], service: showcase)
        await model.load()
        let office = model.table.groups.first { $0.id == "office" }
        #expect(office?.metrics.isEmpty == true)
        #expect(office?.missing.count == 4)
        let money = model.table.groups.first { $0.id == "money" }
        let quota = money?.metrics.first { $0.id == "quota" }
        #expect(quota == nil)
        #expect(money?.missing.contains("Office allowance used") == true)
    }

    @Test func samePartyColumnsUseTheSecondColor() async {
        let model = CompareModel(
            slugs: ["lula", "humberto-costa", "fabiano-contarato"], service: showcase)
        await model.load()
        #expect(model.table.columns.map(\.usesSecondaryColor) == [false, true, false])
        #expect(model.table.columns.allSatisfy { $0.party == "PT" })
    }

    @Test func theLensPutsTheChosenTopicsFirst() async throws {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        let model = CompareModel(
            slugs: ["tabata-amaral", "kim-kataguiri"], service: showcase,
            lens: repositories.lens)
        await model.load()
        let plain = try #require(model.table.groups.first { $0.id == "themes" })
        #expect(!plain.isLensOrdered)
        let last = try #require(plain.metrics.last?.id)
        let theme = String(last.dropFirst("theme-".count))
        try await repositories.lens.save(
            Lens(themes: [try #require(Theme(rawValue: theme))], stance: .left))
        let adapted = CompareModel(
            slugs: ["tabata-amaral", "kim-kataguiri"], service: showcase,
            lens: repositories.lens)
        await adapted.load()
        let ordered = try #require(adapted.table.groups.first { $0.id == "themes" })
        #expect(ordered.isLensOrdered)
        #expect(ordered.metrics.first?.id == last)
        #expect(Set(ordered.metrics.map(\.id)) == Set(plain.metrics.map(\.id)))
    }

    @Test func picksAndDropsPeople() async {
        let model = CompareModel(slugs: [], service: showcase)
        await model.pick()
        #expect(model.isPicking)
        #expect(!model.people.isEmpty)
        let cards = Array(model.people.prefix(4))
        for card in cards { model.toggle(card) }
        #expect(model.slugs == cards.prefix(2).map(\.slug))
        #expect(!model.canToggle(cards[2]))
        model.toggle(cards[0])
        #expect(model.slugs.count == 1)
        model.toggle(cards[2])
        #expect(model.slugs.count == 2)
        model.pickerQuery = "psol"
        #expect(model.pickerResults.map(\.slug) == ["erika-hilton"])
        await model.confirm()
        #expect(!model.isPicking)
        #expect(model.profiles.count == 2)
        #expect(model.choiceText.contains("2"))
    }

    @Test func reportsWhyTheComparisonDidNotLoad() async {
        let offline = CompareModel(
            slugs: ["tabata-amaral", "kim-kataguiri"],
            service: ShowcasePublicData(scenario: .offline))
        await offline.load()
        #expect(offline.phase == .failed(.offline))
        #expect(offline.share == nil)
    }
}
