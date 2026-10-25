import Testing

@testable import FiscalDomain

struct RaceScenarioTests {
    @Test(arguments: RaceScenario.allCases)
    func everyScenarioHasTheSevenRacesInOrder(_ scenario: RaceScenario) {
        let races = scenario.races()
        #expect(races.map(\.id).first == "presidente-br")
        #expect(races.count == 7)
        #expect(races.dropFirst().allSatisfy { $0.office == .governor })
    }

    @Test(arguments: RaceScenario.allCases)
    func candidatesAreSortedAndSharesAddUp(_ scenario: RaceScenario) {
        for race in scenario.races() {
            #expect(race.candidates.map(\.votes) == race.candidates.map(\.votes).sorted(by: >))
            if race.hasStarted {
                let total = race.candidates.reduce(0) { $0 + $1.percent }
                #expect(abs(total - 100) < 0.02)
            }
            #expect(race.candidates.filter(\.elected).count == (race.final ? 1 : 0))
        }
    }

    @Test func waitingHasNoCountedSections() {
        #expect(RaceScenario.waiting.races().allSatisfy { !$0.hasStarted })
    }

    @Test func progressingEndsDecided() {
        #expect(!RaceScenario.progressing.races(step: 3)[0].final)
        #expect(RaceScenario.progressing.races(step: 10).allSatisfy { $0.final })
        #expect(RaceScenario.progressing.state(step: 5)?.sectionsPercent == 50)
    }

    @Test func tieIsOrderedByNumber() {
        let president = RaceScenario.tie.races()[0]
        #expect(president.candidates[0].votes == president.candidates[1].votes)
        #expect(president.candidates.map(\.number) == ["13", "22"])
    }
}
