import FiscalDomain
import Testing

@testable import FeatureToday

struct TodayRaceBoardTests {
    @Test func thePresidentialRaceLeadsWhileItIsCounting() throws {
        let races = RaceScenario.close.races()
        let featured = try #require(TodayRaceBoard.featured(in: races))
        #expect(featured.id == "presidente-br")
        let board = TodayRaceBoard(race: featured, others: races.count - 1)
        #expect(board.sides.count == 2)
        #expect(board.sides.map(\.index) == [0, 1])
        #expect(board.sides.allSatisfy { $0.percent != PublicFormat.missing })
        #expect(board.othersText != nil)
        #expect(board.countedFraction > 0.8 && board.countedFraction < 0.9)
    }

    @Test func aFinishedRaceGivesWayToOneStillCounting() throws {
        let races = RaceScenario.decided.races()
        let featured = try #require(TodayRaceBoard.featured(in: races))
        #expect(!featured.final)
        #expect(featured.office == .governor)
    }

    @Test func theCardLeavesWhenEveryRaceIsOver() {
        #expect(TodayRaceBoard.featured(in: RaceScenario.finished.races()) == nil)
        #expect(TodayRaceBoard.featured(in: []) == nil)
    }

    @Test func beforeTheCountTheNumbersAreMissingNotZero() throws {
        let race = try #require(TodayRaceBoard.featured(in: RaceScenario.waiting.races()))
        let board = TodayRaceBoard(race: race)
        #expect(board.sides.allSatisfy { $0.percent == PublicFormat.missing })
        #expect(board.othersText == nil)
        #expect(board.countedFraction == 0)
    }

    @Test func theLoserIsDimmedOnlyAfterTheFinalResult() throws {
        let race = try #require(
            RaceScenario.finished.races().first { $0.office == .president })
        let board = TodayRaceBoard(race: race)
        #expect(board.sides.filter(\.dimmed).count == 1)
        #expect(board.sides.first { $0.candidate.elected }?.dimmed == false)
    }

    @Test func candidateNamesBecomePortraitSlugs() {
        #expect(TodayRaceBoard.slug("Flavio Bolsonaro") == "flavio-bolsonaro")
        #expect(TodayRaceBoard.slug("Celina Leão") == "celina-leao")
        #expect(TodayRaceBoard.slug("Professora Maria do Carmo") == "professora-maria-do-carmo")
    }

    @Test func theSpokenSummaryNamesBothSides() throws {
        let race = try #require(TodayRaceBoard.featured(in: RaceScenario.close.races()))
        let label = TodayRaceBoard(race: race).accessibilityLabel
        for candidate in race.candidates.prefix(2) {
            #expect(label.contains(candidate.name))
        }
    }
}
